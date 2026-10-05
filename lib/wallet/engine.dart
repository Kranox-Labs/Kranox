// monero_c marks most functions of its Dart package with Deprecated("TODO"): its author has not reviewed their
// documentation yet. They are the plain API of wallet2. This file is the only one that calls them, and it checks
// the status of wallet2 after each call.
// ignore_for_file: deprecated_member_use

import 'package:monero/monero.dart' as monero;

import '../config/app_config.dart';
import '../core/amount.dart';
import '../core/seed.dart';
import 'failure.dart';
import 'models.dart';
import 'requests.dart';

/// The status of wallet2 after a call that went well.
///
/// The status of a wallet also carries the errors of its background scan, such as a node that did not answer for a
/// moment. So the engine reads it only right after wallet2 has made or opened the wallet; it judges every later call
/// by its own result.
const int _statusOk = 0;

/// The separator that the app gives to monero_c for lists in one string.
const String _listSeparator = ',';

/// Runs the requests of the app on wallet2. It lives in the worker isolate, one request at a time, because
/// wallet2 does not take two calls at once.
final class WalletEngine {
  WalletEngine({required String libraryPath}) {
    monero.libPath = libraryPath;
    _manager = monero.WalletManagerFactory_getWalletManager();
  }

  late final monero.WalletManager _manager;
  monero.wallet? _wallet;
  String? _path;
  monero.PendingTransaction? _pending;

  /// Runs one request and gives its answer. Throws a [WalletException] when wallet2 reports an error.
  Object? handle(WalletRequest request) => switch (request) {
    CreateWallet() => _create(request),
    RestoreWallet() => _restore(request),
    OpenWallet() => _open(request),
    ConnectNode() => _connect(request),
    ReadStatus() => _status(),
    ReadHistory() => _history(),
    ReadReceiveAddress() => _receiveAddress(request),
    PrepareSend() => _prepareSend(request),
    ConfirmSend() => _confirmSend(),
    CancelSend() => _cancelSend(),
    ReadSeed() => _seed(request),
    StoreWallet() => _store(),
    CloseWallet() => _close(),
  };

  List<String> _create(CreateWallet request) {
    final wallet = monero.WalletManager_createWallet(
      _manager,
      path: request.path,
      password: request.password,
      language: AppConfig.seedLanguage,
      networkType: request.networkType,
    );
    _adopt(wallet, request.path);
    return _seedWords(wallet);
  }

  Null _restore(RestoreWallet request) {
    final wallet = monero.WalletManager_recoveryWallet(
      _manager,
      path: request.path,
      password: request.password,
      mnemonic: request.seed,
      networkType: request.networkType,
      restoreHeight: request.restoreHeight,
      kdfRounds: AppConfig.kdfRounds,
      seedOffset: '',
    );
    _adopt(wallet, request.path);
    return null;
  }

  Null _open(OpenWallet request) {
    final wallet = monero.WalletManager_openWallet(
      _manager,
      path: request.path,
      password: request.password,
      networkType: request.networkType,
    );
    _adopt(wallet, request.path);
    return null;
  }

  /// Keeps a wallet that wallet2 made or opened. A wallet with an error status is closed and reported.
  void _adopt(monero.wallet wallet, String path) {
    if (monero.Wallet_status(wallet) != _statusOk) {
      final message = monero.Wallet_errorString(wallet);
      monero.WalletManager_closeWallet(_manager, wallet, false);
      throw WalletException.fromNative(message);
    }
    _wallet = wallet;
    _path = path;
  }

  Null _connect(ConnectNode request) {
    final wallet = _requireWallet();
    final initialized = monero.Wallet_init(wallet, daemonAddress: request.address);
    if (!initialized) {
      throw WalletException(WalletFailure.nodeUnreachable, monero.Wallet_errorString(wallet));
    }
    monero.Wallet_setTrustedDaemon(wallet, arg: false);
    monero.Wallet_startRefresh(wallet);
    monero.Wallet_setAutoRefreshInterval(wallet, millis: AppConfig.autoRefreshInterval.inMilliseconds);
    monero.Wallet_refreshAsync(wallet);
    return null;
  }

  WalletStatus _status() {
    final wallet = _requireWallet();
    final connection = monero.Wallet_connected(wallet);
    return WalletStatus(
      balance: XmrAmount(monero.Wallet_balance(wallet, accountIndex: AppConfig.accountIndex)),
      unlocked: XmrAmount(monero.Wallet_unlockedBalance(wallet, accountIndex: AppConfig.accountIndex)),
      walletHeight: monero.Wallet_blockChainHeight(wallet),
      nodeHeight: monero.Wallet_daemonBlockChainHeight(wallet),
      synchronized: monero.Wallet_synchronized(wallet),
      connection: connection >= 0 && connection < NodeConnection.values.length
          ? NodeConnection.values[connection]
          : NodeConnection.disconnected,
    );
  }

  List<WalletTransfer> _history() {
    final history = monero.Wallet_history(_requireWallet());
    monero.TransactionHistory_refresh(history);
    final transfers = [
      for (var index = 0; index < monero.TransactionHistory_count(history); index++)
        _transfer(monero.TransactionHistory_transaction(history, index: index)),
    ];
    transfers.sort((first, second) => second.time.compareTo(first.time));
    return transfers;
  }

  WalletTransfer _transfer(monero.TransactionInfo info) {
    final subaddresses = monero.TransactionInfo_subaddrIndex(info).split(_listSeparator);
    return WalletTransfer(
      hash: monero.TransactionInfo_hash(info),
      direction: monero.TransactionInfo_direction(info) == monero.TransactionInfo_Direction.In
          ? TransferDirection.incoming
          : TransferDirection.outgoing,
      amount: XmrAmount(monero.TransactionInfo_amount(info)),
      fee: XmrAmount(monero.TransactionInfo_fee(info)),
      time: DateTime.fromMillisecondsSinceEpoch(monero.TransactionInfo_timestamp(info) * 1000),
      blockHeight: monero.TransactionInfo_blockHeight(info),
      confirmations: monero.TransactionInfo_confirmations(info),
      isPending: monero.TransactionInfo_isPending(info),
      isFailed: monero.TransactionInfo_isFailed(info),
      subaddressIndex: int.tryParse(subaddresses.first.trim()),
    );
  }

  ReceiveAddress _receiveAddress(ReadReceiveAddress request) {
    final wallet = _requireWallet();
    final count = monero.Wallet_numSubaddresses(wallet, accountIndex: AppConfig.accountIndex);
    // The first address of an account is its main address. The app hands out subaddresses only, so that two
    // payers never see the same address.
    if (request.createNew || count < 2) {
      monero.Wallet_addSubaddress(wallet, accountIndex: AppConfig.accountIndex);
      if (monero.Wallet_numSubaddresses(wallet, accountIndex: AppConfig.accountIndex) <= count) {
        throw WalletException.fromNative(monero.Wallet_errorString(wallet));
      }
    }
    final index = monero.Wallet_numSubaddresses(wallet, accountIndex: AppConfig.accountIndex) - 1;
    return ReceiveAddress(
      address: monero.Wallet_address(wallet, accountIndex: AppConfig.accountIndex, addressIndex: index),
      index: index,
    );
  }

  PreparedSend _prepareSend(PrepareSend request) {
    final wallet = _requireWallet();
    // monero_c offers no call to free a built payment. A payment that the user drops stays in memory until the
    // wallet closes.
    _pending = null;
    final pending = monero.Wallet_createTransaction(
      wallet,
      dst_addr: request.address,
      payment_id: '',
      amount: request.amountUnits,
      mixin_count: AppConfig.decoyCount,
      pendingTransactionPriority: AppConfig.sendPriority,
      subaddr_account: AppConfig.accountIndex,
    );
    _checkPending(pending);
    _pending = pending;
    return PreparedSend(
      address: request.address,
      amount: XmrAmount(monero.PendingTransaction_amount(pending)),
      fee: XmrAmount(monero.PendingTransaction_fee(pending)),
    );
  }

  SentPayment _confirmSend() {
    final wallet = _requireWallet();
    final pending = _pending;
    if (pending == null) {
      throw StateError('No payment waits for its confirmation.');
    }
    _pending = null;
    final committed = monero.PendingTransaction_commit(pending, filename: '', overwrite: false);
    _checkPending(pending);
    if (!committed) {
      throw WalletException(WalletFailure.native, monero.PendingTransaction_errorString(pending));
    }
    final payment = SentPayment(
      transactionId: monero.PendingTransaction_txid(pending, _listSeparator),
      amount: XmrAmount(monero.PendingTransaction_amount(pending)),
      fee: XmrAmount(monero.PendingTransaction_fee(pending)),
    );
    // The node has the payment at this point. A failed write of the wallet file does not undo it, and the file is
    // written again when the wallet closes, so the app reports the payment as sent either way.
    monero.Wallet_store(wallet);
    return payment;
  }

  Null _cancelSend() {
    _pending = null;
    return null;
  }

  List<String> _seed(ReadSeed request) {
    final wallet = _requireWallet();
    final path = _path;
    if (path == null) {
      throw StateError('The open wallet has no path.');
    }
    final valid = monero.WalletManager_verifyWalletPassword(
      _manager,
      keysFileName: '$path.keys',
      password: request.password,
      noSpendKey: false,
      kdfRounds: AppConfig.kdfRounds,
    );
    if (!valid) {
      throw const WalletException(WalletFailure.wrongPassword, 'The password does not open the key file.');
    }
    return _seedWords(wallet);
  }

  Null _store() {
    final wallet = _requireWallet();
    if (!monero.Wallet_store(wallet)) {
      throw WalletException.fromNative(monero.Wallet_errorString(wallet));
    }
    return null;
  }

  Null _close() {
    final wallet = _wallet;
    if (wallet == null) {
      return null;
    }
    _pending = null;
    _wallet = null;
    _path = null;
    // closeWallet with its store flag writes the file while the scan of wallet2 may still run, and the two break the
    // hash chain of the wallet: CHECKED 5 Oct 2026, the app crashed in trim_hashchain and in the serialization of the
    // hash chain when it locked a stagenet wallet that had just caught up. Wallet_store stops a running scan and waits
    // for it (the patch "store crash fix" of monero_c), and the paused scan does not start again. A failed write
    // costs only a new scan from the keys file at the next unlock, so the wallet closes either way.
    monero.Wallet_pauseRefresh(wallet);
    monero.Wallet_store(wallet);
    monero.WalletManager_closeWallet(_manager, wallet, false);
    return null;
  }

  List<String> _seedWords(monero.wallet wallet) {
    final words = monero.Wallet_seed(wallet, seedOffset: '').trim().split(RegExp(r'\s+'));
    if (words.length != seedWordCount) {
      throw WalletException(WalletFailure.native, 'wallet2 gave a seed of ${words.length} words.');
    }
    return words;
  }

  monero.wallet _requireWallet() {
    final wallet = _wallet;
    if (wallet == null) {
      throw StateError('No wallet is open.');
    }
    return wallet;
  }

  void _checkPending(monero.PendingTransaction pending) {
    if (monero.PendingTransaction_status(pending) != _statusOk) {
      throw WalletException.fromNative(monero.PendingTransaction_errorString(pending));
    }
  }
}

import '../core/amount.dart';
import '../core/unlock.dart';

/// The connection of the wallet to its node, in the numbers of wallet2.
enum NodeConnection { disconnected, connected, wrongVersion }

/// The state of an open wallet at one moment.
final class WalletStatus {
  const WalletStatus({
    required this.balance,
    required this.unlocked,
    required this.walletHeight,
    required this.nodeHeight,
    required this.synchronized,
    required this.connection,
  });

  static const WalletStatus unknown = WalletStatus(
    balance: XmrAmount.zero,
    unlocked: XmrAmount.zero,
    walletHeight: 0,
    nodeHeight: 0,
    synchronized: false,
    connection: NodeConnection.disconnected,
  );

  final XmrAmount balance;

  /// The part of the balance that the wallet can spend now. Monero locks a new output for 10 blocks.
  final XmrAmount unlocked;

  /// The height of the chain that the wallet has scanned, and the height that the node knows.
  final int walletHeight;
  final int nodeHeight;
  final bool synchronized;
  final NodeConnection connection;

  XmrAmount get locked => balance - unlocked;

  /// Whether the amounts may still change: the app has no state of the wallet yet, or the wallet scans the chain of a
  /// node that answers. The screens show a spinner in place of an amount then, so that an amount of the last scan
  /// does not look like a fault. With a node that does not answer, the amounts of the last scan show.
  bool get isLoading => identical(this, unknown) || (connection == NodeConnection.connected && !synchronized);

  /// The share of the chain that the wallet has scanned, from 0 to 1.
  double get syncShare {
    if (synchronized) return 1;
    if (nodeHeight <= 0) return 0;
    return (walletHeight / nodeHeight).clamp(0, 1).toDouble();
  }
}

enum TransferDirection { incoming, outgoing }

/// One transaction of the wallet.
final class WalletTransfer {
  const WalletTransfer({
    required this.hash,
    required this.direction,
    required this.amount,
    required this.fee,
    required this.time,
    required this.blockHeight,
    required this.confirmations,
    required this.isPending,
    required this.isFailed,
    required this.subaddressIndex,
  });

  final String hash;
  final TransferDirection direction;
  final XmrAmount amount;
  final XmrAmount fee;
  final DateTime time;
  final int blockHeight;
  final int confirmations;
  final bool isPending;
  final bool isFailed;

  /// The subaddress that received an incoming transfer, when the wallet knows it.
  final int? subaddressIndex;

  /// How far the coins of the transfer are on their way to spendable: the coins received, or the change of a payment.
  UnlockProgress get unlock => UnlockProgress(confirmations);
}

/// The address that the receive screen shows: the newest subaddress of the first account.
final class ReceiveAddress {
  const ReceiveAddress({required this.address, required this.index});

  final String address;
  final int index;
}

/// A payment that wallet2 has built but not sent. The user sees its fee before the app sends it. [id] names it, so
/// that a confirm sends this payment and no other.
final class PreparedSend {
  const PreparedSend({required this.id, required this.address, required this.amount, required this.fee});

  final int id;
  final String address;
  final XmrAmount amount;
  final XmrAmount fee;

  XmrAmount get total => amount + fee;
}

/// A payment that the node has accepted.
final class SentPayment {
  const SentPayment({required this.transactionId, required this.amount, required this.fee});

  final String transactionId;
  final XmrAmount amount;
  final XmrAmount fee;
}

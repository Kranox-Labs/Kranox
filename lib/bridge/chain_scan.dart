/// One side of a transfer on Robinhood Chain, with the name that the explorer gives it, if any.
final class ChainParty {
  const ChainParty({required this.address, required this.label, required this.isContract});

  factory ChainParty.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('A side of a transfer is not an object.');
    final address = json['address'];
    final label = json['label'];
    final isContract = json['isContract'];
    if (address is! String || address.isEmpty || (label != null && label is! String) || isContract is! bool) {
      throw const FormatException('A side of a transfer has no address.');
    }
    return ChainParty(address: address, label: label as String?, isContract: isContract);
  }

  final String address;
  final String? label;
  final bool isContract;
}

/// A token of Robinhood Chain, as ERC-20.
final class ChainToken {
  const ChainToken({required this.symbol, required this.address, required this.decimals});

  factory ChainToken.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('A token is not an object.');
    final symbol = json['symbol'];
    final address = json['address'];
    final decimals = json['decimals'];
    if (symbol is! String || address is! String || decimals is! int || decimals < 0) {
      throw const FormatException('A token has no symbol, address, or decimals.');
    }
    return ChainToken(symbol: symbol, address: address, decimals: decimals);
  }

  final String symbol;
  final String address;
  final int decimals;
}

/// A transfer of ETH, with [token] null, or of a token. [value] counts the smallest unit of the coin.
final class ChainTransfer {
  const ChainTransfer({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.token,
    required this.time,
  });

  factory ChainTransfer.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('A transfer is not an object.');
    final hash = json['hash'];
    final value = BigInt.tryParse('${json['value']}');
    final time = DateTime.tryParse('${json['time']}');
    if (hash is! String || hash.isEmpty || value == null || time == null) {
      throw const FormatException('A transfer has no hash, value, or time.');
    }
    final to = json['to'];
    final token = json['token'];
    return ChainTransfer(
      hash: hash,
      from: ChainParty.fromJson(json['from']),
      to: to == null ? null : ChainParty.fromJson(to),
      value: value,
      token: token == null ? null : ChainToken.fromJson(token),
      time: time,
    );
  }

  final String hash;
  final ChainParty from;

  /// The recipient, or null for the creation of a contract.
  final ChainParty? to;
  final BigInt value;
  final ChainToken? token;
  final DateTime time;
}

/// A token that an address holds.
final class ChainHolding {
  const ChainHolding({required this.token, required this.value});

  factory ChainHolding.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('A holding is not an object.');
    final value = BigInt.tryParse('${json['value']}');
    if (value == null) throw const FormatException('A holding has no value.');
    return ChainHolding(token: ChainToken.fromJson(json['token']), value: value);
  }

  final ChainToken token;
  final BigInt value;
}

/// What the public history of an address on Robinhood Chain shows, as the relay reads it from the explorer. The lists
/// start with the newest and hold the newest 50 items at most.
final class ChainScan {
  const ChainScan({
    required this.address,
    required this.isContract,
    required this.balanceWei,
    required this.transactionCount,
    required this.tokenTransferCount,
    required this.firstTransaction,
    required this.firstTokenTransfer,
    required this.transactions,
    required this.tokenTransfers,
    required this.holdings,
    this.firstFunding,
    this.fundingRead = false,
    this.fundingSure = true,
  });

  factory ChainScan.fromJson(Map<String, Object?> json) {
    final address = json['address'];
    final isContract = json['isContract'];
    final balance = BigInt.tryParse('${json['balanceWei']}');
    final transactionCount = json['transactionCount'];
    final tokenTransferCount = json['tokenTransferCount'];
    final transactions = json['transactions'];
    final tokenTransfers = json['tokenTransfers'];
    final holdings = json['holdings'];
    if (address is! String ||
        isContract is! bool ||
        balance == null ||
        transactionCount is! int ||
        tokenTransferCount is! int ||
        transactions is! List<Object?> ||
        tokenTransfers is! List<Object?> ||
        holdings is! List<Object?>) {
      throw const FormatException('The relay answered a scan without its address, counts, or lists.');
    }
    final first = json['firstTransaction'];
    final firstToken = json['firstTokenTransfer'];
    final funding = json['firstFunding'];
    return ChainScan(
      address: address,
      isContract: isContract,
      balanceWei: balance,
      transactionCount: transactionCount,
      tokenTransferCount: tokenTransferCount,
      firstTransaction: first == null ? null : ChainTransfer.fromJson(first),
      firstTokenTransfer: firstToken == null ? null : ChainTransfer.fromJson(firstToken),
      transactions: transactions.map(ChainTransfer.fromJson).toList(),
      tokenTransfers: tokenTransfers.map(ChainTransfer.fromJson).toList(),
      holdings: holdings.map(ChainHolding.fromJson).toList(),
      firstFunding: funding == null ? null : ChainTransfer.fromJson(funding),
      // A relay before 10 Oct 2026 reads no first funding of its own, so what the app reads from its oldest transfers
      // is unsure.
      fundingRead: json.containsKey('firstFunding'),
      fundingSure: json['fundingSure'] == true,
    );
  }

  final String address;
  final bool isContract;
  final BigInt balanceWei;
  final int transactionCount;
  final int tokenTransferCount;

  /// The oldest transaction and the oldest token transfer of the address, in or out.
  final ChainTransfer? firstTransaction;
  final ChainTransfer? firstTokenTransfer;
  final List<ChainTransfer> transactions;
  final List<ChainTransfer> tokenTransfers;
  final List<ChainHolding> holdings;

  /// The oldest transfer of value into the address that the relay found, of ETH, of ETH that a contract sent, or of a
  /// token, with the public name of its sender; null when it found none. The relay reads it from 10 Oct 2026, when the
  /// owner asked that a name no explorer gave never turn a check green: [fundingRead] says whether it did, and without
  /// it the app reads the first funding from the oldest transactions above.
  final ChainTransfer? firstFunding;
  final bool fundingRead;

  /// Whether the relay read every kind of transfer in and the name of the sender, so that no older one escaped it.
  final bool fundingSure;
}

/// Reads the public history of an address on Robinhood Chain through the relay of Kranox, so that the explorer sees the
/// relay and not the user.
abstract interface class ChainScanClient {
  Future<ChainScan> scanAddress(String address);
}

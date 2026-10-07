import '../bridge/chain_scan.dart';
import '../bridge/models.dart';
import '../config/app_config.dart';

/// The transfer that first brought coins to the scanned address.
final class FirstFunding {
  const FirstFunding({required this.transfer, required this.fromOwn});

  final ChainTransfer transfer;

  /// Whether the sender is another address of the user that the app knows.
  final bool fromOwn;

  /// The public name of the sender, such as the name of an exchange.
  String? get label => transfer.from.label;

  /// A funding from another address of the user, or from a sender with a public name, links the address to it.
  bool get links => fromOwn || label != null;
}

/// A swap of Kranox that the scanned address takes part in. On the chain it shows a transfer to or from the exchanger;
/// only the records of the exchanger tie it to the XMR of the user.
sealed class KranoxLink {
  const KranoxLink(this.swap);

  final BridgeSwap swap;
}

/// The address sent the coin of a receive into the exchanger.
final class FundedReceive extends KranoxLink {
  const FundedReceive(super.swap);
}

/// The address got a payment from XMR.
final class GotPay extends KranoxLink {
  const GotPay(super.swap);
}

/// The user gave the address as the refund address of a receive.
final class RefundOf extends KranoxLink {
  const RefundOf(super.swap);
}

/// A direct transfer between the scanned address and another address of the user.
final class OwnLink {
  const OwnLink({required this.other, required this.at});

  final String other;
  final DateTime at;
}

/// A transfer to the scanned address from an address that looks like one that the scanned address paid.
final class LookAlike {
  const LookAlike({required this.sender, required this.resembles, required this.at});

  final String sender;
  final String resembles;
  final DateTime at;
}

/// What anyone sees of the address.
final class Exposure {
  const Exposure({
    required this.transactions,
    required this.tokenTransfers,
    required this.tokens,
    required this.firstSeen,
    required this.activeHours,
  });

  final int transactions;
  final int tokenTransfers;

  /// The symbols of the tokens that the address holds, at most [AppConfig.scanTokensShown].
  final List<String> tokens;
  final DateTime? firstSeen;

  /// The hours of the day in UTC, from the first to the hour after the last, that hold most of its activity.
  final (int, int)? activeHours;
}

/// What the scan of an address on Robinhood Chain found.
final class ChainPrivacyReport {
  const ChainPrivacyReport({
    required this.scan,
    required this.funding,
    required this.kranox,
    required this.own,
    required this.lookAlikes,
    required this.exposure,
  });

  final ChainScan scan;
  final FirstFunding? funding;
  final List<KranoxLink> kranox;
  final List<OwnLink> own;
  final List<LookAlike> lookAlikes;
  final Exposure exposure;

  /// The links of the funding and of other addresses of the user, and look-alike senders. The swaps of Kranox and what
  /// everyone sees are notes.
  int get toImprove => [funding?.links ?? false, own.isNotEmpty, lookAlikes.isNotEmpty].where((found) => found).length;
}

/// Reads what [scan] gives away, with the swaps of the bridge ([swaps]) and the other addresses of the user that the
/// app knows ([ownAddresses]): the refund addresses of receives and the addresses that the user scanned.
ChainPrivacyReport analyzeChain(
  ChainScan scan, {
  required List<BridgeSwap> swaps,
  required Iterable<String> ownAddresses,
}) {
  final me = scan.address.toLowerCase();
  final own = {
    for (final address in ownAddresses) address.toLowerCase(),
    for (final swap in swaps)
      if (swap.direction == SwapDirection.receive && swap.refundAddress != null) swap.refundAddress!.toLowerCase(),
  }..remove(me);
  final transfers = _distinct([
    ...scan.transactions,
    ...scan.tokenTransfers,
    ?scan.firstTransaction,
    ?scan.firstTokenTransfer,
  ]);
  return ChainPrivacyReport(
    scan: scan,
    funding: _funding(scan, me, own),
    kranox: _kranox(me, transfers, swaps),
    own: _own(me, transfers, own),
    lookAlikes: _lookAlikes(me, transfers),
    exposure: _exposure(scan, transfers),
  );
}

/// The transfers once each: a transfer of ETH and a transfer of a token in the same transaction stay apart.
List<ChainTransfer> _distinct(List<ChainTransfer> transfers) {
  final seen = <String>{};
  return [
    for (final transfer in transfers)
      if (seen.add('${transfer.hash.toLowerCase()}/${transfer.token?.address.toLowerCase()}')) transfer,
  ];
}

bool _to(ChainTransfer transfer, String address) => transfer.to?.address.toLowerCase() == address;

bool _from(ChainTransfer transfer, String address) => transfer.from.address.toLowerCase() == address;

FirstFunding? _funding(ChainScan scan, String me, Set<String> own) {
  final incoming = [
    for (final transfer in [?scan.firstTransaction, ?scan.firstTokenTransfer])
      if (_to(transfer, me)) transfer,
  ];
  if (incoming.isEmpty) return null;
  final first = incoming.reduce((a, b) => b.time.isBefore(a.time) ? b : a);
  return FirstFunding(transfer: first, fromOwn: own.contains(first.from.address.toLowerCase()));
}

List<KranoxLink> _kranox(String me, List<ChainTransfer> transfers, List<BridgeSwap> swaps) {
  final links = <KranoxLink>[];
  for (final swap in swaps) {
    if (swap.direction == SwapDirection.receive) {
      final deposit = swap.depositAddress.toLowerCase();
      if (transfers.any((transfer) => _from(transfer, me) && _to(transfer, deposit))) {
        links.add(FundedReceive(swap));
      } else if (swap.refundAddress?.toLowerCase() == me) {
        links.add(RefundOf(swap));
      }
    } else if (swap.payoutAddress.toLowerCase() == me) {
      links.add(GotPay(swap));
    }
  }
  return links..sort((a, b) => b.swap.createdAt.compareTo(a.swap.createdAt));
}

List<OwnLink> _own(String me, List<ChainTransfer> transfers, Set<String> own) {
  final newest = <String, OwnLink>{};
  for (final transfer in transfers) {
    final from = transfer.from.address;
    final to = transfer.to?.address;
    final other = _from(transfer, me) ? to : (_to(transfer, me) ? from : null);
    if (other == null || !own.contains(other.toLowerCase())) continue;
    final key = other.toLowerCase();
    final known = newest[key];
    if (known == null || transfer.time.isAfter(known.at)) newest[key] = OwnLink(other: other, at: transfer.time);
  }
  return newest.values.toList()..sort((a, b) => b.at.compareTo(a.at));
}

/// Whether two different addresses agree in their first and last hex digits.
bool _looksLike(String a, String b) {
  final x = a.toLowerCase().replaceFirst('0x', '');
  final y = b.toLowerCase().replaceFirst('0x', '');
  if (x == y || x.length != y.length || x.length < AppConfig.lookAlikeHead + AppConfig.lookAlikeTail) return false;
  return x.substring(0, AppConfig.lookAlikeHead) == y.substring(0, AppConfig.lookAlikeHead) &&
      x.substring(x.length - AppConfig.lookAlikeTail) == y.substring(y.length - AppConfig.lookAlikeTail);
}

List<LookAlike> _lookAlikes(String me, List<ChainTransfer> transfers) {
  final paid = {
    for (final transfer in transfers)
      if (_from(transfer, me) && transfer.to != null) transfer.to!.address,
  };
  final found = <String, LookAlike>{};
  for (final transfer in transfers) {
    if (!_to(transfer, me)) continue;
    final sender = transfer.from.address;
    if (paid.any((address) => address.toLowerCase() == sender.toLowerCase())) continue;
    final resembles = paid.where((address) => _looksLike(address, sender)).firstOrNull;
    if (resembles == null) continue;
    final known = found[sender.toLowerCase()];
    if (known == null || transfer.time.isAfter(known.at)) {
      found[sender.toLowerCase()] = LookAlike(sender: sender, resembles: resembles, at: transfer.time);
    }
  }
  return found.values.toList()..sort((a, b) => b.at.compareTo(a.at));
}

Exposure _exposure(ChainScan scan, List<ChainTransfer> transfers) {
  final firsts = [
    for (final transfer in [?scan.firstTransaction, ?scan.firstTokenTransfer]) transfer.time,
  ];
  return Exposure(
    transactions: scan.transactionCount,
    tokenTransfers: scan.tokenTransferCount,
    tokens: [
      for (final holding in scan.holdings)
        if (holding.value > BigInt.zero) holding.token.symbol,
    ].take(AppConfig.scanTokensShown).toList(),
    firstSeen: firsts.isEmpty ? null : firsts.reduce((a, b) => a.isBefore(b) ? a : b),
    activeHours: _activeHours([for (final transfer in transfers) transfer.time.toUtc().hour]),
  );
}

/// The window of [AppConfig.activityWindowHours] hours of the day that holds the most of [hours], when it holds at
/// least [AppConfig.activityShare] of them.
(int, int)? _activeHours(List<int> hours) {
  if (hours.length < AppConfig.activityMinTransfers) return null;
  const width = AppConfig.activityWindowHours;
  var best = 0;
  var bestCount = -1;
  for (var start = 0; start < 24; start++) {
    final count = hours.where((hour) => (hour - start) % 24 < width).length;
    if (count > bestCount) {
      best = start;
      bestCount = count;
    }
  }
  if (bestCount < AppConfig.activityShare * hours.length) return null;
  return (best, (best + width) % 24);
}

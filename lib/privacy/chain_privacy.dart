import '../bridge/chain_scan.dart';
import '../bridge/models.dart';
import '../config/app_config.dart';

/// The transfer that first brought coins to the scanned address.
final class FirstFunding {
  const FirstFunding({required this.transfer, required this.fromOwn, required this.sure, this.fromPay});

  final ChainTransfer transfer;

  /// Whether the sender is another address of the user that the app knows.
  final bool fromOwn;

  /// The payment of the user from XMR whose payout this transfer is: the clean start that the menu Privacy offers. On
  /// the chain it shows a transfer from the exchanger, whatever name an explorer gives it, and only the records of the
  /// exchanger tie it to that one payment.
  final BridgeSwap? fromPay;

  /// Whether the relay read every kind of transfer in, so that no older one escaped it. A funding that is not sure
  /// never counts as clean, though one that links still warns.
  final bool sure;

  /// The public name of the sender, such as the name of an exchange, and where it comes from.
  String? get label => transfer.from.label;
  LabelSource get labelSource => transfer.from.labelSource;

  /// A funding from another address of the user, or from a sender with a public name, links the address to it; the
  /// payout of a payment of the user from XMR does not.
  bool get links => fromPay == null && (fromOwn || label != null);
}

/// A swap of Kranox that the scanned address takes part in. On the chain it shows a transfer to or from the exchanger;
/// only the records of the exchanger tie it to the XMR of the user. One swap ties the address to that swap alone; more
/// tie those swaps together in the records of the exchanger.
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

  /// Whether the address ties swaps of the user together in the records of the exchanger: it took part in more than
  /// one. The owner asked on 10 Oct 2026 for a perfect score that means no trace that Kranox can find, so this counts
  /// as something to improve, with a new address as the way.
  bool get tiesSwaps => kranox.length > 1;

  /// The links of the funding and of other addresses of the user, look-alike senders, and swaps that the address ties
  /// together. What everyone sees is a note.
  int get toImprove =>
      [funding?.links ?? false, own.isNotEmpty, lookAlikes.isNotEmpty, tiesSwaps].where((found) => found).length;
}

/// Whether [links] hold both sides of the bridge: a payment from XMR and a receive into XMR, which the records of the
/// exchanger then tie together.
bool onBothSides(List<KranoxLink> links) => links.any((link) => link is GotPay) && links.any((link) => link is! GotPay);

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
    funding: _funding(scan, me, own, swaps),
    kranox: kranoxLinks(me, swaps, transfers: transfers),
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

/// The first funding of the scanned address: the one that the relay read from every kind of transfer in, or, from a
/// relay before 10 Oct 2026, the older of its oldest transaction and token transfer that came in.
FirstFunding? _funding(ChainScan scan, String me, Set<String> own, List<BridgeSwap> swaps) {
  final ChainTransfer first;
  if (scan.fundingRead) {
    final funding = scan.firstFunding;
    if (funding == null) return null;
    first = funding;
  } else {
    final incoming = [
      for (final transfer in [?scan.firstTransaction, ?scan.firstTokenTransfer])
        if (_to(transfer, me)) transfer,
    ];
    if (incoming.isEmpty) return null;
    first = incoming.reduce((a, b) => b.time.isBefore(a.time) ? b : a);
  }
  final hash = first.hash.toLowerCase();
  return FirstFunding(
    transfer: first,
    fromOwn: own.contains(first.from.address.toLowerCase()),
    fromPay: swaps
        .where((swap) => swap.direction == SwapDirection.pay && swap.payoutHash?.toLowerCase() == hash)
        .firstOrNull,
    sure: scan.fundingSure,
  );
}

/// The swaps of Kranox that [address] takes part in, the newest first: from the records of the swaps, and with the
/// [transfers] of a scan of the address also the receives whose coin it sent in.
List<KranoxLink> kranoxLinks(String address, List<BridgeSwap> swaps, {List<ChainTransfer> transfers = const []}) {
  final me = address.toLowerCase();
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

import 'dart:math';

import '../bridge/models.dart';
import '../config/app_config.dart';
import '../core/amount.dart';
import '../wallet/models.dart';
import 'chain_privacy.dart';

/// A payment to Robinhood Chain under review: what the recipient gets there, and where. The limits of the exchanger
/// keep a suggested amount inside them.
final class ChainPayment {
  const ChainPayment({required this.asset, required this.amount, required this.recipient, this.minXmr, this.maxXmr});

  final BridgeAsset asset;

  /// The amount of [asset] that the recipient gets.
  final double amount;
  final String recipient;
  final double? minXmr;
  final double? maxXmr;
}

/// An earlier amount that the amount of a payment matches, so that someone who sees both can link them.
sealed class AmountMatch {
  const AmountMatch(this.at);

  /// When the earlier amount came in.
  final DateTime at;
}

/// XMR that came into this wallet.
final class XmrMatch extends AmountMatch {
  const XmrMatch({required this.amount, required DateTime at}) : super(at);

  final XmrAmount amount;
}

/// A coin that the user sent in from Robinhood Chain in a receive, which matches what the recipient of a payment to
/// Robinhood Chain gets.
final class ChainMatch extends AmountMatch {
  const ChainMatch({required this.asset, required this.sent, required this.paid, required DateTime at}) : super(at);

  final BridgeAsset asset;

  /// What the user sent in from Robinhood Chain.
  final double sent;

  /// What the recipient of the payment gets.
  final double paid;
}

/// The payment may use coins that came in less than [AppConfig.privacyFreshWindow] ago.
final class FreshCoins {
  const FreshCoins({required this.since, required this.clearsAt, required this.fromChain});

  /// When the newest coins that the payment may use came in.
  final DateTime since;

  /// When the payment no longer needs coins that new.
  final DateTime clearsAt;

  /// Whether some of these coins came from Robinhood Chain through a receive.
  final bool fromChain;
}

/// The recipient of a payment to Robinhood Chain took part in another swap of the user, so that the records of the
/// exchanger tie this payment to that swap, the newest one in [link].
final class OwnAddress {
  const OwnAddress(this.link);

  final KranoxLink link;

  /// When the user made that swap.
  DateTime get usedAt => link.swap.createdAt;
}

/// What the privacy check found for one payment: one finding for each rule that warns, and nothing for a rule that
/// passes. The check advises and blocks nothing; the owner approved its three rules on 7 Oct 2026.
final class PrivacyReport {
  const PrivacyReport({
    required this.checksAddress,
    this.amountMatch,
    this.suggestion,
    this.fresh,
    this.ownAddress,
    this.addressChecked = true,
  });

  /// The rule of the amount: an earlier amount that this one matches.
  final AmountMatch? amountMatch;

  /// An amount of XMR that clears the rule of the amount, if one fits the balance and the limits of the exchanger.
  final XmrAmount? suggestion;

  /// The rule of the timing.
  final FreshCoins? fresh;

  /// Whether the check covers the rule of the address, which only pay has.
  final bool checksAddress;

  /// The rule of the address.
  final OwnAddress? ownAddress;

  /// Whether the rule of the address read what it needs: false while the scan of the recipient runs or after it
  /// failed, since only a scan knows the receives whose coin the recipient sent in. Without it the rule passes
  /// nothing, so that the check never says "All clear" on missing data (the sharp-edges scan of 10 Oct 2026).
  final bool addressChecked;

  int get warnings => [amountMatch, fresh, ownAddress].where((finding) => finding != null).length;

  /// The same report with the rule of the address in [ownAddress], such as one that the scan of the recipient knows,
  /// and whether that rule read what it needs ([checked]).
  PrivacyReport withOwnAddress(OwnAddress? ownAddress, {bool checked = true}) => PrivacyReport(
    checksAddress: checksAddress,
    amountMatch: amountMatch,
    suggestion: suggestion,
    fresh: fresh,
    ownAddress: ownAddress,
    addressChecked: checked,
  );
}

/// Runs the privacy check on a payment of [amount] XMR with [fee]: a plain send, or with [chain] a payment to Robinhood
/// Chain. It reads what came into the wallet ([transfers]), the swaps of the bridge ([swaps]), the [balance], the part
/// of it that the wallet can spend now ([spendable]), and the addresses on Robinhood Chain that the user scanned as
/// theirs ([ownAddresses]). [random] picks the step of a suggested amount, so that suggestions follow no fixed pattern.
PrivacyReport checkPrivacy({
  required XmrAmount amount,
  required XmrAmount fee,
  required List<WalletTransfer> transfers,
  required List<BridgeSwap> swaps,
  required XmrAmount balance,
  required XmrAmount spendable,
  required DateTime now,
  ChainPayment? chain,
  Iterable<String> ownAddresses = const [],
  Random? random,
}) {
  final incoming = [
    for (final transfer in transfers)
      if (transfer.direction == TransferDirection.incoming && !transfer.isFailed) transfer,
  ];
  // A receive leaves a trace on Robinhood Chain only once the user sent the coin in.
  final deposits = [
    for (final swap in swaps)
      if (chain != null &&
          swap.direction == SwapDirection.receive &&
          swap.asset == chain.asset &&
          swap.depositHash != null)
        swap,
  ];
  AmountMatch? matchOf(XmrAmount xmr, double? paid) => _amountMatch(xmr, paid, incoming, deposits, now);
  final match = matchOf(amount, chain?.amount);
  return PrivacyReport(
    amountMatch: match,
    suggestion: match == null
        ? null
        : _suggest(
            amount: amount,
            fee: fee,
            spendable: spendable,
            match: match,
            chain: chain,
            random: random ?? Random.secure(),
            matchOf: matchOf,
          ),
    fresh: _freshCoins(amount + fee, balance, incoming, swaps, now),
    checksAddress: chain != null,
    ownAddress: chain == null ? null : ownAddressOf(chain.recipient, swaps, ownAddresses: ownAddresses),
  );
}

/// The newest earlier amount that [xmr] or [paid] matches within the window of the rule.
AmountMatch? _amountMatch(
  XmrAmount xmr,
  double? paid,
  List<WalletTransfer> incoming,
  List<BridgeSwap> deposits,
  DateTime now,
) {
  AmountMatch? found;
  void keep(AmountMatch match) {
    if (found == null || match.at.isAfter(found!.at)) found = match;
  }

  for (final transfer in incoming) {
    if (now.difference(transfer.time) > AppConfig.privacyAmountWindow) continue;
    if (_close(xmr.units.toDouble(), transfer.amount.units.toDouble(), AppConfig.privacyXmrTolerance)) {
      keep(XmrMatch(amount: transfer.amount, at: transfer.time));
    }
  }
  if (paid != null) {
    for (final swap in deposits) {
      if (now.difference(swap.createdAt) > AppConfig.privacyAmountWindow) continue;
      if (_close(paid, swap.amount, AppConfig.privacyChainTolerance)) {
        keep(ChainMatch(asset: swap.asset, sent: swap.amount, paid: paid, at: swap.createdAt));
      }
    }
  }
  return found;
}

/// Whether [a] and [b] differ by at most [share] of the larger one.
bool _close(double a, double b, double share) => (a - b).abs() <= share * max(a, b);

/// An amount near [amount] that matches nothing, with a step past the tolerance of the [match] that [random] widens.
/// It tries a smaller amount first, so that it fits the balance, and a larger one when the smaller one falls below the
/// minimum of the exchanger.
XmrAmount? _suggest({
  required XmrAmount amount,
  required XmrAmount fee,
  required XmrAmount spendable,
  required AmountMatch match,
  required ChainPayment? chain,
  required Random random,
  required AmountMatch? Function(XmrAmount xmr, double? paid) matchOf,
}) {
  final tolerance = match is ChainMatch ? AppConfig.privacyChainTolerance : AppConfig.privacyXmrTolerance;
  final step = pow(10, XmrAmount.decimals - AppConfig.privacySuggestionDecimals).toInt();
  final minUnits = chain?.minXmr == null ? null : chain!.minXmr! * XmrAmount.unitsPerXmr;
  final maxUnits = chain?.maxXmr == null ? null : chain!.maxXmr! * XmrAmount.unitsPerXmr;
  for (var attempt = 1; attempt <= AppConfig.privacySuggestionAttempts; attempt++) {
    final margin =
        AppConfig.privacySuggestionMarginMin +
        random.nextDouble() * (AppConfig.privacySuggestionMarginMax - AppConfig.privacySuggestionMarginMin);
    final share = tolerance + margin * attempt;
    for (final sign in const [-1, 1]) {
      final raw = amount.units * (1 + sign * share) / step;
      final units = (sign < 0 ? raw.floor() : raw.ceil()) * step;
      if (units <= 0) continue;
      if (minUnits != null && units < minUnits) continue;
      if (maxUnits != null && units > maxUnits) continue;
      final candidate = XmrAmount(units);
      if (candidate + fee > spendable) continue;
      final paid = chain == null ? null : chain.amount * units / amount.units;
      if (matchOf(candidate, paid) == null) return candidate;
    }
  }
  return null;
}

/// Whether a payment of [needed] XMR with its fee may use coins that came in less than the window ago. The check counts
/// the coins of the [balance] that came in before the window, takes the newest coins last, and finds when the payment
/// no longer needs coins that new.
FreshCoins? _freshCoins(
  XmrAmount needed,
  XmrAmount balance,
  List<WalletTransfer> incoming,
  List<BridgeSwap> swaps,
  DateTime now,
) {
  final fresh = [
    for (final transfer in incoming)
      if (now.difference(transfer.time) < AppConfig.privacyFreshWindow) transfer,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (fresh.isEmpty) return null;
  final freshUnits = fresh.fold<int>(0, (sum, transfer) => sum + transfer.amount.units);
  var held = max(0, balance.units - freshUnits);
  if (needed.units <= held) return null;
  final fromChainHashes = {
    for (final swap in swaps)
      if (swap.direction == SwapDirection.receive && swap.payoutHash != null) swap.payoutHash!,
  };
  var fromChain = false;
  for (final transfer in fresh) {
    held += transfer.amount.units;
    fromChain = fromChain || fromChainHashes.contains(transfer.hash);
    if (held >= needed.units) {
      return FreshCoins(
        since: transfer.time,
        clearsAt: transfer.time.add(AppConfig.privacyFreshWindow),
        fromChain: fromChain,
      );
    }
  }
  final newest = fresh.last;
  return FreshCoins(since: newest.time, clearsAt: newest.time.add(AppConfig.privacyFreshWindow), fromChain: fromChain);
}

/// What ties a payment to [recipient] to another swap of the user: from the records of the swaps, or from the [links]
/// of a scan of the recipient, which also know the receives whose coin it sent in. A receive ties it, since the user
/// gave the address there or sent from it. An earlier payment ties it only when the user scanned it as an address of
/// theirs ([ownAddresses]), since paying someone again is how payments go.
OwnAddress? ownAddressOf(
  String recipient,
  List<BridgeSwap> swaps, {
  Iterable<String> ownAddresses = const [],
  List<KranoxLink>? links,
}) {
  final found = links ?? kranoxLinks(recipient, swaps);
  if (found.where((link) => link is! GotPay).firstOrNull case final receive?) return OwnAddress(receive);
  final target = recipient.toLowerCase();
  final yours = ownAddresses.any((address) => address.toLowerCase() == target);
  final paid = found.whereType<GotPay>().firstOrNull;
  return yours && paid != null ? OwnAddress(paid) : null;
}

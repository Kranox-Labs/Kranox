import 'dart:math';

import '../bridge/models.dart';
import '../config/app_config.dart';
import '../core/amount.dart';
import '../wallet/models.dart';

/// A subaddress of this wallet that took more than one payment.
final class ReusedSubaddress {
  const ReusedSubaddress({required this.index, required this.payments});

  final int index;
  final int payments;
}

/// A receive from Robinhood Chain and a later payment to it that sit close in time or in amount, so that someone who
/// watches the chain can match the coin that went in with the coin that came out.
final class SwapPair {
  const SwapPair({required this.receive, required this.pay, required this.closeInTime, required this.closeInAmount});

  final BridgeSwap receive;
  final BridgeSwap pay;
  final bool closeInTime;
  final bool closeInAmount;
}

/// An address on Robinhood Chain that the user gave as the refund address of a receive and later paid from XMR.
final class LinkedRefund {
  const LinkedRefund({required this.address, required this.receivedAt, required this.paidAt});

  final String address;

  /// When the user made the receive with this refund address.
  final DateTime receivedAt;

  /// When the user paid this address from XMR.
  final DateTime paidAt;
}

/// XMR that came in less than [AppConfig.privacyFreshWindow] ago.
final class NewCoins {
  const NewCoins({required this.amount, required this.allOlderAt});

  final XmrAmount amount;

  /// When all of it came in longer ago than the window.
  final DateTime allOlderAt;
}

/// What the menu Privacy found for the whole wallet, from the history on this Mac. The owner decided on 7 Oct 2026
/// that the privacy check also has a menu of its own.
final class WalletPrivacyReport {
  const WalletPrivacyReport({
    required this.node,
    required this.ownNode,
    required this.reused,
    required this.pairs,
    required this.links,
    required this.newCoins,
  });

  final String node;

  /// Whether the node runs on this Mac or in its own network, so that no outside node sees the requests of the wallet.
  final bool ownNode;

  /// The subaddresses that took more than one payment, the most payments first.
  final List<ReusedSubaddress> reused;

  /// The swaps that sit close in time or in amount, the newest first.
  final List<SwapPair> pairs;

  /// The refund addresses that the user paid from XMR, the newest first.
  final List<LinkedRefund> links;

  /// New XMR in the balance. Time alone fixes it, so it counts as a note and not as something to improve.
  final NewCoins? newCoins;

  int get toImprove => [!ownNode, reused.isNotEmpty, pairs.isNotEmpty, links.isNotEmpty].where((found) => found).length;
}

/// Checks the privacy of the whole wallet: its [node], what came in ([transfers]), the swaps of the bridge ([swaps]),
/// and the [balance].
WalletPrivacyReport checkWallet({
  required String node,
  required List<WalletTransfer> transfers,
  required List<BridgeSwap> swaps,
  required XmrAmount balance,
  required DateTime now,
}) {
  final incoming = [
    for (final transfer in transfers)
      if (transfer.direction == TransferDirection.incoming && !transfer.isFailed) transfer,
  ];
  return WalletPrivacyReport(
    node: node,
    ownNode: isOwnNode(node),
    reused: _reused(incoming),
    pairs: _pairs(swaps),
    links: _links(swaps),
    newCoins: _newCoins(incoming, balance, now),
  );
}

/// Whether the host of [node] is this Mac or an address of a private network: localhost, a loopback address, an
/// address of RFC 1918 or a link-local one, a unique local address of IPv6, or a name of mDNS that ends in `.local`.
bool isOwnNode(String node) {
  final host = _hostOf(node).toLowerCase();
  if (host == 'localhost' || host.endsWith('.local')) return true;
  if (host.contains(':')) {
    return host == '::1' || host.startsWith('fe80:') || host.startsWith('fc') || host.startsWith('fd');
  }
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((octet) => octet == null || octet < 0 || octet > 255)) return false;
  final a = octets[0]!;
  final b = octets[1]!;
  return a == 127 || a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 169 && b == 254);
}

/// The host of a node address of the form `host:port` or `[ipv6]:port`.
String _hostOf(String node) {
  final value = node.trim();
  if (value.startsWith('[')) {
    final end = value.indexOf(']');
    return end < 0 ? value : value.substring(1, end);
  }
  final colon = value.lastIndexOf(':');
  return colon < 0 ? value : value.substring(0, colon);
}

List<ReusedSubaddress> _reused(List<WalletTransfer> incoming) {
  final counts = <int, int>{};
  for (final transfer in incoming) {
    final index = transfer.subaddressIndex;
    if (index != null) counts.update(index, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final MapEntry(key: index, value: payments) in counts.entries)
      if (payments > 1) ReusedSubaddress(index: index, payments: payments),
  ]..sort((a, b) => b.payments.compareTo(a.payments));
}

/// The pairs of a receive whose coin went in and a later payment whose XMR left: close in time when the payment
/// followed the XMR of the receive within the window of the timing, and close in amount when the coin of both is the
/// same and within the tolerance on the chain, within the window of the amount.
List<SwapPair> _pairs(List<BridgeSwap> swaps) {
  final receives = [
    for (final swap in swaps)
      if (swap.direction == SwapDirection.receive && swap.depositHash != null) swap,
  ];
  final pays = [
    for (final swap in swaps)
      if (swap.direction == SwapDirection.pay && swap.depositHash != null) swap,
  ];
  final pairs = <SwapPair>[];
  for (final pay in pays) {
    for (final receive in receives) {
      final cameIn = receive.updatedAt ?? receive.createdAt;
      final gap = pay.createdAt.difference(cameIn);
      final closeInTime = !gap.isNegative && gap < AppConfig.privacyFreshWindow;
      final apart = pay.createdAt.difference(receive.createdAt).abs();
      final closeInAmount =
          pay.asset == receive.asset &&
          apart <= AppConfig.privacyAmountWindow &&
          (pay.amount - receive.amount).abs() <= AppConfig.privacyChainTolerance * max(pay.amount, receive.amount);
      if (closeInTime || closeInAmount) {
        pairs.add(SwapPair(receive: receive, pay: pay, closeInTime: closeInTime, closeInAmount: closeInAmount));
      }
    }
  }
  return pairs..sort((a, b) => b.pay.createdAt.compareTo(a.pay.createdAt));
}

/// The refund addresses of receives that the user later paid from XMR, one for each address, with its newest payment.
List<LinkedRefund> _links(List<BridgeSwap> swaps) {
  final refunds = <String, DateTime>{};
  for (final swap in swaps) {
    final refund = swap.refundAddress;
    if (swap.direction != SwapDirection.receive || refund == null) continue;
    final key = refund.toLowerCase();
    final known = refunds[key];
    if (known == null || swap.createdAt.isAfter(known)) refunds[key] = swap.createdAt;
  }
  final links = <String, LinkedRefund>{};
  for (final swap in swaps) {
    if (swap.direction != SwapDirection.pay) continue;
    final key = swap.payoutAddress.toLowerCase();
    final receivedAt = refunds[key];
    if (receivedAt == null) continue;
    final known = links[key];
    if (known == null || swap.createdAt.isAfter(known.paidAt)) {
      links[key] = LinkedRefund(address: swap.payoutAddress, receivedAt: receivedAt, paidAt: swap.createdAt);
    }
  }
  return links.values.toList()..sort((a, b) => b.paidAt.compareTo(a.paidAt));
}

NewCoins? _newCoins(List<WalletTransfer> incoming, XmrAmount balance, DateTime now) {
  final fresh = [
    for (final transfer in incoming)
      if (now.difference(transfer.time) < AppConfig.privacyFreshWindow) transfer,
  ];
  if (fresh.isEmpty) return null;
  // New XMR that already left the wallet is no longer in the balance.
  final units = min(fresh.fold<int>(0, (sum, transfer) => sum + transfer.amount.units), balance.units);
  if (units <= 0) return null;
  final newest = fresh.map((transfer) => transfer.time).reduce((a, b) => a.isAfter(b) ? a : b);
  return NewCoins(amount: XmrAmount(units), allOlderAt: newest.add(AppConfig.privacyFreshWindow));
}

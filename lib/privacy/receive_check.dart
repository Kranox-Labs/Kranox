import '../bridge/models.dart';
import '../wallet/models.dart';
import 'wallet_privacy.dart';

// The privacy checks before a receive, which the owner asked for on 10 Oct 2026 ("sebelum user eksekusi receive ada
// layer privacy check dulu"): on the receive page, the payments that the subaddress it gives out already took; on the
// review of a receive from Robinhood Chain, whether the user ever paid the refund address from XMR.

/// How many payments came in to the subaddress [index]: payers of the same subaddress can tell that they paid the same
/// person.
int paymentsTo(int index, List<WalletTransfer> transfers) =>
    incomingTransfers(transfers).where((transfer) => transfer.subaddressIndex == index).length;

/// When the user last paid [address] on Robinhood Chain from XMR, or null. A refund address that the user also paid
/// from XMR ties both sides of the bridge together, as the check "Refund addresses" of the menu Privacy reads it after
/// the fact.
DateTime? lastPaidFromXmr(String address, List<BridgeSwap> swaps) {
  final target = address.toLowerCase();
  DateTime? paidAt;
  for (final swap in swaps) {
    if (swap.direction != SwapDirection.pay || swap.payoutAddress.toLowerCase() != target) continue;
    if (paidAt == null || swap.createdAt.isAfter(paidAt)) paidAt = swap.createdAt;
  }
  return paidAt;
}

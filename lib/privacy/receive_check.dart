import '../wallet/models.dart';
import 'wallet_privacy.dart';

// The privacy checks before a receive, which the owner asked for on 10 Oct 2026 ("sebelum user eksekusi receive ada
// layer privacy check dulu"): on the receive page, the payments that the subaddress it gives out already took. The
// review of a receive from Robinhood Chain reads the swaps of its refund address with kranoxLinks of chain_privacy.

/// How many payments came in to the subaddress [index]: payers of the same subaddress can tell that they paid the same
/// person.
int paymentsTo(int index, List<WalletTransfer> transfers) =>
    incomingTransfers(transfers).where((transfer) => transfer.subaddressIndex == index).length;

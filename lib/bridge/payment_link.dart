import '../config/app_config.dart';
import 'models.dart';

/// The payment link of EIP-681 for a deposit of [amount] of [asset] to [address] on Robinhood Chain, for the code of a
/// deposit: a wallet that reads such links proposes a send on the right chain, of the right coin, and of the amount,
/// instead of a send of a bare address on whatever chain it has open (K-22 of the security review of 0.2.0). [amount]
/// is the decimal text that the card shows; an amount with more decimals than the coin has goes out of the link, and
/// the wallet asks for it.
String depositLink({required BridgeAsset asset, required String address, required String amount}) {
  final units = baseUnits(amount, asset.decimals);
  final chain = AppConfig.robinhoodChainId;
  final contract = asset.contract;
  if (contract == null) {
    return units == null ? 'ethereum:$address@$chain' : 'ethereum:$address@$chain?value=$units';
  }
  final value = units == null ? '' : '&uint256=$units';
  return 'ethereum:$contract@$chain/transfer?address=$address$value';
}

/// The whole number of the smallest units of a coin of [decimals] in the decimal text [amount], such as 5500000000000000
/// for 0.0055 ETH, or null when [amount] has more decimals than the coin or is no plain decimal.
String? baseUnits(String amount, int decimals) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(amount);
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  if (fraction.length > decimals) return null;
  return BigInt.parse('${match.group(1)}${fraction.padRight(decimals, '0')}').toString();
}

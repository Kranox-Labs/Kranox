import '../bridge/client.dart';
import '../config/app_config.dart';
import '../config/network.dart';
import '../core/address.dart';
import '../core/amount.dart';
import '../core/evm_address.dart';
import '../core/seed.dart';
import '../wallet/failure.dart';
import 'copy.dart';

/// The number of decimals of an amount in a list or on a card. The send screen shows every decimal.
const int listDecimals = 4;

/// The number of characters that a short address keeps at each end.
const int _shortAddressEnds = 4;

String formatAmount(XmrAmount amount) => amount.toFixed(listDecimals);

/// Writes the time of a transaction: the hour of today, or the day of another date.
String formatTime(DateTime time, DateTime now) {
  final local = time.toLocal();
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return Copy.today('$hour:$minute');
  }
  final day = '${local.day} ${Copy.months[local.month - 1]}';
  return local.year == now.year ? day : '$day ${local.year}';
}

/// Shortens an address or a transaction id to its first and last characters.
String shortText(String text) => text.length <= _shortAddressEnds * 2 + 1
    ? text
    : '${text.substring(0, _shortAddressEnds)}…${text.substring(text.length - _shortAddressEnds)}';

String failureText(WalletException error) => switch (error.failure) {
  WalletFailure.wrongPassword => Copy.wrongPassword,
  WalletFailure.walletMissing => Copy.walletMissing,
  WalletFailure.notEnoughUnlocked => Copy.notEnoughUnlocked,
  WalletFailure.nodeUnreachable => Copy.nodeUnreachable,
  WalletFailure.native => Copy.walletReported(error.detail),
};

/// Says what is wrong with an address for a wallet on [network].
String addressProblemText(AddressException error, MoneroNetwork network) => switch (error.problem) {
  AddressProblem.empty => Copy.addressEmpty,
  AddressProblem.wrongLength => Copy.addressLength,
  AddressProblem.notBase58 => Copy.addressNotBase58,
  AddressProblem.badChecksum => Copy.addressChecksum,
  AddressProblem.otherNetwork => Copy.addressOtherNetwork(error.network ?? network, network),
  AddressProblem.unknownPrefix => Copy.addressUnknown,
};

String amountProblemText(AmountProblem problem) => switch (problem) {
  AmountProblem.empty => Copy.amountEmpty,
  AmountProblem.notANumber => Copy.amountNotANumber,
  AmountProblem.tooManyDecimals => Copy.amountTooManyDecimals,
  AmountProblem.tooLarge => Copy.amountTooLarge,
  AmountProblem.zero => Copy.amountZero,
};

String seedProblemText(SeedFormatException error) => switch (error.problem) {
  SeedProblem.wrongWordCount => Copy.seedWordCount(error.wordCount),
  SeedProblem.invalidCharacters => Copy.seedCharacters,
};

/// Checks a new password and its repetition. Gives the text of the problem, or null.
String? passwordProblem(String password, String repeated) {
  if (password.length < AppConfig.minPasswordLength) return Copy.passwordTooShort(AppConfig.minPasswordLength);
  if (password != repeated) return Copy.passwordMismatch;
  return null;
}

/// Writes an amount of the bridge with at most [decimals] decimals and no zeros at the end, such as 0.0271.
String formatDecimal(double value, {int decimals = 6}) {
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String bridgeFailureText(BridgeException error) => switch (error.failure) {
  BridgeFailure.relayDown => Copy.bridgeRelayDown,
  BridgeFailure.refused => Copy.bridgeRefused(error.detail),
  BridgeFailure.failed => Copy.bridgeFailed(error.detail),
  BridgeFailure.rateExpired => Copy.payRateExpired,
};

String evmAddressProblemText(EvmAddressProblem problem) => switch (problem) {
  EvmAddressProblem.empty || EvmAddressProblem.wrongForm => Copy.payRecipientWrongForm,
  EvmAddressProblem.badChecksum => Copy.payRecipientBadChecksum,
};

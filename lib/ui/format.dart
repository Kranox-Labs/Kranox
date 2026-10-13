import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../bridge/client.dart';
import '../config/app_config.dart';
import '../config/network.dart';
import '../core/address.dart';
import '../core/amount.dart';
import '../core/connection_probe.dart';
import '../core/evm_address.dart';
import '../core/seed.dart';
import '../wallet/controller.dart' show NodeReport, WalletController, isLongEnoughPassword;
import '../wallet/tor_service.dart' show TorState;
import '../wallet/failure.dart';
import '../wallet/models.dart';
import 'copy.dart';

/// The number of decimals of an amount in a list or on a card. The send screen shows every decimal.
const int listDecimals = 4;

/// The number of characters that a short address keeps at each end.
const int _shortAddressEnds = 4;

/// Lets an amount field take digits, then one point with at most [decimals] digits after it, and nothing else: a key or
/// a paste that would make anything else leaves the field as it was. Without [decimals], the field takes any number of
/// them, for a form that says itself when there are too many. A keyboard of numbers filters no keys on the desktop; on
/// 6 Oct 2026 the owner typed letters and signs into the amount of receive.
final class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({int? decimals})
    : _pattern = RegExp('^(\\d+(\\.\\d${decimals == null ? '*' : '{0,$decimals}'})?)?\$');

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

String formatAmount(XmrAmount amount) => amount.toFixed(listDecimals);

/// Writes the time of day with its seconds, such as when the app last checked a swap.
String formatClock(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

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

/// Writes how long ago something happened, such as "3 hours ago".
String formatAgo(Duration age) {
  if (age.inMinutes < 1) return Copy.justNow;
  if (age.inHours < 1) return Copy.minutesAgo(age.inMinutes);
  if (age.inDays < 1) return Copy.hoursAgo(age.inHours);
  return Copy.daysAgo(age.inDays);
}

/// Writes a moment to come with its hour: today, tomorrow, or its day.
String formatMoment(DateTime time, DateTime now) {
  final local = time.toLocal();
  final current = now.toLocal();
  // Calendar days, not spans of 24 hours, so that a change of the clock for summer time keeps "tomorrow".
  bool sameDay(DateTime day) => local.year == day.year && local.month == day.month && local.day == day.day;
  final hour = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (sameDay(current)) return Copy.todayAt(hour);
  if (sameDay(DateTime(current.year, current.month, current.day + 1))) return Copy.tomorrowAt(hour);
  return Copy.dayAt('${local.day} ${Copy.months[local.month - 1]}', hour);
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
  WalletFailure.walletClosed => Copy.walletClosed,
  WalletFailure.paymentChanged => Copy.paymentChanged,
  WalletFailure.deadlinePassed => Copy.deadlinePassed,
  WalletFailure.feeTooHigh => Copy.feeTooHigh(error.detail, AppConfig.maxNetworkFee.toExact()),
  WalletFailure.proxyRefused => Copy.proxyRefused,
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
  if (!isLongEnoughPassword(password)) return Copy.passwordTooShort(AppConfig.minPasswordLength);
  if (password != repeated) return Copy.passwordMismatch;
  return null;
}

/// Writes an amount of the bridge with at most [decimals] decimals and no zeros at the end, such as 0.0271.
/// Writes a limit of an amount at [decimals]: a minimum rounded up and a maximum rounded down, so that a limit on the
/// screen never lets an amount through that the exchanger refuses.
String formatLimit(double value, {required bool up, int decimals = 4}) {
  final scale = math.pow(10, decimals);
  final scaled = value * scale;
  return formatDecimal((up ? scaled.ceil() : scaled.floor()) / scale, decimals: decimals);
}

String formatDecimal(double value, {int decimals = 6}) {
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The words about the trouble with the node for the home page and the sidebar: what the look of the app found, or
/// that it runs; null while the node answers, and before the first look.
String? nodeTroubleText(WalletController controller) {
  if (controller.status.connection != NodeConnection.disconnected) return null;
  // The wallet waits for Tor built into the app before it reaches its node: the words say so, before any look.
  if (controller.waitsForTor) {
    return controller.tor?.state == TorState.failed ? Copy.torFailed : Copy.torStarting;
  }
  if (controller.torNameFailed) return Copy.nodeTroubleTorName(controller.node);
  if (controller.proxyRefused) return Copy.proxyRefused;
  final NodeReport? report = controller.nodeReport;
  if (report == null) return controller.lookingForNode ? Copy.nodeLooking : null;
  // The words name what the look tried, not a setting that came after it. The proxy of Tor built into the app is
  // no setting of the user, so the words name Tor rather than its address.
  final node = report.node;
  final proxy = report.proxy ?? '';
  final tor = controller.torBuiltIn;
  return switch (report.trouble) {
    ConnectionTrouble.proxyDown => tor ? Copy.nodeTroubleTorProxy : Copy.nodeTroubleProxyDown(proxy),
    ConnectionTrouble.proxyNotSocks5 => tor ? Copy.nodeTroubleTorProxy : Copy.nodeTroubleNotSocks5(proxy),
    ConnectionTrouble.hostUnreachableThroughProxy =>
      tor ? Copy.nodeTroubleThroughTor(node) : Copy.nodeTroubleThroughProxy(node, proxy),
    ConnectionTrouble.hostNameUnknown => Copy.nodeTroubleNameUnknown(node),
    ConnectionTrouble.hostDown => Copy.nodeTroubleDown(node),
    ConnectionTrouble.lookFailed => Copy.nodeTroubleLookFailed,
    ConnectionTrouble.torNotReady => Copy.torStarting,
    null => Copy.nodeTroubleSilent(node),
  };
}

/// The reason of a failed start of Tor built into the app, as one line for the settings page: the text of the
/// failure without its line breaks, cut short.
String torFailureText(Object failure) {
  final line = failure.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return line.length > 240 ? '${line.substring(0, 239)}…' : line;
}

/// The words about the trouble with the relay, which the look of the app found; with [tor], the proxy is Tor built
/// into the app, which the words name rather than its address.
String relayTroubleText(ConnectionTrouble trouble, {required String? proxy, bool tor = false}) => switch (trouble) {
  ConnectionTrouble.proxyDown => tor ? Copy.nodeTroubleTorProxy : Copy.relayTroubleProxyDown(proxy ?? ''),
  ConnectionTrouble.proxyNotSocks5 => tor ? Copy.nodeTroubleTorProxy : Copy.relayTroubleNotSocks5(proxy ?? ''),
  ConnectionTrouble.lookFailed => Copy.relayTroubleLookFailed,
  ConnectionTrouble.hostUnreachableThroughProxy =>
    tor ? Copy.relayTroubleThroughTor : Copy.relayTroubleThroughProxy(proxy ?? ''),
  ConnectionTrouble.hostNameUnknown => Copy.relayTroubleNameUnknown,
  ConnectionTrouble.hostDown => Copy.relayTroubleDown,
  ConnectionTrouble.torNotReady => Copy.relayTroubleTor,
};

/// The words of a failure of the bridge; a relay that does not answer names the trouble that the look found, if any.
String bridgeFailureText(BridgeException error, {ConnectionTrouble? relayTrouble, String? proxy, bool tor = false}) =>
    switch (error.failure) {
      BridgeFailure.relayDown =>
        relayTrouble == null
            ? Copy.bridgeRelayDown
            : '${Copy.bridgeRelayDown} ${relayTroubleText(relayTrouble, proxy: proxy, tor: tor)}',
      BridgeFailure.refused => Copy.bridgeRefused(error.detail),
      BridgeFailure.failed => Copy.bridgeFailed(error.detail),
      BridgeFailure.rateExpired => Copy.payRateExpired,
    };

String evmAddressProblemText(EvmAddressProblem problem) => switch (problem) {
  EvmAddressProblem.empty || EvmAddressProblem.wrongForm => Copy.payRecipientWrongForm,
  EvmAddressProblem.badChecksum => Copy.payRecipientBadChecksum,
};

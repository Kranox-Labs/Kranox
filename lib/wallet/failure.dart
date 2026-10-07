/// The ways in which a call to the wallet can fail. The screens show a sentence for each one.
enum WalletFailure {
  wrongPassword,
  walletMissing,
  notEnoughUnlocked,
  nodeUnreachable,

  /// The wallet closed, by a lock, a change of network, or the end of the app, before the call reached it.
  walletClosed,

  /// The payment under review is not the one that the wallet built last, or the wallet holds none: nothing was sent.
  paymentChanged,

  /// The time until which a payment had to leave has passed: nothing was sent.
  deadlinePassed,
  native,
}

/// A failed call to the wallet. [detail] holds the message of wallet2, for the cases that the app does not name.
final class WalletException implements Exception {
  const WalletException(this.failure, this.detail);

  final WalletFailure failure;
  final String detail;

  /// Names the failure from the message of wallet2.
  factory WalletException.fromNative(String message) {
    final text = message.toLowerCase();
    final failure = switch (text) {
      _ when text.contains('invalid password') => WalletFailure.wrongPassword,
      _ when text.contains('file not found') => WalletFailure.walletMissing,
      _ when text.contains('not enough') => WalletFailure.notEnoughUnlocked,
      _ when text.contains('no connection to daemon') || text.contains('failed to connect') =>
        WalletFailure.nodeUnreachable,
      _ => WalletFailure.native,
    };
    return WalletException(failure, message);
  }

  @override
  String toString() => 'WalletException(${failure.name}): $detail';
}

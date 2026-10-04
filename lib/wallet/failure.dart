/// The ways in which a call to the wallet can fail. The screens show a sentence for each one.
enum WalletFailure { wrongPassword, walletMissing, notEnoughUnlocked, nodeUnreachable, native }

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

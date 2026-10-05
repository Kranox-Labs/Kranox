import 'dart:math' as math;

/// The blocks that Monero puts on top of a new output before the output can be spent. A payment in and the change of
/// a payment out both wait this long. CHECKED 5 Oct 2026: CRYPTONOTE_DEFAULT_TX_SPENDABLE_AGE in
/// src/cryptonote_config.h of monero-project/monero at v0.18.4.2, which wallet2 compares with the confirmations.
const int spendableAge = 10;

/// The target time of one block of Monero. A block can come sooner or later, so a wait in blocks gives an estimate in
/// time only. CHECKED 5 Oct 2026: DIFFICULTY_TARGET_V2 in the same file, 120 seconds.
const Duration blockTarget = Duration(seconds: 120);

/// How far one transfer is on its way to coins that the wallet can spend.
final class UnlockProgress {
  /// [confirmations] counts the blocks on top of the transfer: 0 while it waits in the pool of the node.
  UnlockProgress(int confirmations) : confirmations = math.max(0, math.min(confirmations, spendableAge));

  /// The confirmations that count toward the unlock, from 0 to [spendableAge].
  final int confirmations;

  /// The progress of the transfer that unlocks last among [all], or null when every one has unlocked.
  static UnlockProgress? slowest(Iterable<UnlockProgress> all) {
    UnlockProgress? slowest;
    for (final progress in all) {
      if (progress.isUnlocked) continue;
      if (slowest == null || progress.confirmations < slowest.confirmations) slowest = progress;
    }
    return slowest;
  }

  int get blocksLeft => spendableAge - confirmations;

  bool get isUnlocked => blocksLeft == 0;

  /// The time that the blocks left take on average.
  Duration get timeLeft => blockTarget * blocksLeft;

  /// The share of the wait that is behind the transfer, from 0 to 1.
  double get share => confirmations / spendableAge;
}

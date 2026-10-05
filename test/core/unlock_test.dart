import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/unlock.dart';

void main() {
  group('UnlockProgress', () {
    test('counts the blocks and the minutes left until the coins unlock', () {
      final waiting = UnlockProgress(0);
      expect(waiting.blocksLeft, 10);
      expect(waiting.timeLeft, const Duration(minutes: 20));
      expect(waiting.share, 0);
      expect(waiting.isUnlocked, isFalse);

      final halfway = UnlockProgress(2);
      expect(halfway.blocksLeft, 8);
      expect(halfway.timeLeft, const Duration(minutes: 16));
      expect(halfway.share, 0.2);

      final last = UnlockProgress(9);
      expect(last.blocksLeft, 1);
      expect(last.timeLeft, const Duration(minutes: 2));
    });

    test('holds the confirmations between none and the spendable age', () {
      expect(UnlockProgress(-1).confirmations, 0);
      expect(UnlockProgress(10).isUnlocked, isTrue);
      expect(UnlockProgress(63).confirmations, 10);
      expect(UnlockProgress(63).timeLeft, Duration.zero);
      expect(UnlockProgress(63).share, 1);
    });
  });

  group('UnlockProgress.slowest', () {
    List<UnlockProgress> of(List<int> confirmations) => confirmations.map(UnlockProgress.new).toList();

    test('picks the transfer that unlocks last', () {
      expect(UnlockProgress.slowest(of([63, 2, 9]))?.confirmations, 2);
      expect(UnlockProgress.slowest(of([14, 0, 5]))?.confirmations, 0);
    });

    test('gives nothing when every transfer has unlocked', () {
      expect(UnlockProgress.slowest(of([10, 15, 68])), isNull);
      expect(UnlockProgress.slowest(of([])), isNull);
    });
  });
}

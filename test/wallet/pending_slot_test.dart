import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/wallet/failure.dart';
import 'package:kranox_wallet/wallet/pending_slot.dart';

Matcher _failsWith(WalletFailure failure) =>
    throwsA(isA<WalletException>().having((error) => error.failure, 'failure', failure));

void main() {
  const plain = 'address-of-the-plain-send';
  const deposit = 'deposit-of-the-exchanger';
  const now = 1000000;

  test('sends the payment that a review names', () {
    final slot = PendingSlot<String>();
    final id = slot.put('payment', address: plain, units: 50);
    expect(slot.take(id: id, address: plain, units: 50, now: now), 'payment');
    expect(
      () => slot.take(id: id, address: plain, units: 50, now: now),
      _failsWith(WalletFailure.paymentChanged),
      reason: 'a payment leaves once',
    );
  });

  test('sends no payment that another screen built later', () {
    // Pay builds its deposit while the plain review is open: the plain confirm must not send the deposit.
    final slot = PendingSlot<String>();
    final plainId = slot.put('plain payment', address: plain, units: 50);
    final payId = slot.put('deposit payment', address: deposit, units: 160);
    expect(() => slot.take(id: plainId, address: plain, units: 50, now: now), _failsWith(WalletFailure.paymentChanged));
    expect(slot.take(id: payId, address: deposit, units: 160, now: now), 'deposit payment');
  });

  test('sends no payment whose address or amount differs from its review', () {
    final slot = PendingSlot<String>();
    final id = slot.put('payment', address: deposit, units: 160);
    expect(() => slot.take(id: id, address: plain, units: 160, now: now), _failsWith(WalletFailure.paymentChanged));
    final again = slot.put('payment', address: deposit, units: 160);
    expect(
      () => slot.take(id: again, address: deposit, units: 161, now: now),
      _failsWith(WalletFailure.paymentChanged),
    );
  });

  test('a cancel drops only the payment that it names', () {
    final slot = PendingSlot<String>();
    final plainId = slot.put('plain payment', address: plain, units: 50);
    final payId = slot.put('deposit payment', address: deposit, units: 160);
    slot.drop(plainId);
    expect(slot.take(id: payId, address: deposit, units: 160, now: now), 'deposit payment');
  });

  test('sends nothing after its deadline, and drops the payment', () {
    final slot = PendingSlot<String>();
    final id = slot.put('payment', address: deposit, units: 160);
    expect(
      () => slot.take(id: id, address: deposit, units: 160, deadline: now, now: now),
      _failsWith(WalletFailure.deadlinePassed),
    );
    expect(() => slot.take(id: id, address: deposit, units: 160, now: now), _failsWith(WalletFailure.paymentChanged));
    final early = slot.put('payment', address: deposit, units: 160);
    expect(slot.take(id: early, address: deposit, units: 160, deadline: now + 1, now: now), 'payment');
  });

  test('gives each built payment a new id', () {
    final slot = PendingSlot<String>();
    final first = slot.put('a', address: plain, units: 1);
    final second = slot.put('b', address: plain, units: 1);
    expect(second, isNot(first));
    expect(() => slot.take(id: first, address: plain, units: 1, now: now), _failsWith(WalletFailure.paymentChanged));
  });
}

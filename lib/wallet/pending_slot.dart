import 'failure.dart';

/// The payment that wallet2 built last and has not sent, with what the review of it shows. One slot serves the plain
/// send and pay, so a confirm names the payment that its screen shows, and the slot gives it up only when it is that
/// payment. [T] is the built payment of wallet2; a test uses any value.
final class PendingSlot<T extends Object> {
  T? _payment;
  ({int id, String address, int units})? _built;
  int _lastId = 0;

  /// Keeps [payment], built to [address] for [units] atomic units, in place of any other, and gives its new id.
  int put(T payment, {required String address, required int units}) {
    final id = ++_lastId;
    _payment = payment;
    _built = (id: id, address: address, units: units);
    return id;
  }

  /// Gives the payment that a confirm sends and empties the slot. The confirm names the payment by [id], with the
  /// [address] and the [units] that its review shows; with [deadline], in milliseconds since the epoch, it must come
  /// before that time, which [now] gives. Throws a [WalletException] when the slot holds another payment or none, or
  /// when the deadline has passed; then nothing may leave.
  T take({required int id, required String address, required int units, int? deadline, required int now}) {
    final payment = _payment;
    final built = _built;
    if (payment == null || built == null || built.id != id || built.address != address || built.units != units) {
      throw const WalletException(WalletFailure.paymentChanged, 'The wallet holds no payment that matches the review.');
    }
    clear();
    if (deadline != null && now >= deadline) {
      throw const WalletException(WalletFailure.deadlinePassed, 'The payment had to leave before its deadline.');
    }
    return payment;
  }

  /// Drops the payment with [id]. A payment that the wallet built after it, for another screen, stays.
  void drop(int id) {
    if (_built?.id == id) clear();
  }

  void clear() {
    _payment = null;
    _built = null;
  }
}

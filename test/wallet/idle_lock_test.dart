import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/wallet/idle_lock.dart';

void main() {
  late DateTime clock;
  late bool open;
  late int locks;
  late IdleLock idle;

  setUp(() {
    clock = DateTime.utc(2026, 10, 7, 12);
    open = true;
    locks = 0;
    idle = IdleLock(
      isOpen: () => open,
      lock: () async {
        locks++;
        open = false;
      },
      now: () => clock,
    );
  });

  test('locks an open wallet after the time without use', () async {
    clock = clock.add(AppConfig.idleLockAfter - const Duration(seconds: 1));
    await idle.check();
    expect(locks, 0);
    clock = clock.add(const Duration(seconds: 1));
    await idle.check();
    expect(locks, 1);
  });

  test('each use starts the time again', () async {
    clock = clock.add(const Duration(minutes: 9));
    idle.touch();
    clock = clock.add(const Duration(minutes: 9));
    await idle.check();
    expect(locks, 0);
  });

  test('a Mac that slept longer finds its wallet locked at the first check', () async {
    // A timer stands still while the Mac sleeps; the clock does not.
    clock = clock.add(const Duration(hours: 8));
    await idle.check();
    expect(locks, 1);
  });

  test('locks nothing when the wallet is not open, and locks once', () async {
    open = false;
    clock = clock.add(const Duration(hours: 1));
    await idle.check();
    expect(locks, 0);
    open = true;
    await Future.wait([idle.check(), idle.check()]);
    expect(locks, 1);
  });
}

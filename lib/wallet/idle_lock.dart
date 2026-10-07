import 'dart:async';

import '../config/app_config.dart';

/// Locks an open wallet after a time without use. It reads the clock of the Mac, not the time that a timer counts, so
/// a Mac that slept for longer than [after] finds its wallet locked at the next check.
final class IdleLock {
  IdleLock({
    required this._isOpen,
    required this._lock,
    DateTime Function() now = DateTime.now,
    this.after = AppConfig.idleLockAfter,
  }) : _now = now,
       _lastUse = now();

  final bool Function() _isOpen;
  final Future<void> Function() _lock;
  final DateTime Function() _now;
  final Duration after;

  DateTime _lastUse;
  bool _locking = false;
  Timer? _timer;

  /// A key, a click, or a move of the pointer.
  void touch() => _lastUse = _now();

  /// Locks the wallet when it is open and nobody used the app for [after].
  Future<void> check() async {
    if (_locking || !_isOpen() || _now().difference(_lastUse) < after) return;
    _locking = true;
    try {
      await _lock();
    } finally {
      _locking = false;
      touch();
    }
  }

  /// Checks at [interval] until [stop].
  void start({Duration interval = AppConfig.idleCheckInterval}) {
    _timer ??= Timer.periodic(interval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

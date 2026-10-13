import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/socks.dart';
import '../core/tor_engine.dart';

/// Where Tor built into the app stands.
enum TorState {
  /// Not running: the wallet reaches the node and the relay straight, or through a proxy of the user.
  off,

  /// Starting and building its first circuits. The wallet reaches nothing until it is on.
  starting,

  /// Running, with its SOCKS5 proxy at [TorService.address], which answered the greeting of the app.
  on,

  /// It could not start, or its proxy stopped answering, with the reason in [TorService.failure]. The wallet reaches
  /// nothing until a new start works, or the user turns Tor built into the app off.
  failed,
}

/// A check of the proxy of Tor at an address, which throws when the proxy does not answer as a SOCKS5 proxy.
typedef ProxyProbe = Future<void> Function(String address);

/// Tor built into the app for the screens and the controller: its state, the address of its proxy while it is on,
/// and the start and the stop. The calls run one after the other, in the order they came, so that a start and a
/// stop never cross (W-06 of the scan of 13 Oct 2026): a stop while a start runs turns the state off at once, and
/// stops the engine once that start returns; a start takes at most [startTimeout], after which it fails; the proxy
/// must answer the greeting of the app before the state is on (W-04); and a proxy that stops answering later is
/// marked failed by the looks of the app ([markDead]).
final class TorService extends ChangeNotifier {
  TorService({required this._engine, ProxyProbe? probe, this.startTimeout = AppConfig.torStartTimeout})
    : _probe = probe ?? _greet;

  final TorEngine _engine;
  final ProxyProbe _probe;

  /// How long a start may take before it counts as failed.
  final Duration startTimeout;

  TorState _state = TorState.off;
  String? _address;
  Object? _failure;

  /// Whether the last call asked for Tor on; a start or a stop that finds the other wish changes nothing.
  bool _wantOn = false;

  /// Whether the engine runs, from a start that returned until a stop; a stop with nothing running changes nothing.
  bool _engineRunning = false;

  /// The calls in flight, one after the other.
  Future<void> _chain = Future<void>.value();

  TorState get state => _state;

  /// The SOCKS5 proxy of Tor, 127.0.0.1 and its port, while Tor is on; null otherwise.
  String? get address => _state == TorState.on ? _address : null;

  /// Why the last start failed, or why the proxy was marked dead, while the state is [TorState.failed].
  Object? get failure => _failure;

  /// Starts Tor, unless it is on already. The state is starting at once; the call completes once Tor is on, or
  /// failed.
  Future<void> start() {
    _wantOn = true;
    if (_state == TorState.off || _state == TorState.failed) _set(TorState.starting);
    return _enqueue(_startNow);
  }

  /// Stops Tor. The state is off at once, so that nothing reads the address meanwhile; a start in flight ends on its
  /// own, and the engine stops right after it.
  Future<void> stop() {
    _wantOn = false;
    if (_state != TorState.off) _set(TorState.off);
    return _enqueue(_stopNow);
  }

  /// Marks a Tor that is on as failed, for a look of the app that found its proxy not answering, so that the screens
  /// offer a new start and the wallet waits rather than point at a dead port.
  void markDead(Object reason) {
    if (_state != TorState.on) return;
    _set(TorState.failed, failure: reason);
  }

  Future<void> _enqueue(Future<void> Function() call) {
    final next = _chain.then((_) => call());
    _chain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _startNow() async {
    // A stop came after this start was asked, or Tor is on: nothing to do.
    if (!_wantOn || _state == TorState.on) return;
    if (_state != TorState.starting) _set(TorState.starting);
    try {
      final started = _engine.start();
      final port = await started.timeout(startTimeout);
      _engineRunning = true;
      if (!_wantOn) {
        // A stop came while the start ran: the state is off already; the engine stops now.
        await _stopEngine();
        return;
      }
      final address = '127.0.0.1:$port';
      await _probe(address).timeout(AppConfig.probeTimeout);
      _address = address;
      _set(TorState.on);
    } on Object catch (error) {
      // A start that failed, or that took too long, leaves nothing of itself running: a start that ends later stops
      // its engine then, unless a new start wants it.
      await _stopEngine();
      if (!_wantOn) return;
      _set(TorState.failed, failure: error);
    }
  }

  Future<void> _stopNow() async {
    // A start came after this stop was asked, or nothing runs: nothing to stop.
    if (_wantOn || !_engineRunning) return;
    try {
      await _stopEngine();
    } finally {
      if (_state != TorState.off) _set(TorState.off);
    }
  }

  Future<void> _stopEngine() async {
    _engineRunning = false;
    try {
      await _engine.stop().timeout(AppConfig.probeTimeout);
    } on Object {
      // An engine that fails to stop, or takes too long, is left to itself: nothing of the app points at it.
    }
  }

  void _set(TorState state, {Object? failure}) {
    _state = state;
    _failure = failure;
    if (state != TorState.on) _address = null;
    notifyListeners();
  }

  static Future<void> _greet(String address) => probeSocks5(proxy: address, timeout: AppConfig.probeTimeout);
}

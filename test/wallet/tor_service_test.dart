import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/tor_engine.dart';
import 'package:kranox_wallet/wallet/tor_service.dart';

/// An engine of the test: a start that the test completes, or fails, and a count of the starts and the stops.
final class _FakeTorEngine implements TorEngine {
  Completer<int> starting = Completer<int>();
  Object? failure;
  int starts = 0;
  int stops = 0;

  @override
  Future<int> start() {
    starts++;
    if (failure case final failure?) return Future<int>.error(failure);
    return starting.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> _answers(String address) async {}

void main() {
  test('starts once, checks its proxy, says that it is on with the address, and stops', () async {
    final engine = _FakeTorEngine();
    final probed = <String>[];
    final tor = TorService(engine: engine, probe: (address) async => probed.add(address));
    var changes = 0;
    tor.addListener(() => changes++);
    expect(tor.state, TorState.off);
    expect(tor.address, isNull);

    final first = tor.start();
    final second = tor.start();
    expect(tor.state, TorState.starting, reason: 'the state says so at once');
    await pumpEventQueue();
    engine.starting.complete(9150);
    await first;
    await second;
    expect(engine.starts, 1, reason: 'a second start while it starts joins the first');
    expect(tor.state, TorState.on);
    expect(tor.address, '127.0.0.1:9150');
    expect(probed, ['127.0.0.1:9150'], reason: 'the proxy answered the greeting before Tor counts as on (W-04)');
    await tor.start();
    expect(engine.starts, 1, reason: 'a start while it is on changes nothing');

    await tor.stop();
    expect(tor.state, TorState.off);
    expect(tor.address, isNull);
    expect(engine.stops, 1);
    await tor.stop();
    expect(engine.stops, 1, reason: 'a stop while it is off changes nothing');
    expect(changes, 3, reason: 'starting, on, off: the screens hear of each; the stop while off says nothing');
  });

  test('keeps the failure of a start, stops what the start left, and starts again on the next call', () async {
    final engine = _FakeTorEngine()..failure = StateError('no network');
    final tor = TorService(engine: engine, probe: _answers);
    await tor.start();
    expect(tor.state, TorState.failed);
    expect(tor.address, isNull);
    expect(tor.failure, isA<StateError>());
    expect(engine.stops, 1, reason: 'a start that failed leaves nothing of itself running');

    engine.failure = null;
    final again = tor.start();
    expect(tor.state, TorState.starting);
    expect(tor.failure, isNull);
    engine.starting.complete(9151);
    await again;
    expect(tor.state, TorState.on);
    expect(tor.address, '127.0.0.1:9151');
  });

  test('a proxy that does not answer the greeting leaves Tor failed, with the engine stopped (W-04)', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: (_) async => throw const FormatException('not SOCKS5'));
    final start = tor.start();
    engine.starting.complete(9152);
    await start;
    expect(tor.state, TorState.failed);
    expect(tor.failure, isA<FormatException>());
    expect(tor.address, isNull);
    expect(engine.stops, 1);
  });

  test('a stop during a start turns Tor off at once, and stops the engine once the start returns (W-05)', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: _answers);
    final start = tor.start();
    // The start reached the engine, which now bootstraps.
    await pumpEventQueue();
    expect(engine.starts, 1);
    final stop = tor.stop();
    expect(tor.state, TorState.off, reason: 'nothing waits for the start');
    expect(engine.stops, 0, reason: 'the engine cannot stop before its start returns');
    engine.starting.complete(9153);
    await start;
    await stop;
    expect(tor.state, TorState.off);
    expect(tor.address, isNull);
    expect(engine.stops, 1, reason: 'the proxy that the start opened is stopped');
  });

  test('a stop right after a start, before the engine heard of it, starts nothing', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: _answers);
    final start = tor.start();
    final stop = tor.stop();
    await start;
    await stop;
    expect(tor.state, TorState.off);
    expect(engine.starts, 0);
    expect(engine.stops, 0);
  });

  test('a start that takes too long fails, and the engine is stopped when it finally returns', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: _answers, startTimeout: const Duration(milliseconds: 50));
    await tor.start();
    expect(tor.state, TorState.failed);
    expect(tor.failure, isA<TimeoutException>());
    expect(engine.stops, 1);
  });

  test('two changes in a row end in the state of the last one (W-06)', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: _answers);
    // On, off, on while the first start runs: Tor ends on, with one engine running.
    final first = tor.start();
    final off = tor.stop();
    final again = tor.start();
    engine.starting.complete(9154);
    await first;
    await off;
    await again;
    expect(tor.state, TorState.on);
    expect(engine.starts, 1, reason: 'the engine of the first start serves the last call');
    expect(engine.stops, 0);
    // Off, on while the stop waits its turn: the stop finds the wish for Tor on and leaves the engine running, and
    // the start asks the running engine for its port again.
    final stop = tor.stop();
    engine.starting = Completer<int>();
    final back = tor.start();
    engine.starting.complete(9155);
    await stop;
    await back;
    expect(tor.state, TorState.on);
    expect(tor.address, '127.0.0.1:9155');
    expect(engine.stops, 0, reason: 'an engine that is wanted on again is not stopped');
    expect(engine.starts, 2);
  });

  test('a look that finds the proxy dead marks Tor failed, for a new start', () async {
    final engine = _FakeTorEngine();
    final tor = TorService(engine: engine, probe: _answers);
    final start = tor.start();
    engine.starting.complete(9156);
    await start;
    tor.markDead(const FormatException('gone'));
    expect(tor.state, TorState.failed);
    expect(tor.address, isNull);
    expect(tor.failure, isA<FormatException>());
    tor.markDead(const FormatException('again'));
    expect((tor.failure! as FormatException).message, 'gone', reason: 'only a Tor that is on can die');
  });
}

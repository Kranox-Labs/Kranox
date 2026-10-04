import 'dart:async';
import 'dart:isolate';

import 'engine.dart';
import 'failure.dart';
import 'requests.dart';

/// What the controller needs from a wallet engine: an answer to one request at a time, and a way to stop. The app
/// uses [WalletWorker]; a picture of the screens can answer with sample data instead.
abstract interface class WalletBackend {
  /// Sends one request and gives its answer. Throws a [WalletException] when the request fails.
  Future<T> call<T>(WalletRequest request);

  void stop();
}

/// The wallet engine in its own isolate. The calls of wallet2 block, some of them for seconds, so they run away
/// from the isolate that draws the screens. The worker answers one request at a time, in the order of arrival.
final class WalletWorker implements WalletBackend {
  WalletWorker._(this._isolate, this._requests);

  final Isolate _isolate;
  final SendPort _requests;

  static Future<WalletWorker> start({required String libraryPath}) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _runWorker,
      _WorkerStart(libraryPath: libraryPath, ready: ready.sendPort),
      debugName: 'wallet',
    );
    final requests = await ready.first as SendPort;
    ready.close();
    return WalletWorker._(isolate, requests);
  }

  @override
  Future<T> call<T>(WalletRequest request) async {
    final reply = ReceivePort();
    _requests.send(_Envelope(request, reply.sendPort));
    final answer = await reply.first as _Answer;
    reply.close();
    return switch (answer) {
      _Value(:final value) => value as T,
      _Failure(:final failure, :final detail) => throw WalletException(failure, detail),
      _Crash(:final message) => throw StateError('The wallet engine failed: $message'),
    };
  }

  @override
  void stop() => _isolate.kill(priority: Isolate.immediate);
}

final class _WorkerStart {
  const _WorkerStart({required this.libraryPath, required this.ready});

  final String libraryPath;
  final SendPort ready;
}

final class _Envelope {
  const _Envelope(this.request, this.reply);

  final WalletRequest request;
  final SendPort reply;
}

sealed class _Answer {
  const _Answer();
}

final class _Value extends _Answer {
  const _Value(this.value);

  final Object? value;
}

final class _Failure extends _Answer {
  const _Failure(this.failure, this.detail);

  final WalletFailure failure;
  final String detail;
}

/// An error that the engine did not expect, such as a call on a closed wallet. The worker passes it on.
final class _Crash extends _Answer {
  const _Crash(this.message);

  final String message;
}

void _runWorker(_WorkerStart start) {
  final engine = WalletEngine(libraryPath: start.libraryPath);
  final requests = ReceivePort();
  start.ready.send(requests.sendPort);
  requests.listen((message) {
    final envelope = message as _Envelope;
    try {
      envelope.reply.send(_Value(engine.handle(envelope.request)));
    } on WalletException catch (error) {
      envelope.reply.send(_Failure(error.failure, error.detail));
    } on Object catch (error, stack) {
      envelope.reply.send(_Crash('$error\n$stack'));
    }
  });
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'client.dart';

/// A quote that follows a form of the bridge: it asks a moment after the last change of the form, so that typing does
/// not send a request per key, and it drops an answer that comes for an older state of the form. [K] is what the
/// form asks for, such as a coin and an amount, and [Q] the answer of the relay.
final class LiveQuote<K, Q> {
  LiveQuote({required this._fetch, required this._onChanged});

  final Future<Q> Function(K key) _fetch;
  final VoidCallback _onChanged;
  K? _key;
  Q? _value;
  BridgeException? _error;
  bool _pending = false;
  bool _disposed = false;
  Timer? _timer;

  /// The answer for the form as it stands, or null while none has come.
  Q? get value => _value;
  BridgeException? get error => _error;

  /// Whether a quote for the form as it stands is on its way.
  bool get pending => _pending;

  /// Follows the form: [key] is what to quote, or null when the form holds nothing that the relay can quote.
  void follow(K? key) {
    _timer?.cancel();
    _key = key;
    _value = null;
    _error = null;
    _pending = key != null;
    if (key != null) _timer = Timer(AppConfig.bridgeQuoteDelay, () => _ask(key));
    _onChanged();
  }

  Future<void> _ask(K key) async {
    Q? value;
    BridgeException? error;
    try {
      value = await _fetch(key);
    } on BridgeException catch (failure) {
      error = failure;
    } on FormatException catch (failure) {
      error = BridgeException(BridgeFailure.failed, failure.message);
    }
    // The form may have changed while the quote was on its way, and a newer request follows then; or the form is gone.
    if (_disposed || key != _key) return;
    _value = value;
    _error = error;
    _pending = false;
    _onChanged();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

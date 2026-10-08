import 'package:flutter/foundation.dart';

import '../bridge/chain_scan.dart';
import '../bridge/client.dart';

/// The scans of addresses on Robinhood Chain that the user made while the wallet is open. The user pastes addresses
/// of their own, so each scanned address counts as one of theirs in the next scan.
final class ChainScans extends ChangeNotifier {
  ChainScans(this._client);

  final ChainScanClient _client;

  // The newest scan of each address, by its lowercase form, in the order of the scans.
  final Map<String, ChainScan> _scans = {};
  String? _current;
  bool _scanning = false;
  BridgeException? _error;
  bool _disposed = false;

  bool get scanning => _scanning;
  BridgeException? get error => _error;

  /// The scan on screen: the last one that worked.
  ChainScan? get current => _current == null ? null : _scans[_current];

  /// Every address that the user scanned while the wallet is open.
  List<String> get scanned => [for (final scan in _scans.values) scan.address];

  Future<void> scan(String address) async {
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      final result = await readScan(_client, address);
      final key = result.address.toLowerCase();
      _scans.remove(key);
      _scans[key] = result;
      _current = key;
    } on BridgeException catch (error) {
      _error = error;
    } finally {
      _scanning = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Asks [client] for the scan of [address], and turns an answer of the wrong form into a failure of the bridge, so that
/// a caller catches one kind of failure.
Future<ChainScan> readScan(ChainScanClient client, String address) async {
  try {
    return await client.scanAddress(address);
  } on FormatException catch (error) {
    throw BridgeException(BridgeFailure.failed, error.message);
  }
}

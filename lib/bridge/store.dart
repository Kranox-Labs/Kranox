import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/file_cipher.dart';
import 'models.dart';

/// The swaps of the bridge in a file of the support folder, so that the app follows a swap again after a restart.
/// The file holds the id, the amounts, the addresses, and the read token of each swap, no key of the wallet. It is
/// sealed with the key of the files of the open wallet (wallet O-007 of the second security review), so that it reads
/// only while that wallet is open: the store reads it with the key, keeps the key for its writes, and forgets it when
/// the wallet locks.
final class BridgeStore {
  BridgeStore(this.path);

  final String path;

  /// The cipher of the key of the open wallet, or null while no wallet is open.
  FileCipher? _cipher;

  // The writes, one at a time in the order of the calls, so that an older list never ends up after a newer one.
  Future<void> _writing = Future<void>.value();

  /// Where the last read moved a file that it could not read whole, or null. The entries that it could read go on.
  String? get recoveredFrom => _recoveredFrom;
  String? _recoveredFrom;

  /// Reads the swaps with [key], the key of the files of the open wallet, and keeps the key for the writes after it.
  /// A file that the app cannot read whole, after a crash, from a newer release, or of another wallet, moves aside
  /// with the time in its name, so that the app still starts and the file stays for support; the entries that read
  /// stay. The plain file of a release before the seal is sealed now.
  Future<List<BridgeSwap>> read(Uint8List key) async {
    final cipher = _cipher = FileCipher(key, purpose: _purpose);
    final file = File(path);
    if (!await file.exists()) return const [];
    final swaps = <BridgeSwap>[];
    var whole = true;
    var plain = false;
    try {
      var data = jsonDecode(await file.readAsString());
      if (FileCipher.isSealed(data)) {
        data = jsonDecode(cipher.open(data));
      } else {
        plain = true;
      }
      if (data is! List<Object?>) throw FormatException('The bridge file holds no list.', path);
      for (final item in data) {
        final swap = _readEntry(item);
        if (swap == null) {
          whole = false;
        } else {
          swaps.add(swap);
        }
      }
    } on FormatException {
      whole = false;
    }
    if (!whole) {
      final aside = '$path.unreadable-${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await file.rename(aside);
      _recoveredFrom = aside;
      await write(swaps);
    } else if (plain) {
      await write(swaps);
    }
    return swaps;
  }

  /// Forgets the key, as when the wallet locks. A write after it fails, until the next read.
  void close() => _cipher = null;

  /// One saved swap, or null for an entry that the app cannot read, such as one with an unknown stage.
  static BridgeSwap? _readEntry(Object? item) {
    if (item is! Map<String, Object?>) return null;
    try {
      return BridgeSwap.fromJson(item);
    } on FormatException {
      return null;
    } on ArgumentError {
      // An unknown name of an enum, such as a direction of a newer release.
      return null;
    }
  }

  /// Writes the swaps, sealed, through a temporary file and a rename, so that a crash leaves the old file or the new
  /// one, never a part of one. Throws a [StateError] while no wallet is open.
  Future<void> write(List<BridgeSwap> swaps) {
    final cipher = _cipher;
    if (cipher == null) throw StateError('The swaps of the bridge are closed while no wallet is open.');
    final text = cipher.seal(jsonEncode([for (final swap in swaps) swap.toJson()]));
    // The failure of an earlier write reached its own caller; this write runs either way.
    final next = _writing.then((_) => _replace(text), onError: (Object _) => _replace(text));
    _writing = next;
    return next;
  }

  Future<void> _replace(String text) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temporary = File('$path.tmp');
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(path);
  }

  /// The purpose of the seal, so that no other sealed file of the app opens as the swaps.
  static const String _purpose = 'kranox/bridge/1';
}

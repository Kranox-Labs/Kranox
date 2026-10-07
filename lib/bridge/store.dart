import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// The swaps of the bridge in a file of the support folder, so that the app follows a swap again after a restart.
/// The file holds the id, the amounts, and the addresses of each swap, no key.
final class BridgeStore {
  BridgeStore(this.path);

  final String path;

  // The writes, one at a time in the order of the calls, so that an older list never ends up after a newer one.
  Future<void> _writing = Future<void>.value();

  /// Where the last read moved a file that it could not read whole, or null. The entries that it could read go on.
  String? get recoveredFrom => _recoveredFrom;
  String? _recoveredFrom;

  /// Reads the swaps. A file that the app cannot read whole, after a crash or from a newer release, moves aside with
  /// the time in its name, so that the app still starts and the file stays for support; the entries that read stay.
  Future<List<BridgeSwap>> read() async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final swaps = <BridgeSwap>[];
    var whole = true;
    try {
      final data = jsonDecode(await file.readAsString());
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
    }
    return swaps;
  }

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

  /// Writes the swaps through a temporary file and a rename, so that a crash leaves the old file or the new one,
  /// never a part of one.
  Future<void> write(List<BridgeSwap> swaps) {
    final text = jsonEncode([for (final swap in swaps) swap.toJson()]);
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
}

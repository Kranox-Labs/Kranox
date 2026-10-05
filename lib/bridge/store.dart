import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// The swaps of the bridge in a file of the support folder, so that the app follows a swap again after a restart.
/// The file holds the id, the amounts, and the addresses of each swap, no key.
final class BridgeStore {
  const BridgeStore(this.path);

  final String path;

  Future<List<BridgeSwap>> read() async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final data = jsonDecode(await file.readAsString());
    if (data is! List<Object?>) throw FormatException('The bridge file holds no list.', path);
    return [
      for (final item in data)
        if (item is Map<String, Object?>)
          BridgeSwap.fromJson(item)
        else
          throw FormatException('The bridge file holds an entry that is no object.', path),
    ];
  }

  Future<void> write(List<BridgeSwap> swaps) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final swap in swaps) swap.toJson()]));
  }
}

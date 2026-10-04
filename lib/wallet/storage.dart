import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// The name of the Monero library inside the app, and the folder of the app bundle that holds it.
const String _moneroLibraryName = 'libmonero_wallet2_api_c.dylib';
const String _bundleLibraryFolder = 'Frameworks';

/// Gives the path of the Monero library that the Xcode build copies into the app.
String moneroLibraryPath() {
  final executable = File(Platform.resolvedExecutable);
  return '${executable.parent.parent.path}/$_bundleLibraryFolder/$_moneroLibraryName';
}

/// The files of the app in its support folder: the wallet of the network of this build, and the settings.
final class AppStorage {
  const AppStorage(this.root);

  final String root;

  static Future<AppStorage> locate() async => AppStorage((await getApplicationSupportDirectory()).path);

  String get walletFolder => '$root/${AppConfig.walletsFolderName}/${AppConfig.network.name}';
  String get walletPath => '$walletFolder/${AppConfig.walletFileName}';
  String get _settingsPath => '$root/${AppConfig.settingsFileName}';

  Future<bool> walletExists() => File('$walletPath.keys').exists();

  Future<void> prepareWalletFolder() => Directory(walletFolder).create(recursive: true);

  /// Reads the node that the user chose, or the default node of the network.
  Future<String> readNode() async {
    final file = File(_settingsPath);
    if (!await file.exists()) {
      return AppConfig.defaultNode;
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, Object?>) {
      throw FormatException('The settings file holds no object.', _settingsPath);
    }
    final node = data[_nodeKey];
    if (node is! String) {
      throw FormatException('The settings file holds no node.', _settingsPath);
    }
    return node;
  }

  Future<void> writeNode(String node) async {
    await Directory(root).create(recursive: true);
    await File(_settingsPath).writeAsString(jsonEncode({_nodeKey: node}));
  }

  static const String _nodeKey = 'node';
}

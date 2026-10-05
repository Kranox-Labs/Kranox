import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/network.dart';
import 'settings.dart';

/// The name of the Monero library inside the app, and the folder of the app bundle that holds it.
const String _moneroLibraryName = 'libmonero_wallet2_api_c.dylib';
const String _bundleLibraryFolder = 'Frameworks';

/// Gives the path of the Monero library that the Xcode build copies into the app.
String moneroLibraryPath() {
  final executable = File(Platform.resolvedExecutable);
  return '${executable.parent.parent.path}/$_bundleLibraryFolder/$_moneroLibraryName';
}

/// The files of the app in its support folder: one wallet for each network, and the settings.
final class AppStorage {
  const AppStorage(this.root);

  final String root;

  static Future<AppStorage> locate() async => AppStorage((await getApplicationSupportDirectory()).path);

  String walletFolder(MoneroNetwork network) => '$root/${AppConfig.walletsFolderName}/${network.name}';
  String walletPath(MoneroNetwork network) => '${walletFolder(network)}/${AppConfig.walletFileName}';
  String get _settingsPath => '$root/${AppConfig.settingsFileName}';

  Future<bool> walletExists(MoneroNetwork network) => File('${walletPath(network)}.keys').exists();

  Future<void> prepareWalletFolder(MoneroNetwork network) => Directory(walletFolder(network)).create(recursive: true);

  /// Reads the choices of the user, or the defaults when the user has made none.
  Future<AppSettings> readSettings() async {
    final file = File(_settingsPath);
    if (!await file.exists()) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException catch (error) {
      throw FormatException('${error.message} File: $_settingsPath', error.source);
    }
  }

  Future<void> writeSettings(AppSettings settings) async {
    await Directory(root).create(recursive: true);
    await File(_settingsPath).writeAsString(jsonEncode(settings.toJson()));
  }
}

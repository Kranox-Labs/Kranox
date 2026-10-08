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
  AppStorage(this.root);

  final String root;

  /// Where the last read moved a settings file that it could not read, or null.
  String? get settingsRecoveredFrom => _settingsRecoveredFrom;
  String? _settingsRecoveredFrom;

  static Future<AppStorage> locate() async => AppStorage((await getApplicationSupportDirectory()).path);

  String walletFolder(MoneroNetwork network) => '$root/${AppConfig.walletsFolderName}/${network.name}';
  String walletPath(MoneroNetwork network) => '${walletFolder(network)}/${AppConfig.walletFileName}';
  String get _settingsPath => '$root/${AppConfig.settingsFileName}';

  /// The swaps of the bridge, which works on mainnet only.
  String get bridgePath => '$root/${AppConfig.bridgeFileName}';

  Future<bool> walletExists(MoneroNetwork network) => File('${walletPath(network)}.keys').exists();

  Future<void> prepareWalletFolder(MoneroNetwork network) => Directory(walletFolder(network)).create(recursive: true);

  /// Reads the choices of the user, or the defaults when the user has made none. A file that the app cannot read,
  /// after a crash or from a newer release, moves aside with the time in its name, and the app starts with the
  /// defaults: the wallets stay, and the user chooses the network and the node again.
  Future<AppSettings> readSettings() async {
    final file = File(_settingsPath);
    if (!await file.exists()) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      final aside = '$_settingsPath.unreadable-${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await file.rename(aside);
      _settingsRecoveredFrom = aside;
      return const AppSettings();
    }
  }

  /// Writes the settings through a temporary file and a rename, so that a crash leaves the old file or the new one.
  Future<void> writeSettings(AppSettings settings) async {
    await Directory(root).create(recursive: true);
    final temporary = File('$_settingsPath.tmp');
    await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temporary.rename(_settingsPath);
  }
}

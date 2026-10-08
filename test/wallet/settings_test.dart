import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/wallet/settings.dart';
import 'package:kranox_wallet/wallet/storage.dart';

void main() {
  test('starts on the default network with the default node of each network', () {
    const settings = AppSettings();
    expect(settings.network, AppConfig.defaultNetwork);
    for (final network in MoneroNetwork.values) {
      expect(settings.nodeOf(network), AppConfig.defaultNode(network));
    }
  });

  test('keeps a node for one network only', () {
    final settings = const AppSettings().withNode(MoneroNetwork.stagenet, 'my.node:38081');
    expect(settings.nodeOf(MoneroNetwork.stagenet), 'my.node:38081');
    expect(settings.nodeOf(MoneroNetwork.mainnet), AppConfig.defaultNode(MoneroNetwork.mainnet));
    expect(settings.withNetwork(MoneroNetwork.testnet).nodeOf(MoneroNetwork.stagenet), 'my.node:38081');
  });

  test('reads back what it writes', () {
    final settings = const AppSettings()
        .withNetwork(MoneroNetwork.testnet)
        .withNode(MoneroNetwork.mainnet, 'my.node:18081')
        .withNode(MoneroNetwork.testnet, 'my.node:28081')
        .withProxy('127.0.0.1:9050');
    final read = AppSettings.fromJson(jsonDecode(jsonEncode(settings.toJson())));
    expect(read.network, MoneroNetwork.testnet);
    expect(read.nodes, settings.nodes);
    expect(read.proxy, '127.0.0.1:9050');
    expect(read.withNode(MoneroNetwork.mainnet, 'other.node:18081').proxy, '127.0.0.1:9050', reason: 'a node keeps it');
    expect(read.withProxy(null).proxy, isNull);
    expect(AppSettings.fromJson(const AppSettings().toJson()).proxy, isNull);
  });

  test('reads the node of a file from the time of stagenet only as the node of stagenet', () {
    final read = AppSettings.fromJson({'node': 'old.node:38089'});
    expect(read.network, AppConfig.defaultNetwork);
    expect(read.nodeOf(MoneroNetwork.stagenet), 'old.node:38089');
    expect(read.nodeOf(MoneroNetwork.mainnet), AppConfig.defaultNode(MoneroNetwork.mainnet));
  });

  test('rejects settings of the wrong form', () {
    for (final data in [
      'text',
      {'network': 'moonnet'},
      {'nodes': 'my.node:18081'},
      {
        'nodes': {'mainnet': 18081},
      },
      {'proxy': 9050},
    ]) {
      expect(() => AppSettings.fromJson(data), throwsFormatException, reason: '$data');
    }
  });

  test('keeps the wallet of each network in its own folder', () async {
    final root = Directory.systemTemp.createTempSync('kranox-settings');
    addTearDown(() => root.deleteSync(recursive: true));
    final storage = AppStorage(root.path);
    expect(
      await storage.readSettings(),
      isA<AppSettings>().having((s) => s.network, 'network', AppConfig.defaultNetwork),
    );
    final folders = {for (final network in MoneroNetwork.values) storage.walletFolder(network)};
    expect(folders, hasLength(MoneroNetwork.values.length));

    await storage.prepareWalletFolder(MoneroNetwork.stagenet);
    File('${storage.walletPath(MoneroNetwork.stagenet)}.keys').createSync();
    expect(await storage.walletExists(MoneroNetwork.stagenet), isTrue);
    expect(await storage.walletExists(MoneroNetwork.mainnet), isFalse);

    await storage.writeSettings(const AppSettings(network: MoneroNetwork.stagenet));
    expect((await storage.readSettings()).network, MoneroNetwork.stagenet);
  });
}

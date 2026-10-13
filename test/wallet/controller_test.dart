import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/core/amount.dart';
import 'package:kranox_wallet/core/connection_probe.dart';
import 'package:kranox_wallet/core/node_address.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/models.dart';
import 'package:kranox_wallet/wallet/settings.dart';
import 'package:kranox_wallet/wallet/failure.dart';
import 'package:kranox_wallet/wallet/requests.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

/// A wallet engine that opens every wallet and keeps the requests it gets, so that a test can check them. With
/// [refusesProxies], it refuses every proxy as wallet2 refuses one that it cannot read.
/// A probe of the test: it answers [trouble] for every look and records what it was asked.
final class _FakeProbe extends ConnectionProbe {
  _FakeProbe(this.trouble);

  ConnectionTrouble? trouble;
  final List<({String host, int port, String? proxy})> looks = [];

  /// A failure that every look throws, when a test wants one.
  Object? failure;

  @override
  Future<ConnectionTrouble?> run({required String host, required int port, required String? proxy}) async {
    looks.add((host: host, port: port, proxy: proxy));
    if (failure case final failure?) throw failure;
    return trouble;
  }
}

/// The state of a wallet whose node does not answer, as the engine reads it: not the "unknown" of no read.
const _silentNode = WalletStatus(
  balance: XmrAmount.zero,
  unlocked: XmrAmount.zero,
  walletHeight: 10,
  nodeHeight: 0,
  synchronized: false,
  connection: NodeConnection.disconnected,
);

final class _RecordingBackend implements WalletBackend {
  final List<WalletRequest> requests = [];
  bool refusesProxies = false;

  /// A failure that every connect throws, when a test wants one.
  WalletException? connectFailure;

  /// The state that the backend reports; the "unknown" of no read unless a test sets a node that stays silent.
  WalletStatus status = WalletStatus.unknown;

  @override
  Future<T> call<T>(WalletRequest request) async {
    requests.add(request);
    if (request is ConnectNode && request.proxy != null && refusesProxies) {
      throw const WalletException(WalletFailure.proxyRefused, 'Failed to parse proxy address');
    }
    if (request is ConnectNode) {
      if (connectFailure case final failure?) throw failure;
    }
    final Object? answer = switch (request) {
      ReadReceiveAddress() || ReadSubaddress() => const ReceiveAddress(address: 'sample', index: 1),
      ReadHistory() => const <WalletTransfer>[],
      ReadStatus() => status,
      _ => null,
    };
    return answer as T;
  }

  @override
  void stop() {}
}

void main() {
  group('the look for the node', lookTests);
  late Directory root;
  late AppStorage storage;
  late _RecordingBackend backend;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kranox-controller');
    storage = AppStorage(root.path);
    backend = _RecordingBackend();
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<WalletController> started() async {
    final controller = WalletController(worker: backend, storage: storage);
    await controller.start();
    addTearDown(controller.dispose);
    return controller;
  }

  void makeWallet(MoneroNetwork network) {
    Directory(storage.walletFolder(network)).createSync(recursive: true);
    File('${storage.walletPath(network)}.keys').createSync();
  }

  test('starts on mainnet and offers a new wallet there', () async {
    makeWallet(MoneroNetwork.stagenet);
    final controller = await started();
    expect(controller.network, MoneroNetwork.mainnet);
    expect(controller.phase, WalletPhase.noWallet);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.mainnet));
  });

  test('moves to the wallet of another network and remembers the network', () async {
    makeWallet(MoneroNetwork.stagenet);
    final controller = await started();
    await controller.switchNetwork(MoneroNetwork.stagenet);
    expect(controller.phase, WalletPhase.locked);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.stagenet));
    expect(controller.walletFolder, storage.walletFolder(MoneroNetwork.stagenet));

    final again = await started();
    expect(again.network, MoneroNetwork.stagenet);
    expect(again.phase, WalletPhase.locked);
  });

  test('closes the open wallet before it moves, and opens the wallet of the new network', () async {
    makeWallet(MoneroNetwork.mainnet);
    makeWallet(MoneroNetwork.testnet);
    final controller = await started();
    await controller.unlock('password');
    expect(controller.phase, WalletPhase.open);

    await controller.switchNetwork(MoneroNetwork.testnet);
    expect(controller.phase, WalletPhase.locked);
    expect(backend.requests.whereType<CloseWallet>(), hasLength(1));

    await controller.unlock('password');
    final opened = backend.requests.whereType<OpenWallet>().last;
    expect(opened.path, storage.walletPath(MoneroNetwork.testnet));
    expect(opened.networkType, MoneroNetwork.testnet.walletType);
    final connected = backend.requests.whereType<ConnectNode>().last;
    expect(connected.address, AppConfig.defaultNode(MoneroNetwork.testnet));
    await controller.lock();
  });

  test('keeps a chosen node with its network', () async {
    final controller = await started();
    await controller.changeNode('my.node:18081');
    expect(controller.node, 'my.node:18081');
    await controller.switchNetwork(MoneroNetwork.stagenet);
    expect(controller.node, AppConfig.defaultNode(MoneroNetwork.stagenet));
    await controller.switchNetwork(MoneroNetwork.mainnet);
    expect(controller.node, 'my.node:18081');
  });

  test('makes and restores no wallet under a password shorter than the rule, whatever the screen checked', () async {
    final controller = await started();
    final short = '🔐' * 6;
    expect(() => controller.create(short), throwsArgumentError);
    expect(
      () => controller.restore(seed: List.filled(25, 'abbey'), restoreHeight: 0, password: 'eleven-char'),
      throwsArgumentError,
    );
    expect(backend.requests.whereType<CreateWallet>(), isEmpty);
    expect(backend.requests.whereType<RestoreWallet>(), isEmpty);
    try {
      await controller.create('eleven-char');
    } on ArgumentError catch (error) {
      expect(error.toString(), isNot(contains('eleven-char')), reason: 'the error never holds the password');
    }
  });

  test('connects through a proxy such as Tor, and straight again without one (K-11)', () async {
    final controller = await started();
    await controller.unlock('password');
    await controller.changeProxy(' 127.0.0.1:9050 ');
    expect(controller.proxy, '127.0.0.1:9050');
    expect(backend.requests.whereType<ConnectNode>().last.proxy, '127.0.0.1:9050');
    await controller.changeNode('my.node:18081');
    expect(backend.requests.whereType<ConnectNode>().last.proxy, '127.0.0.1:9050', reason: 'a new node keeps it');
    expect(() => controller.changeProxy('tor'), throwsA(isA<NodeAddressException>()));
    await controller.changeProxy('');
    expect(controller.proxy, isNull);
    expect(backend.requests.whereType<ConnectNode>().last.proxy, isNull);
    expect(() => controller.changeProxy('localhost:9050'), throwsA(isA<NodeAddressException>()));
  });

  test('a proxy that wallet2 refuses leaves the wallet open and away from its node, and says so', () async {
    await storage.writeSettings(const AppSettings().withProxy('127.0.0.1:9050'));
    backend.refusesProxies = true;
    final controller = await started();
    await controller.unlock('password');
    expect(controller.phase, WalletPhase.open, reason: 'the user can still reach the settings');
    expect(controller.proxyRefused, isTrue);
    await expectLater(
      controller.changeProxy('127.0.0.1:9150'),
      throwsA(isA<WalletException>().having((error) => error.failure, 'failure', WalletFailure.proxyRefused)),
    );
    backend.refusesProxies = false;
    await controller.changeProxy('127.0.0.1:9150');
    expect(controller.proxyRefused, isFalse);
  });
}

/// The look for the trouble with the node, from 13 Oct 2026: the app says why its node does not answer.
void lookTests() {
  late Directory root;
  late AppStorage storage;
  late _RecordingBackend backend;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kranox-look');
    storage = AppStorage(root.path);
    backend = _RecordingBackend()..status = _silentNode;
    Directory(storage.walletFolder(MoneroNetwork.mainnet)).createSync(recursive: true);
    File('${storage.walletPath(MoneroNetwork.mainnet)}.keys').createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  // The clock of the look, which the tests move by hand.
  var elapsed = Duration.zero;

  Future<WalletController> opened(_FakeProbe probe) async {
    final controller = WalletController(worker: backend, storage: storage, probe: probe, elapsed: () => elapsed);
    await controller.start();
    await controller.unlock('password');
    addTearDown(controller.dispose);
    return controller;
  }

  test('reports no trouble before the node has been silent for a while', () async {
    final probe = _FakeProbe(ConnectionTrouble.proxyDown);
    final controller = await opened(probe);
    expect(controller.status.connection, NodeConnection.disconnected);
    expect(controller.nodeReport, isNull);
    expect(probe.looks, isEmpty, reason: 'the moment of a connection at the open raises no look');
  });

  test('looks at once on a reconnect, through the proxy of the settings, and reports what it found', () async {
    final probe = _FakeProbe(ConnectionTrouble.proxyDown);
    final controller = await opened(probe);
    await controller.changeProxy('127.0.0.1:9050');
    await controller.reconnect();
    final node = splitNodeAddress(controller.node);
    expect(probe.looks.single, (host: node.host, port: node.port, proxy: '127.0.0.1:9050'));
    expect(controller.nodeReport?.trouble, ConnectionTrouble.proxyDown);
    expect(controller.lookingForNode, isFalse);
  });

  test('drops the report once the node answers', () async {
    final probe = _FakeProbe(ConnectionTrouble.hostDown);
    final controller = await opened(probe);
    await controller.reconnect();
    expect(controller.nodeReport?.trouble, ConnectionTrouble.hostDown);
    backend.status = const WalletStatus(
      balance: XmrAmount.zero,
      unlocked: XmrAmount.zero,
      walletHeight: 10,
      nodeHeight: 20,
      synchronized: false,
      connection: NodeConnection.connected,
    );
    await controller.reconnect();
    expect(controller.nodeReport, isNull);
  });

  test('looks once the node has been silent for a while, and again at an interval', () async {
    final probe = _FakeProbe(ConnectionTrouble.hostDown);
    final controller = await opened(probe);
    // The reads of the poll come every two seconds; the clock of the look is the one of the test.
    elapsed = AppConfig.nodeLookDelay + const Duration(seconds: 1);
    await Future<void>.delayed(AppConfig.statusInterval + const Duration(milliseconds: 300));
    expect(probe.looks, hasLength(1), reason: 'the delay passed');
    expect(controller.nodeReport?.trouble, ConnectionTrouble.hostDown);
    elapsed += const Duration(seconds: 5);
    await Future<void>.delayed(AppConfig.statusInterval + const Duration(milliseconds: 300));
    expect(probe.looks, hasLength(1), reason: 'the interval has not passed');
    elapsed += AppConfig.lookInterval;
    await Future<void>.delayed(AppConfig.statusInterval + const Duration(milliseconds: 300));
    expect(probe.looks, hasLength(2), reason: 'the interval passed');
  });

  test('says that a look failed, instead of a report of no trouble', () async {
    final probe = _FakeProbe(null)..failure = ArgumentError('a name too long for the proxy');
    final controller = await opened(probe);
    await runZonedGuarded(() => controller.reconnect(), (error, stack) {});
    expect(controller.nodeReport?.trouble, ConnectionTrouble.lookFailed);
    expect(controller.lookingForNode, isFalse);
  });

  test('forgets the report when the node or the proxy changes, and names what the look tried', () async {
    final probe = _FakeProbe(ConnectionTrouble.proxyDown);
    final controller = await opened(probe);
    await controller.changeProxy('127.0.0.1:9050');
    await controller.reconnect();
    expect(controller.nodeReport?.proxy, '127.0.0.1:9050');
    expect(controller.nodeReport?.node, controller.node);
    await controller.changeProxy('127.0.0.1:9150');
    expect(controller.nodeReport, isNull, reason: 'a report of another proxy says nothing about this one');
    await controller.reconnect();
    expect(controller.nodeReport?.proxy, '127.0.0.1:9150');
    await controller.changeNode('other.node:18081');
    expect(controller.nodeReport, isNull, reason: 'a report of another node says nothing about this one');
  });

  test('runs one reconnect at a time, and keeps a refusal of wallet2 for the notice', () async {
    final probe = _FakeProbe(ConnectionTrouble.hostDown);
    final controller = await opened(probe);
    final connects = backend.requests.whereType<ConnectNode>().length;
    await Future.wait([controller.reconnect(), controller.reconnect()]);
    expect(backend.requests.whereType<ConnectNode>().length, connects + 1, reason: 'the second click joined');
    expect(controller.reconnecting, isFalse);
    expect(controller.reconnectFailure, isNull);
    backend.connectFailure = const WalletException(WalletFailure.native, 'wallet2 said no');
    await controller.reconnect();
    expect(controller.reconnectFailure?.failure, WalletFailure.native);
    backend.connectFailure = null;
    await controller.reconnect();
    expect(controller.reconnectFailure, isNull, reason: 'the next reconnect starts afresh');
  });

  test('drops the report when the wallet locks', () async {
    final probe = _FakeProbe(null);
    final controller = await opened(probe);
    await controller.reconnect();
    expect(controller.nodeReport, isNotNull, reason: 'a look that found no trouble still reports');
    expect(controller.nodeReport?.trouble, isNull);
    await controller.lock();
    expect(controller.nodeReport, isNull);
  });
}

// Runs the app on macOS with the real Monero library and a stagenet node, and drives its screens: it checks that the
// welcome card on mainnet offers no network, moves to stagenet, makes a wallet, opens it, checks the pages, shows the
// seed, locks the wallet, opens it again, moves to testnet in Settings, and goes back to mainnet from there. The wallet lives in a temporary
// folder, and the test writes a picture of each screen beside it. The test does not wait until the wallet has caught
// up with the node: wallet_engine_test.dart checks that without a window.
//
// The test runs in two places. In the app on macOS, it shows the real window; macOS draws no frames for a window that
// another window covers, so keep the window in view. On the host, it runs without a window, at the size of the window
// of the app. Run in apps/wallet:
//   fvm flutter test integration_test/wallet_screens_test.dart -d macos
//   fvm flutter test integration_test/wallet_screens_test.dart -d flutter-tester
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kranox_wallet/app.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/controller.dart';
import 'package:kranox_wallet/bridge/store.dart';
import 'package:kranox_wallet/config/network.dart';
import 'package:kranox_wallet/ui/copy.dart';
import 'package:kranox_wallet/ui/theme/typography.dart';
import 'package:kranox_wallet/ui/widgets/seed_grid.dart';
import 'package:kranox_wallet/ui/widgets/sidebar.dart';
import 'package:kranox_wallet/wallet/controller.dart';
import 'package:kranox_wallet/wallet/storage.dart';
import 'package:kranox_wallet/wallet/worker.dart';

const String _password = 'kranox-test-password';

/// The test waits this long at most for the wallet: to make it, to scan the chain, and to answer.
const Duration _patience = Duration(seconds: 90);

const Duration _frame = Duration(milliseconds: 100);

/// The size of the window of the app when it opens, as in macos/Runner/MainFlutterWindow.swift.
const Size _windowSize = Size(1200, 800);
const double _windowPixelRatio = 2;

/// Whether the test runs on the host, without the app around it.
bool get _onHost => Platform.resolvedExecutable.endsWith('flutter_tester');

/// On the host, the library lies where tool/fetch_monero_c.sh writes it, not in an app.
String get _libraryPath =>
    _onHost ? '${Directory.current.path}/macos/Libraries/libmonero_wallet2_api_c.dylib' : moneroLibraryPath();

/// The host draws text in a test font until the test loads the font of the app.
Future<void> _loadAppFont() async {
  final loader = FontLoader(KranoxType.family)..addFont(rootBundle.load('assets/fonts/archivo/Archivo-Variable.ttf'));
  await loader.load();
}

// A stagenet address and a mainnet address of throwaway wallets, as in test/core/address_test.dart.
const String _stagenetAddress =
    '54gC41sfYPoXMRg6ytR2hRTtwK2TES1cbZ1KPxxXKAv2drLzkQbakX4ifsEGq2SZo5WeXHRM7hLRA1YC3F6Eyu6aLwnPUng';
const String _mainnetAddress =
    '48PFnHrr8bVGx463yo8SMXGZUp7PyYPgwZJR4MnpgjKCDXpw3XvK6UTbarKkpwaPbPSYSdJ4rozjZjGxr2t3qVP4B4DzzVs';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('makes, opens, locks, and unlocks a stagenet wallet, and moves between networks', (tester) async {
    final root = Directory.systemTemp.createTempSync('kranox-flow');
    final shots = Directory('${root.path}/shots')..createSync();
    debugPrint('Pictures of the screens: ${shots.path}');
    if (_onHost) {
      tester.view.physicalSize = _windowSize * _windowPixelRatio;
      tester.view.devicePixelRatio = _windowPixelRatio;
      addTearDown(tester.view.reset);
      await _loadAppFont();
    }
    final worker = await WalletWorker.start(libraryPath: _libraryPath);
    final controller = WalletController(worker: worker, storage: AppStorage(root.path));
    await controller.start();
    final bridge = BridgeController(
      client: RelayBridgeClient(),
      store: BridgeStore(AppStorage(root.path).bridgePath),
      wallet: controller,
    );
    await bridge.start();
    final frame = GlobalKey();

    Future<void> shoot(String name) async {
      await tester.pump(_frame);
      final boundary = frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${shots.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<void> waitFor(Finder finder) async {
      final deadline = DateTime.now().add(_patience);
      while (finder.evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          await shoot('failure');
          fail('The screen did not show $finder.');
        }
        await tester.pump(_frame);
      }
    }

    Future<void> waitUntil(bool Function() condition, String what) async {
      final deadline = DateTime.now().add(_patience);
      var report = DateTime.now();
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) fail('The wallet did not reach: $what.');
        if (DateTime.now().difference(report) > const Duration(seconds: 5)) {
          report = DateTime.now();
          final status = controller.status;
          debugPrint(
            'Waiting for $what: wallet height ${status.walletHeight}, node height ${status.nodeHeight}, '
            'synchronized ${status.synchronized}, ${status.connection.name}',
          );
        }
        await tester.pump(_frame);
      }
    }

    // A long page scrolls, so each step first brings its target into view.
    Future<void> tapText(String text) async {
      final target = find.text(text).last;
      await tester.ensureVisible(target);
      await tester.pump(_frame);
      await tester.tap(target);
      await tester.pump(_frame);
    }

    Future<void> enter(int field, String text) async {
      final target = find.byType(TextField).at(field);
      await tester.ensureVisible(target);
      await tester.pump(_frame);
      await tester.enterText(target, text);
      await tester.pump(_frame);
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: KranoxApp(controller: controller, bridge: bridge),
      ),
    );
    // The app starts on mainnet, and its welcome card offers no network: the network changes in Settings only. The
    // test wallet belongs on stagenet, so the test moves there through the controller, as Settings would.
    await waitFor(find.text(Copy.createWallet));
    expect(controller.network, MoneroNetwork.mainnet);
    expect(find.text(MoneroNetwork.stagenet.label.toUpperCase()), findsNothing);
    expect(find.text(Copy.backToMainnet), findsNothing);
    await shoot('01-welcome');
    await controller.switchNetwork(MoneroNetwork.stagenet);
    await waitFor(find.text(Copy.backToMainnet));
    await shoot('01-welcome-stagenet');

    // Make the wallet: a password, then the seed.
    await tapText(Copy.createWallet);
    await enter(0, _password);
    await enter(1, _password);
    await shoot('02-create');
    await tapText(Copy.createAction);
    await waitFor(find.byType(SeedGrid));
    final createdSeed = tester.widget<SeedGrid>(find.byType(SeedGrid)).words;
    expect(createdSeed, hasLength(25));
    await shoot('03-seed');
    await tester.tap(find.byType(Checkbox));
    await tester.pump(_frame);
    await tapText(Copy.enterWallet);

    // The open wallet talks to its node and starts to scan the chain.
    await waitFor(find.text(Copy.balance.toUpperCase()));
    await waitUntil(() => controller.status.nodeHeight > 0, 'an answer of the node');
    expect(controller.receiveAddress?.address, startsWith('7'));
    await shoot('04-home');

    await tapText(Copy.navReceive);
    await waitFor(find.text(Copy.receiveTitle));
    await shoot('05-receive');
    final firstAddress = controller.receiveAddress!.address;
    await tapText(Copy.newAddress);
    await waitUntil(() => controller.receiveAddress!.address != firstAddress, 'a new subaddress');

    // The send form checks the address and the amount before it asks the wallet.
    await tapText(Copy.navSend);
    await waitFor(find.text(Copy.sendTitle));
    await enter(0, _mainnetAddress);
    await enter(1, '1.5');
    await tapText(Copy.review);
    await waitFor(find.text(Copy.addressOtherNetwork(MoneroNetwork.mainnet, MoneroNetwork.stagenet)));
    expect(find.text(Copy.amountAboveUnlocked), findsOneWidget);
    await shoot('06-send-checks');
    await enter(0, _stagenetAddress);
    await enter(1, '0.0000000000001');
    await tapText(Copy.review);
    await waitFor(find.text(Copy.amountTooManyDecimals));

    await tapText(Copy.navActivity);
    await waitFor(find.text(Copy.activityLead));
    await shoot('07-activity');

    // The exchanger works on mainnet only, so receive from Robinhood Chain on stagenet says so and offers no form.
    await tapText(Copy.navReceive);
    await tapText(Copy.receiveChainTab.toUpperCase());
    await waitFor(find.text(Copy.bridgeMainnetOnly));
    expect(find.text(Copy.bridgeFormTitle), findsNothing);
    await shoot('07-receive-chain-stagenet');

    // The seed shows behind the password, and it is the seed of the creation.
    await tapText(Copy.navSettings);
    await waitFor(find.text(Copy.settingsLead));
    await shoot('08-settings');
    await tester.ensureVisible(find.text(Copy.networkLead));
    await shoot('08-settings-network');
    await enter(1, 'wrong-password');
    await tapText(Copy.showSeed);
    await waitFor(find.text(Copy.wrongPassword));
    await enter(1, _password);
    await tapText(Copy.showSeed);
    await waitFor(find.byType(SeedGrid));
    expect(tester.widget<SeedGrid>(find.byType(SeedGrid)).words, createdSeed);
    await shoot('09-settings-seed');

    // Lock from the sidebar: the settings page has a card with the same title. Then a wrong password and the right one.
    final sidebarLock = find.descendant(of: find.byType(Sidebar), matching: find.text(Copy.navLock));
    await tester.tap(sidebarLock);
    await tester.pump(_frame);
    await waitFor(find.text(Copy.unlockTitle));
    await enter(0, 'wrong-password');
    await tapText(Copy.unlockAction);
    await waitFor(find.text(Copy.wrongPassword));
    await shoot('10-unlock-wrong');
    await enter(0, _password);
    await tapText(Copy.unlockAction);
    await waitFor(find.text(Copy.balance.toUpperCase()));
    expect(controller.phase, WalletPhase.open);

    // Testnet has no wallet yet, so the settings page leads to the welcome card, which offers the way back to mainnet.
    await tapText(Copy.navSettings);
    await waitFor(find.text(Copy.networkLead));
    await tapText(MoneroNetwork.testnet.label.toUpperCase());
    await waitFor(find.text(Copy.createWallet));
    expect(controller.network, MoneroNetwork.testnet);
    expect(controller.phase, WalletPhase.noWallet);
    await shoot('11-welcome-testnet');
    await tapText(Copy.backToMainnet);
    await waitFor(find.text(Copy.createWallet));
    expect(controller.network, MoneroNetwork.mainnet);
    expect(find.text(Copy.backToMainnet), findsNothing);
    // The stagenet wallet asks for its password again, with the way back to mainnet below.
    await controller.switchNetwork(MoneroNetwork.stagenet);
    await waitFor(find.text(Copy.unlockTitle));
    expect(find.text(Copy.backToMainnet), findsOneWidget);
    await shoot('12-unlock-stagenet');

    bridge.dispose();
    await controller.shutdown();
  });
}

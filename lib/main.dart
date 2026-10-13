import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bridge/client.dart';
import 'bridge/controller.dart';
import 'bridge/store.dart';
import 'core/tor_engine.dart';
import 'wallet/controller.dart';
import 'wallet/storage.dart';
import 'wallet/tor_service.dart';
import 'wallet/worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.locate();
  final worker = await WalletWorker.start(libraryPath: moneroLibraryPath());
  // Tor built into the app: the controller starts it when the settings say so, and the node and the relay wait for it.
  final tor = TorService(engine: ArtiTorEngine());
  final controller = WalletController(worker: worker, storage: storage, tor: tor);
  await controller.start();
  // One client of the relay serves the bridge and the scan of an address on Robinhood Chain, through Tor built into
  // the app, or the proxy of the node when the user sets one; no call goes out while the wallet waits for Tor.
  final relay = RelayBridgeClient(proxy: () => controller.proxy, blocked: () => controller.waitsForTor);
  final bridge = BridgeController(
    client: relay,
    store: BridgeStore(storage.bridgePath),
    wallet: controller,
    scanner: relay,
  );
  await bridge.start();
  runApp(KranoxApp(controller: controller, bridge: bridge));
}

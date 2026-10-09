import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bridge/client.dart';
import 'bridge/controller.dart';
import 'bridge/store.dart';
import 'wallet/controller.dart';
import 'wallet/storage.dart';
import 'wallet/worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.locate();
  final worker = await WalletWorker.start(libraryPath: moneroLibraryPath());
  final controller = WalletController(worker: worker, storage: storage);
  await controller.start();
  // One client of the relay serves the bridge and the scan of an address on Robinhood Chain, through the proxy of the
  // node when the user sets one.
  final relay = RelayBridgeClient(proxy: () => controller.proxy);
  final bridge = BridgeController(
    client: relay,
    store: BridgeStore(storage.bridgePath),
    wallet: controller,
    scanner: relay,
  );
  await bridge.start();
  runApp(KranoxApp(controller: controller, bridge: bridge));
}

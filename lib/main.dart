import 'package:flutter/widgets.dart';

import 'app.dart';
import 'wallet/controller.dart';
import 'wallet/storage.dart';
import 'wallet/worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.locate();
  final worker = await WalletWorker.start(libraryPath: moneroLibraryPath());
  final controller = WalletController(worker: worker, storage: storage);
  await controller.start();
  runApp(KranoxApp(controller: controller));
}

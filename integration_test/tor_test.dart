// Tor built into the app against the real Tor network: arti starts in the process of the test, builds its circuits,
// carries a call to the relay of Kranox through its SOCKS5 proxy, and stops. Run on this Mac with
//   fvm flutter test integration_test/tor_test.dart -d macos
// It needs the network; it makes no swap and touches no wallet.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/core/socks.dart';
import 'package:kranox_wallet/core/tor_engine.dart';
import 'package:kranox_wallet/wallet/tor_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A plain test, not one of widgets: the test pumps no widget, and the binding of the integration tests would
  // otherwise hold a handle of the semantics that the end of a widget test refuses.
  test('Tor built into the app starts, carries a call to the relay, and stops', () async {
    {
      final tor = TorService(engine: ArtiTorEngine());
      final watch = Stopwatch()..start();
      await tor.start().timeout(const Duration(minutes: 3));
      // ignore: avoid_print
      print('tor: ${tor.state.name} after ${watch.elapsed.inSeconds} s, failure: ${tor.failure}');
      expect(tor.state, TorState.on, reason: 'Tor did not start: ${tor.failure}');
      final address = tor.address;
      expect(address, isNotNull);
      expect(address, startsWith('127.0.0.1:'));
      // The proxy answers the greeting of the app, resolves a name with RESOLVE, the command of Tor (W-07), and
      // opens a connection to the relay, resolving its name itself.
      await probeSocks5(proxy: address!, timeout: const Duration(seconds: 10));
      final resolved = await resolveThroughSocks(
        proxy: address,
        host: 'relay.kranox.cash',
        timeout: const Duration(seconds: 60),
      );
      // ignore: avoid_print
      print('relay resolved through tor: ${resolved.type.name}');
      expect(resolved.type, isIn([InternetAddressType.IPv4, InternetAddressType.IPv6]));
      await checkThroughSocks(
        proxy: address,
        host: 'relay.kranox.cash',
        port: 443,
        timeout: const Duration(seconds: 60),
      );
      // A call of the relay through Tor, with its signature checked: the way the app reaches the relay.
      final relay = RelayBridgeClient(proxy: () => address);
      watch.reset();
      final online = await relay.isOnline();
      // ignore: avoid_print
      print('relay through tor: ${online ? "online" : "offline"} after ${watch.elapsedMilliseconds} ms');
      expect(online, isTrue);
      await tor.stop();
      expect(tor.state, TorState.off);
      expect(tor.address, isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

import 'package:tor/tor.dart' as arti;

/// Tor built into the app, from 13 Oct 2026: a client of the Tor network inside the process of the app, arti (the
/// Tor client in Rust of the Tor Project) through the plugin `tor` of Foundation Devices, which starts it and runs a
/// SOCKS5 proxy on 127.0.0.1 at a port of its choice. The wallet and the client of the relay then go through that
/// proxy as through any SOCKS proxy, so no Tor of the user is needed. A test gives another engine.
abstract interface class TorEngine {
  /// Starts Tor and waits until it has built its first circuits. The port of its SOCKS5 proxy on 127.0.0.1.
  Future<int> start();

  /// Stops the proxy and the client. A later [start] starts them again.
  Future<void> stop();
}

/// The engine of the plugin. CHECKED 13 Oct 2026, its sources at the commit the app pins: the proxy listens on
/// localhost alone (`Listen::new_localhost`), the state and the cache of arti live under the application support
/// folder of the app, `start` returns once arti has bootstrapped (`create_bootstrapped`), and addresses of onion
/// services are allowed, for a relay at one later.
final class ArtiTorEngine implements TorEngine {
  @override
  Future<int> start() async {
    await arti.Tor.init();
    final tor = arti.Tor.instance;
    if (tor.started) {
      await tor.enable();
    } else {
      await tor.start();
    }
    final port = tor.port;
    if (port < 1 || port > 65535) throw StateError('Tor started without a port of its proxy.');
    return port;
  }

  @override
  Future<void> stop() => arti.Tor.instance.stop();
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/models.dart';

void main() {
  test('makes no call to the relay while the wallet waits for Tor built into the app', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response
        ..statusCode = 200
        ..write('{"ok":true}');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    var blocked = true;
    final client = RelayBridgeClient(
      proxy: () => null,
      blocked: () => blocked,
      baseUrl: 'http://127.0.0.1:${server.port}',
      signingKeys: const [],
    );
    expect(await client.isOnline(), isFalse);
    await expectLater(
      client.payRange(BridgeAsset.usdg, PayRate.floating),
      throwsA(isA<BridgeException>().having((error) => error.failure, 'failure', BridgeFailure.relayDown)),
    );
    expect(requests, 0, reason: 'nothing reaches the relay while the wallet waits for Tor');
    // Once Tor is on, the calls go out (and fail here on the signature, which is no concern of this test).
    blocked = false;
    await client.isOnline();
    expect(requests, 1);
  });
}

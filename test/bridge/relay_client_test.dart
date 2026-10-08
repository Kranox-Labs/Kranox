import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/models.dart';

/// A local server in place of the relay that keeps the headers of each request and answers a new payment and a state.
void main() {
  late HttpServer server;
  final heard = <String, HttpHeaders>{};

  setUp(() async {
    heard.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      heard['${request.method} ${request.uri.path}'] = request.headers;
      await utf8.decoder.bind(request).join();
      final body = request.method == 'POST'
          ? {
              'id': 'pay1',
              'asset': 'usdg',
              'amount': 80,
              'xmrAmount': 0.16,
              'depositAddress': 'deposit',
              'payoutAddress': '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
              'readToken': 'token-of-pay1',
            }
          : {'status': 'waiting'};
      request.response
        ..statusCode = request.method == 'POST' ? 201 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('sends the key of a creation and the token of a read in the headers that the relay reads', () async {
    final client = RelayBridgeClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final created = await client.createPay(
      asset: BridgeAsset.usdg,
      rate: PayRate.floating,
      xmrAmount: '0.16',
      address: '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      refundAddress: 'subaddress',
      rateId: null,
      creationKey: 'c0ffee00c0ffee00c0ffee00c0ffee00',
    );
    expect(created.readToken, 'token-of-pay1');
    expect(heard['POST /v1/pay/swaps']!.value('idempotency-key'), 'c0ffee00c0ffee00c0ffee00c0ffee00');

    await client.readSwap('pay1', token: created.readToken);
    expect(heard['GET /v1/swaps/pay1']!.value('kranox-swap-token'), 'token-of-pay1');
    await client.readSwap('pay0');
    expect(heard['GET /v1/swaps/pay0']!.value('kranox-swap-token'), isNull, reason: 'a swap of an older release');
  });
}

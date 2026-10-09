import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/bridge/client.dart';
import 'package:kranox_wallet/bridge/models.dart';
import 'package:kranox_wallet/bridge/relay_signature.dart';
import 'package:kranox_wallet/config/app_config.dart';
import 'package:pointycastle/export.dart';

/// A key of P-256 for the relay of the test, which signs as the relay does: SHA-256 over the nonce, a line break, and
/// the body, as 64 bytes of r and s in base64.
final class _TestKey {
  _TestKey() {
    final random = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList([for (var i = 0; i < 32; i++) Random.secure().nextInt(256)])));
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(ECCurve_secp256r1()), random));
    final pair = generator.generateKeyPair();
    _private = pair.privateKey;
    publicBase64 = base64Encode(pair.publicKey.Q!.getEncoded(false));
    _random = random;
  }

  late final ECPrivateKey _private;
  late final String publicBase64;
  late final SecureRandom _random;

  String sign(String nonce, String body) {
    final signer = ECDSASigner(SHA256Digest())
      ..init(true, ParametersWithRandom(PrivateKeyParameter<ECPrivateKey>(_private), _random));
    final signature = signer.generateSignature(Uint8List.fromList(utf8.encode('$nonce\n$body'))) as ECSignature;
    Uint8List bytes(BigInt value) =>
        Uint8List.fromList([for (var i = 31; i >= 0; i--) ((value >> (8 * i)) & BigInt.from(0xff)).toInt()]);
    return base64Encode([...bytes(signature.r), ...bytes(signature.s)]);
  }
}

/// A local server in place of the relay that keeps the headers of each request and answers a new payment and a state,
/// signed by [_TestKey] unless the test asks otherwise.
void main() {
  late HttpServer server;
  final key = _TestKey();
  final heard = <String, HttpHeaders>{};
  String Function(String nonce, String body) signer = key.sign;

  setUp(() async {
    heard.clear();
    signer = key.sign;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      heard['${request.method} ${request.uri.path}'] = request.headers;
      await utf8.decoder.bind(request).join();
      final body = jsonEncode(
        request.method == 'POST'
            ? {
                'id': 'pay1',
                'asset': 'usdg',
                'amount': 80,
                'xmrAmount': 0.16,
                'depositAddress': 'deposit',
                'payoutAddress': '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
                'readToken': 'token-of-pay1',
              }
            : {'status': 'waiting'},
      );
      request.response
        ..statusCode = request.method == 'POST' ? 201 : 200
        ..headers.contentType = ContentType.json
        ..headers.set('kranox-signature', signer(request.headers.value('kranox-nonce') ?? '', body))
        ..write(body);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  RelayBridgeClient client() =>
      RelayBridgeClient(proxy: () => null, baseUrl: 'http://127.0.0.1:${server.port}', signingKeys: [key.publicBase64]);

  test('sends the key of a creation and the token of a read in the headers that the relay reads', () async {
    final created = await client().createPay(
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

    await client().readSwap('pay1', token: created.readToken);
    expect(heard['GET /v1/swaps/pay1']!.value('kranox-swap-token'), 'token-of-pay1');
    await client().readSwap('pay0');
    expect(heard['GET /v1/swaps/pay0']!.value('kranox-swap-token'), isNull, reason: 'a swap of an older release');
  });

  test('trusts no answer without the signature of the relay over its request (K-10)', () async {
    Future<void> refused(String reason) => expectLater(
      client().readSwap('pay1'),
      throwsA(isA<BridgeException>().having((error) => error.detail, 'detail', contains('without a valid signature'))),
      reason: reason,
    );
    expect((await client().readSwap('pay1')).stage, SwapStage.waiting);
    expect(heard['GET /v1/swaps/pay1']!.value('kranox-nonce'), matches(RegExp(r'^[0-9a-f]{32}$')));

    signer = (nonce, body) => '';
    await refused('no signature');
    signer = (nonce, body) => key.sign('0123456789abcdef0123456789abcdef', body);
    await refused('an old answer for another request');
    signer = (nonce, body) => key.sign(nonce, '$body ');
    await refused('a signature of another body');
    signer = (nonce, body) => _TestKey().sign(nonce, body);
    await refused('a key that the app does not hold');
  });

  group('through a SOCKS proxy such as Tor (O-001 of the second review)', () {
    late _SocksProxy proxy;
    late ServerSocket straight;
    var straightCalls = 0;

    setUp(() async {
      proxy = await _SocksProxy.start();
      straightCalls = 0;
      // The relay at a straight address, which counts every connection that reaches it without the proxy.
      straight = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      straight.listen((socket) {
        straightCalls++;
        socket.destroy();
      });
    });

    tearDown(() async {
      await proxy.close();
      await straight.close();
    });

    Matcher relayDown(String detail) => throwsA(
      isA<BridgeException>()
          .having((error) => error.failure, 'failure', BridgeFailure.relayDown)
          .having((error) => error.detail, 'detail', contains(detail)),
    );

    test('hands the name of the relay to the proxy, which resolves it', () async {
      final client = RelayBridgeClient(
        proxy: () => proxy.address,
        baseUrl: 'https://relay.kranox.invalid',
        signingKeys: [key.publicBase64],
      );
      // The proxy of the test lets the connection through to nothing, so TLS fails after the proxy has seen it.
      await expectLater(client.readSwap('pay1'), throwsA(isA<BridgeException>()));
      expect(proxy.greetings, [
        [5, 1, 0],
      ], reason: 'SOCKS5 with one method: no user name');
      expect(proxy.targets, ['relay.kranox.invalid:443'], reason: 'a name that only the proxy could resolve');
    });

    test('fails a call that the proxy refuses or cannot carry, and never calls the relay straight', () async {
      final relay = 'https://127.0.0.1:${straight.port}';
      RelayBridgeClient through(String address) =>
          RelayBridgeClient(proxy: () => address, baseUrl: relay, signingKeys: [key.publicBase64]);

      proxy.reply = 5;
      await expectLater(through(proxy.address).readSwap('pay1'), relayDown('SOCKS5 reply 5'));
      expect(proxy.targets, ['127.0.0.1:${straight.port}']);
      proxy.method = 0xff;
      await expectLater(through(proxy.address).readSwap('pay1'), relayDown('without a user name'));

      final down = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final downAddress = '127.0.0.1:${down.port}';
      await down.close();
      await expectLater(through(downAddress).readSwap('pay1'), throwsA(isA<BridgeException>()));
      expect(await through(downAddress).isOnline(), isFalse);
      expect(straightCalls, 0);
    });

    test('takes a new proxy at once, without the open connections of the straight way', () async {
      String? current;
      final client = RelayBridgeClient(
        proxy: () => current,
        baseUrl: 'http://127.0.0.1:${server.port}',
        signingKeys: [key.publicBase64],
      );
      expect((await client.readSwap('pay1')).stage, SwapStage.waiting);
      heard.clear();

      current = proxy.address;
      await expectLater(client.readSwap('pay1'), relayDown('HTTPS only'));
      expect(heard, isEmpty, reason: 'the kept connection to the relay carries no call after the proxy is set');

      current = null;
      expect((await client.readSwap('pay1')).stage, SwapStage.waiting);
    });
  });

  test('holds a key of the relay that lies on P-256', () {
    expect(AppConfig.relaySigningKeys, isNotEmpty);
    expect(() => RelaySignature(AppConfig.relaySigningKeys), returnsNormally);
  });

  test('takes only an uncompressed point of P-256 as a key of the relay', () {
    expect(() => RelaySignature([base64Encode(List.filled(65, 4))]), throwsArgumentError);
    expect(() => RelaySignature([base64Encode(List.filled(33, 2))]), throwsArgumentError);
    expect(RelaySignature([key.publicBase64]).verifies(nonce: 'n', body: 'b', signature: null), isFalse);
  });
}

/// A SOCKS5 proxy for the tests. It keeps the greeting and the target of each connection, answers [reply] to the
/// command CONNECT, and then closes, so that a call through it fails after the proxy has seen where it goes.
final class _SocksProxy {
  _SocksProxy._(this._server) {
    _server.listen(_serve);
  }

  static Future<_SocksProxy> start() async => _SocksProxy._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  final ServerSocket _server;
  final List<List<int>> greetings = [];
  final List<String> targets = [];

  /// The method that the proxy picks: 0 for no user name, 0xff for none of the methods that the app offers.
  int method = 0;

  /// The reply to the command CONNECT: 0 lets it through, any other code refuses it.
  int reply = 0;

  String get address => '127.0.0.1:${_server.port}';

  Future<void> close() => _server.close();

  void _serve(Socket socket) {
    final bytes = <int>[];
    var stage = 0;
    socket.listen((data) {
      bytes.addAll(data);
      if (stage == 0 && bytes.length >= 3) {
        greetings.add(bytes.sublist(0, 3));
        bytes.removeRange(0, 3);
        stage = 1;
        socket.add([5, method]);
        if (method != 0) socket.close();
      } else if (stage == 1) {
        final target = _target(bytes);
        if (target == null) return;
        targets.add(target);
        stage = 2;
        socket
          ..add([5, reply, 0, 1, 0, 0, 0, 0, 0, 0])
          ..close();
      }
    }, onError: (Object _) => socket.destroy());
  }

  /// The host and the port of a whole command CONNECT, or null while a part of it is still on the way.
  static String? _target(List<int> bytes) {
    if (bytes.length < 5) return null;
    final type = bytes[3];
    final length = switch (type) {
      1 => 4,
      4 => 16,
      3 => 1 + bytes[4],
      _ => throw StateError('An address of the type $type.'),
    };
    if (bytes.length < 4 + length + 2) return null;
    final address = bytes.sublist(4, 4 + length);
    final port = bytes[4 + length] << 8 | bytes[5 + length];
    final host = type == 3
        ? ascii.decode(address.sublist(1))
        : InternetAddress.fromRawAddress(Uint8List.fromList(address)).address;
    return '$host:$port';
  }
}

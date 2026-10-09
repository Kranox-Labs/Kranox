import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'chain_scan.dart';
import 'models.dart';
import 'relay_signature.dart';
import 'socks.dart';

/// The ways in which a call of the bridge can fail. The screens show a sentence for each one.
enum BridgeFailure {
  /// The relay of Kranox does not answer.
  relayDown,

  /// The relay or the exchanger refused the request, such as an amount below the minimum. The detail says why.
  refused,

  /// The exchanger failed or answered in a form that the app does not read.
  failed,

  /// The fixed rate of a payment ran out before the payment left, so the user reviews the payment again.
  rateExpired,
}

final class BridgeException implements Exception {
  const BridgeException(this.failure, this.detail);

  final BridgeFailure failure;
  final String detail;

  @override
  String toString() => 'BridgeException(${failure.name}): $detail';
}

/// What the app needs from the bridge. The app talks to the relay of Kranox, which holds the API key of the exchanger;
/// a test answers with samples.
abstract interface class BridgeClient {
  Future<BridgeQuote> quote(BridgeAsset asset, String amount);

  /// Asks the exchanger for a swap of [amount] of [asset] into XMR for [address]. The answer carries the deposit
  /// address on Robinhood Chain. A second call with the same [creationKey] and the same request gets the swap of the
  /// first, so that a try after a lost answer makes no second swap.
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
    required String creationKey,
  });

  /// Asks the exchanger for the range of the XMR of one payment into [asset] at [rate].
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate);

  /// Asks the exchanger how much of [asset] on Robinhood Chain a payment of [xmrAmount] buys at [rate].
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount);

  /// Asks the exchanger for a payment of [xmrAmount] into [asset] for [address] on Robinhood Chain at [rate], with a
  /// refund of the XMR to [refundAddress] of this wallet. A fixed rate holds the rate of [rateId]; a floating rate
  /// takes none. The answer carries the Monero address of the deposit and the amount that the recipient gets. The
  /// [creationKey] works as for a swap.
  Future<CreatedPay> createPay({
    required BridgeAsset asset,
    required PayRate rate,
    required String xmrAmount,
    required String address,
    required String refundAddress,
    required String? rateId,
    required String creationKey,
  });

  /// Reads the state of the swap [id], with the [token] that the relay gave at its creation. A swap of a release
  /// before 0.3.1 has no token.
  Future<SwapState> readSwap(String id, {String? token});

  /// Whether the relay answers. A relay that does not answer gives false, not an error.
  Future<bool> isOnline();
}

/// The answer of the relay to a new swap.
final class CreatedSwap {
  const CreatedSwap({
    required this.id,
    required this.amount,
    required this.estimatedXmr,
    required this.depositAddress,
    required this.payoutAddress,
    this.readToken,
  });

  final String id;
  final double amount;
  final double? estimatedXmr;
  final String depositAddress;
  final String payoutAddress;

  /// The token that reads the state of the swap at the relay; null from a relay before 8 Oct 2026.
  final String? readToken;

  factory CreatedSwap.fromJson(Map<String, Object?> data) {
    final id = data['id'];
    final amount = data['amount'];
    final estimate = data['estimatedXmr'];
    final deposit = data['depositAddress'];
    final payout = data['payoutAddress'];
    if (id is! String ||
        id.isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        (estimate != null && (estimate is! num || !estimate.isFinite)) ||
        deposit is! String ||
        deposit.isEmpty ||
        payout is! String ||
        payout.isEmpty) {
      throw const FormatException('The relay answered a new swap without its id, amount, or addresses.');
    }
    return CreatedSwap(
      id: id,
      amount: amount.toDouble(),
      estimatedXmr: estimate is num ? estimate.toDouble() : null,
      depositAddress: deposit,
      payoutAddress: payout,
      readToken: _readToken(data),
    );
  }
}

/// The answer of the relay to a new payment.
final class CreatedPay {
  const CreatedPay({
    required this.id,
    required this.amount,
    required this.xmrAmount,
    required this.depositAddress,
    required this.payoutAddress,
    this.readToken,
  });

  final String id;

  /// The amount that the recipient gets.
  final double amount;

  /// The XMR of the deposit.
  final double xmrAmount;
  final String depositAddress;
  final String payoutAddress;

  /// The token that reads the state of the payment at the relay; null from a relay before 8 Oct 2026.
  final String? readToken;

  factory CreatedPay.fromJson(Map<String, Object?> data) {
    final id = data['id'];
    final amount = data['amount'];
    final xmr = data['xmrAmount'];
    final deposit = data['depositAddress'];
    final payout = data['payoutAddress'];
    if (id is! String ||
        id.isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        xmr is! num ||
        !xmr.isFinite ||
        deposit is! String ||
        deposit.isEmpty ||
        payout is! String ||
        payout.isEmpty) {
      throw const FormatException('The relay answered a new payment without its id, amounts, or addresses.');
    }
    return CreatedPay(
      id: id,
      amount: amount.toDouble(),
      xmrAmount: xmr.toDouble(),
      depositAddress: deposit,
      payoutAddress: payout,
      readToken: _readToken(data),
    );
  }
}

/// The read token of a new swap or payment: text when the relay gives one, null from an older relay.
String? _readToken(Map<String, Object?> data) => switch (data['readToken']) {
  null => null,
  final String token when token.isNotEmpty => token,
  _ => throw const FormatException('The relay answered a read token that is no text.'),
};

/// The headers of the key of a creation, of the read token of a swap, of the nonce of a request, and of the signature
/// of an answer, as the relay reads and writes them.
const String _creationKeyHeader = 'Idempotency-Key';
const String _swapTokenHeader = 'Kranox-Swap-Token';
const String _nonceHeader = 'Kranox-Nonce';
const String _signatureHeader = 'Kranox-Signature';

/// The bridge through the relay of Kranox, over HTTP, and the scan of an address on Robinhood Chain through it.
final class RelayBridgeClient implements BridgeClient, ChainScanClient {
  /// A release talks to its relay over HTTPS only, and trusts an answer only with a signature under [signingKeys].
  /// Each call goes through the SOCKS proxy that `proxy` gives at that moment, such as Tor, or straight without one.
  RelayBridgeClient({
    required this._proxy,
    String baseUrl = AppConfig.bridgeRelay,
    List<String> signingKeys = AppConfig.relaySigningKeys,
  }) : _base = Uri.parse(baseUrl),
       _signature = RelaySignature(signingKeys) {
    if (kReleaseMode && _base.scheme != 'https') {
      throw StateError('A release of the app talks to its relay over HTTPS only, not at $baseUrl.');
    }
  }

  final String? Function() _proxy;
  final Uri _base;
  final RelaySignature _signature;
  final Random _random = Random.secure();
  HttpClient? _http;
  String? _httpProxy;

  @override
  Future<BridgeQuote> quote(BridgeAsset asset, String amount) async =>
      BridgeQuote.fromJson(await _call('GET', '/v1/receive/quote', query: {'asset': asset.code, 'amount': amount}));

  @override
  Future<CreatedSwap> createSwap({
    required BridgeAsset asset,
    required String amount,
    required String address,
    String? refundAddress,
    required String creationKey,
  }) async => CreatedSwap.fromJson(
    await _call(
      'POST',
      '/v1/receive/swaps',
      body: {'asset': asset.code, 'amount': amount, 'address': address, 'refundAddress': ?refundAddress},
      headers: {_creationKeyHeader: creationKey},
    ),
  );

  @override
  Future<PayRange> payRange(BridgeAsset asset, PayRate rate) async =>
      PayRange.fromJson(await _call('GET', '/v1/pay/range', query: {'asset': asset.code, 'rate': rate.name}));

  @override
  Future<PayQuote> payQuote(BridgeAsset asset, PayRate rate, String xmrAmount) async => PayQuote.fromJson(
    await _call('GET', '/v1/pay/quote', query: {'asset': asset.code, 'rate': rate.name, 'xmrAmount': xmrAmount}),
  );

  @override
  Future<CreatedPay> createPay({
    required BridgeAsset asset,
    required PayRate rate,
    required String xmrAmount,
    required String address,
    required String refundAddress,
    required String? rateId,
    required String creationKey,
  }) async => CreatedPay.fromJson(
    await _call(
      'POST',
      '/v1/pay/swaps',
      body: {
        'asset': asset.code,
        'rate': rate.name,
        'xmrAmount': xmrAmount,
        'address': address,
        'refundAddress': refundAddress,
        'rateId': ?rateId,
      },
      headers: {_creationKeyHeader: creationKey},
    ),
  );

  @override
  Future<SwapState> readSwap(String id, {String? token}) async => SwapState.fromJson(
    await _call('GET', '/v1/swaps/${Uri.encodeComponent(id)}', headers: {_swapTokenHeader: ?token}),
  );

  @override
  Future<ChainScan> scanAddress(String address) async =>
      ChainScan.fromJson(await _call('GET', '/v1/scan/robinhood', query: {'address': address}));

  @override
  Future<bool> isOnline() async {
    try {
      return (await _call('GET', '/health'))['ok'] == true;
    } on BridgeException {
      return false;
    }
  }

  /// The HTTP client of [proxy]. Another proxy closes the client of the old one, so that no open connection of the old
  /// way carries a later call (O-001 of the second security review).
  HttpClient _httpFor(String? proxy) {
    if (_http case final http? when proxy == _httpProxy) return http;
    _http?.close();
    _httpProxy = proxy;
    final http = HttpClient()..connectionTimeout = AppConfig.bridgeRequestTimeout;
    if (proxy != null) {
      // Every connection opens through the SOCKS proxy, so no HTTP proxy of the environment comes between.
      http
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = (uri, _, _) => _throughProxy(proxy, uri);
    }
    return _http = http;
  }

  /// A connection to the relay through [proxy]. The proxy carries HTTPS only, and a proxy that fails fails the call:
  /// the app never falls back to a straight connection.
  static Future<ConnectionTask<Socket>> _throughProxy(String proxy, Uri uri) async {
    if (!uri.isScheme('https')) {
      throw StateError('The proxy carries the relay over HTTPS only, not at $uri.');
    }
    return connectTlsThroughSocks(proxy: proxy, host: uri.host, port: uri.port);
  }

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async {
    // The relay may sit under a path of its address, so the path of the call follows it.
    final basePath = _base.path.endsWith('/') ? _base.path.substring(0, _base.path.length - 1) : _base.path;
    final uri = _base.replace(path: '$basePath$path', queryParameters: query);
    final nonce = [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
    final HttpClientResponse response;
    final String text;
    try {
      final request = await _httpFor(_proxy()).openUrl(method, uri).timeout(AppConfig.bridgeRequestTimeout);
      request.headers.set(_nonceHeader, nonce);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      response = await request.close().timeout(AppConfig.bridgeRequestTimeout);
      text = await response.transform(utf8.decoder).join().timeout(AppConfig.bridgeRequestTimeout);
    } on SocketException catch (error) {
      throw BridgeException(BridgeFailure.relayDown, error.message);
    } on SocksException catch (error) {
      throw BridgeException(BridgeFailure.relayDown, error.message);
    } on Object catch (error) {
      throw BridgeException(BridgeFailure.relayDown, '$error');
    }
    // An answer counts only with the signature of the relay over this request and its body, an error too.
    if (!_signature.verifies(nonce: nonce, body: text, signature: response.headers.value(_signatureHeader))) {
      throw BridgeException(
        BridgeFailure.failed,
        'The relay answered ${response.statusCode} without a valid signature.',
      );
    }
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw BridgeException(BridgeFailure.failed, 'The relay answered ${response.statusCode} without JSON.');
    }
    if (data is! Map<String, Object?>) {
      throw const BridgeException(BridgeFailure.failed, 'The relay answered without an object.');
    }
    if (response.statusCode >= 400) {
      final message = data['error'];
      final detail = message is String ? message : 'HTTP ${response.statusCode}';
      final refused = response.statusCode == HttpStatus.badRequest || response.statusCode == 422;
      throw BridgeException(refused ? BridgeFailure.refused : BridgeFailure.failed, detail);
    }
    return data;
  }
}

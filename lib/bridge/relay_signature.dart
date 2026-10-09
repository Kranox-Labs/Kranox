import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show PublicKeyParameter;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/ecc/ecc_fp.dart' as fp;
import 'package:pointycastle/signers/ecdsa_signer.dart';

/// What a signature of the relay binds: the request with its nonce, and the answer.
final class SignedAnswer {
  const SignedAnswer({
    required this.nonce,
    required this.method,
    required this.target,
    required this.requestBody,
    required this.status,
    required this.body,
  });

  final String nonce;
  final String method;

  /// The path of the request with its query, as the app sent it.
  final String target;

  /// The bytes of the body of the request; none for a request without a body.
  final List<int> requestBody;
  final int status;
  final String body;

  /// The text that the signature covers: one field on each line, with the SHA-256 of the body of the request in hex,
  /// and the body of the answer last. Its first line holds a slash, which no nonce holds, so the text of the older
  /// signature over the nonce and the body never reads as this one.
  String get message => [
    _answerV2,
    nonce,
    method,
    target,
    _hex(SHA256Digest().process(Uint8List.fromList(requestBody))),
    '$status',
    body,
  ].join('\n');

  static String _hex(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

  static const String _answerV2 = 'kranox/answer/2';
}

/// The check of the signature that the relay puts on each answer (K-10 of the security review of 0.2.0): ECDSA on
/// P-256 with SHA-256 over the [SignedAnswer.message], as 64 bytes of r and s in base64. The app holds the public keys
/// of the relay, so an interception of the connection, such as a company proxy with its own certificate, cannot answer
/// for the relay, and a signed answer answers only the request that the app sent: its nonce, its method, its path with
/// the query, its body, and the status (wallet O-003 of the second security review).
final class RelaySignature {
  /// Takes each public key as the uncompressed point of P-256 in base64, 65 bytes that start with 4.
  RelaySignature(List<String> keys) : _keys = [for (final key in keys) _publicKey(key)];

  final List<ECPublicKey> _keys;

  static ECPublicKey _publicKey(String base64Point) {
    final curve = ECCurve_secp256r1();
    final bytes = base64Decode(base64Point);
    final point = bytes.length == _pointLength && bytes.first == _uncompressed ? curve.curve.decodePoint(bytes) : null;
    // pointycastle reads any two numbers as a point, so the key must also lie on the curve: y² = x³ + ax + b.
    if (point == null || !_onCurve(point, curve.curve as fp.ECCurve)) {
      throw ArgumentError.value(base64Point, 'key', 'is no uncompressed point of P-256');
    }
    return ECPublicKey(point, curve);
  }

  static bool _onCurve(ECPoint point, fp.ECCurve curve) {
    final q = curve.q!;
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final a = curve.a!.toBigInteger()!;
    final b = curve.b!.toBigInteger()!;
    return (y * y - (x * x * x + a * x + b)) % q == BigInt.zero;
  }

  /// Whether [signature] signs [answer] under one of the keys of the relay.
  bool verifies(SignedAnswer answer, String? signature) {
    if (signature == null) return false;
    final Uint8List bytes;
    try {
      bytes = base64Decode(signature);
    } on FormatException {
      return false;
    }
    if (bytes.length != _signatureLength) return false;
    final half = _signatureLength ~/ 2;
    final parts = ECSignature(_number(bytes.sublist(0, half)), _number(bytes.sublist(half)));
    final message = Uint8List.fromList(utf8.encode(answer.message));
    for (final key in _keys) {
      final verifier = ECDSASigner(SHA256Digest())..init(false, PublicKeyParameter<ECPublicKey>(key));
      if (verifier.verifySignature(message, parts)) return true;
    }
    return false;
  }

  static BigInt _number(List<int> bytes) => bytes.fold(BigInt.zero, (value, byte) => (value << 8) | BigInt.from(byte));

  static const int _pointLength = 65;
  static const int _uncompressed = 4;
  static const int _signatureLength = 64;
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

/// The encryption of a file of the app (wallet O-007 of the second security review): AES-256 in GCM under a key of
/// 32 bytes, with a new random nonce for each write, so that only the key reads the file and any change to it shows.
/// The [purpose] goes in as associated data, so that a file of one purpose never opens as one of another. A sealed
/// file is a JSON object with its version, its nonce, and its data in base64.
final class FileCipher {
  FileCipher(Uint8List key, {required String purpose})
    : _key = Uint8List.fromList(key),
      _purpose = Uint8List.fromList(utf8.encode(purpose)) {
    if (key.length != keyLength) {
      throw ArgumentError.value(key.length, 'key', 'must be $keyLength bytes');
    }
  }

  final Uint8List _key;
  final Uint8List _purpose;
  final Random _random = Random.secure();

  /// The length of a key in bytes: AES-256.
  static const int keyLength = 32;

  /// Whether [data], the decoded JSON of a file, is a sealed file, and not the plain file of an earlier release.
  static bool isSealed(Object? data) => data is Map<String, Object?> && data[_versionField] == _version;

  /// [text] as the JSON of a sealed file.
  String seal(String text) {
    final nonce = Uint8List.fromList([for (var i = 0; i < _nonceLength; i++) _random.nextInt(256)]);
    final sealed = _cipher(forSealing: true, nonce: nonce).process(Uint8List.fromList(utf8.encode(text)));
    return jsonEncode({_versionField: _version, _nonceField: base64Encode(nonce), _dataField: base64Encode(sealed)});
  }

  /// The text of [data], the decoded JSON of a sealed file. Throws a [FormatException] for a file of another form,
  /// another key, or another purpose, and for a file that changed.
  String open(Object? data) {
    if (!isSealed(data)) throw const FormatException('The file is not sealed.');
    final fields = data as Map<String, Object?>;
    final nonce = _bytes(fields[_nonceField]);
    final sealed = _bytes(fields[_dataField]);
    if (nonce.length != _nonceLength || sealed.length < _tagLength) {
      throw const FormatException('The sealed file is cut short.');
    }
    try {
      return utf8.decode(_cipher(forSealing: false, nonce: nonce).process(sealed));
    } on InvalidCipherTextException {
      throw const FormatException('The sealed file does not open with this key, or it changed.');
    }
  }

  GCMBlockCipher _cipher({required bool forSealing, required Uint8List nonce}) =>
      GCMBlockCipher(AESEngine())
        ..init(forSealing, AEADParameters(KeyParameter(_key), _tagLength * 8, nonce, _purpose));

  static Uint8List _bytes(Object? value) {
    if (value is! String) throw const FormatException('The sealed file lacks a field.');
    return base64Decode(value);
  }

  static const String _versionField = 'sealed';
  static const int _version = 1;
  static const String _nonceField = 'nonce';
  static const String _dataField = 'data';
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
}

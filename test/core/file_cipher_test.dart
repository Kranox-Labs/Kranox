import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/file_cipher.dart';

void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final cipher = FileCipher(key, purpose: 'kranox/test/1');
  const text = '[{"id":"swap1","payoutAddress":"0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}]';

  test('seals a text that only its key and its purpose open again (O-007)', () {
    final sealed = cipher.seal(text);
    expect(sealed, isNot(contains('swap1')));
    expect(sealed, isNot(contains('0x5aaeb')));
    expect(FileCipher.isSealed(jsonDecode(sealed)), isTrue);
    expect(cipher.open(jsonDecode(sealed)), text);
    expect(cipher.seal(text), isNot(sealed), reason: 'each write takes a new nonce');

    final otherKey = FileCipher(Uint8List(32), purpose: 'kranox/test/1');
    expect(() => otherKey.open(jsonDecode(sealed)), throwsFormatException);
    final otherPurpose = FileCipher(key, purpose: 'kranox/other/1');
    expect(() => otherPurpose.open(jsonDecode(sealed)), throwsFormatException);
  });

  test('opens no file that changed, that is cut short, or that is not sealed', () {
    final fields = jsonDecode(cipher.seal(text)) as Map<String, Object?>;
    final data = base64Decode(fields['data']! as String)..[0] ^= 1;
    expect(() => cipher.open({...fields, 'data': base64Encode(data)}), throwsFormatException);
    expect(() => cipher.open({...fields, 'data': base64Encode(Uint8List(4))}), throwsFormatException);
    expect(() => cipher.open({...fields, 'nonce': null}), throwsFormatException);
    expect(FileCipher.isSealed(jsonDecode(text)), isFalse, reason: 'the plain file of an earlier release');
    expect(() => cipher.open(jsonDecode(text)), throwsFormatException);
  });

  test('takes a key of 32 bytes only', () {
    expect(() => FileCipher(Uint8List(16), purpose: 'kranox/test/1'), throwsArgumentError);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/ui/format.dart';

/// The text of a field after a key or a paste turns [before] into [after].
String _typed(TextInputFormatter formatter, String before, String after) =>
    formatter.formatEditUpdate(TextEditingValue(text: before), TextEditingValue(text: after)).text;

void main() {
  test('lets an amount field take digits and one point with a few decimals only', () {
    final formatter = AmountInputFormatter(decimals: 8);
    for (final text in ['', '0', '0.', '0.006', '15', '12.12345678']) {
      expect(_typed(formatter, '', text), text, reason: text);
    }
    for (final text in ['0|', 'abc', '0.006*', '.5', '0..1', '0.1.2', '1,5', '-1', ' 1', '1e3', '0.123456789']) {
      expect(_typed(formatter, '0', text), '0', reason: text);
    }
  });

  test('without a number of decimals, takes any number of them and still no other sign', () {
    final formatter = AmountInputFormatter();
    expect(_typed(formatter, '', '0.0000000000001'), '0.0000000000001');
    for (final text in ['0|', '0.5x', '0..5']) {
      expect(_typed(formatter, '0', text), '0', reason: text);
    }
  });
}

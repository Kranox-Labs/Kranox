import 'package:flutter_test/flutter_test.dart';
import 'package:kranox_wallet/core/amount.dart';

Matcher _throwsProblem(AmountProblem problem) =>
    throwsA(isA<AmountFormatException>().having((error) => error.problem, 'problem', problem));

void main() {
  group('XmrAmount.parse', () {
    test('reads whole and decimal amounts in atomic units', () {
      expect(XmrAmount.parse('1').units, 1000000000000);
      expect(XmrAmount.parse('12.4821').units, 12482100000000);
      expect(XmrAmount.parse('0.000000000001').units, 1);
      expect(XmrAmount.parse('.5').units, 500000000000);
      expect(XmrAmount.parse('  1.5  ').units, 1500000000000);
    });

    test('rejects text that is no amount', () {
      expect(() => XmrAmount.parse(''), _throwsProblem(AmountProblem.empty));
      expect(() => XmrAmount.parse('   '), _throwsProblem(AmountProblem.empty));
      expect(() => XmrAmount.parse('abc'), _throwsProblem(AmountProblem.notANumber));
      expect(() => XmrAmount.parse('1,5'), _throwsProblem(AmountProblem.notANumber));
      expect(() => XmrAmount.parse('-1'), _throwsProblem(AmountProblem.notANumber));
      expect(() => XmrAmount.parse('1.2.3'), _throwsProblem(AmountProblem.notANumber));
      expect(() => XmrAmount.parse('.'), _throwsProblem(AmountProblem.notANumber));
    });

    test('rejects more decimals than one atomic unit', () {
      expect(() => XmrAmount.parse('0.0000000000001'), _throwsProblem(AmountProblem.tooManyDecimals));
    });

    test('rejects zero and amounts beyond the range of the app', () {
      expect(() => XmrAmount.parse('0'), _throwsProblem(AmountProblem.zero));
      expect(() => XmrAmount.parse('0.000'), _throwsProblem(AmountProblem.zero));
      expect(() => XmrAmount.parse('9300000'), _throwsProblem(AmountProblem.tooLarge));
    });
  });

  group('XmrAmount formatting', () {
    test('cuts to a fixed number of decimals and never rounds up', () {
      expect(const XmrAmount(12482100000000).toFixed(4), '12.4821');
      expect(const XmrAmount(999999999999).toFixed(4), '0.9999');
      expect(const XmrAmount(1).toFixed(4), '0.0000');
      expect(const XmrAmount(5000000000000).toFixed(0), '5');
    });

    test('writes every decimal that the amount has', () {
      expect(const XmrAmount(1500000000000).toExact(), '1.5');
      expect(const XmrAmount(2000000000000).toExact(), '2.0');
      expect(const XmrAmount(1).toExact(), '0.000000000001');
    });

    test('adds and compares amounts in atomic units', () {
      const amount = XmrAmount(1000000000000);
      const fee = XmrAmount(30000000);
      expect((amount + fee).units, 1000030000000);
      expect(amount > fee, isTrue);
      expect(amount.compareTo(fee), greaterThan(0));
    });
  });
}

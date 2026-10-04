/// An amount of XMR in atomic units. One XMR has 10^12 atomic units, which Monero calls piconero.
///
/// The amount is a whole number of atomic units, so no rounding of a floating-point number can change it.
final class XmrAmount implements Comparable<XmrAmount> {
  const XmrAmount(this.units);

  static const int decimals = 12;
  static const int unitsPerXmr = 1000000000000;
  static const XmrAmount zero = XmrAmount(0);

  /// The largest amount that the app accepts in a field: the largest whole number of atomic units of Dart.
  static const int maxUnits = 0x7FFFFFFFFFFFFFFF;

  final int units;

  /// Reads an amount that a user types, such as `1`, `0.5`, or `12.4821`. A point separates the decimals.
  /// Throws an [AmountFormatException] that says what is wrong.
  factory XmrAmount.parse(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      throw const AmountFormatException(AmountProblem.empty);
    }
    final match = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(value);
    if (match == null) {
      throw const AmountFormatException(AmountProblem.notANumber);
    }
    final whole = match.group(1) ?? '';
    final fraction = match.group(2) ?? '';
    if (whole.isEmpty && fraction.isEmpty) {
      throw const AmountFormatException(AmountProblem.notANumber);
    }
    if (fraction.length > decimals) {
      throw const AmountFormatException(AmountProblem.tooManyDecimals);
    }
    final digits = '${whole.isEmpty ? '0' : whole}${fraction.padRight(decimals, '0')}';
    final units = BigInt.parse(digits);
    if (units > BigInt.from(maxUnits)) {
      throw const AmountFormatException(AmountProblem.tooLarge);
    }
    if (units == BigInt.zero) {
      throw const AmountFormatException(AmountProblem.zero);
    }
    return XmrAmount(units.toInt());
  }

  /// Writes the amount with exactly [places] decimals. Decimals beyond them are cut, not rounded, so that the
  /// app never shows more than the wallet holds.
  String toFixed(int places) {
    if (places < 0 || places > decimals) {
      throw RangeError.range(places, 0, decimals, 'places');
    }
    final whole = units ~/ unitsPerXmr;
    final fraction = (units % unitsPerXmr).toString().padLeft(decimals, '0').substring(0, places);
    return places == 0 ? '$whole' : '$whole.$fraction';
  }

  /// Writes the amount with every decimal that it has, and at least one.
  String toExact() {
    final whole = units ~/ unitsPerXmr;
    var fraction = (units % unitsPerXmr).toString().padLeft(decimals, '0');
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return '$whole.${fraction.isEmpty ? '0' : fraction}';
  }

  XmrAmount operator +(XmrAmount other) => XmrAmount(units + other.units);
  XmrAmount operator -(XmrAmount other) => XmrAmount(units - other.units);
  bool operator >(XmrAmount other) => units > other.units;

  @override
  int compareTo(XmrAmount other) => units.compareTo(other.units);

  @override
  bool operator ==(Object other) => other is XmrAmount && other.units == units;

  @override
  int get hashCode => units.hashCode;

  @override
  String toString() => '${toExact()} XMR';
}

/// What is wrong with a typed amount.
enum AmountProblem { empty, notANumber, tooManyDecimals, tooLarge, zero }

final class AmountFormatException implements Exception {
  const AmountFormatException(this.problem);

  final AmountProblem problem;

  @override
  String toString() => 'AmountFormatException: ${problem.name}';
}

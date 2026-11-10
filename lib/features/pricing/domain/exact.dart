/// Exact reduced rational arithmetic. No binary floating point enters pricing.
final class Exact implements Comparable<Exact> {
  factory Exact(BigInt numerator, [BigInt? denominator]) {
    final d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw const FormatException('Division by zero');
    final gcd = numerator.gcd(d);
    final sign = d.isNegative ? -BigInt.one : BigInt.one;
    return Exact._(numerator ~/ gcd * sign, d ~/ gcd * sign);
  }
  const Exact._(this.numerator, this.denominator);
  factory Exact.parse(String value) {
    if (value.length > 256) throw const FormatException('Number too long');
    final fraction = RegExp(r'^(-?\d+)/(\d+)$').firstMatch(value);
    if (fraction != null) {
      return Exact(BigInt.parse(fraction[1]!), BigInt.parse(fraction[2]!));
    }
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) {
      throw const FormatException('Enter a plain decimal number');
    }
    final parts = value.split('.');
    final scale = parts.length == 1 ? 0 : parts[1].length;
    return Exact(BigInt.parse(parts.join()), BigInt.from(10).pow(scale));
  }
  factory Exact.integer(int value) => Exact(BigInt.from(value));
  static final zero = Exact.integer(0);
  static final one = Exact.integer(1);
  final BigInt numerator;
  final BigInt denominator;
  Exact operator +(Exact other) => Exact(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  Exact operator -(Exact other) =>
      this + Exact(-other.numerator, other.denominator);
  Exact operator *(Exact other) =>
      Exact(numerator * other.numerator, denominator * other.denominator);
  Exact operator /(Exact other) =>
      Exact(numerator * other.denominator, denominator * other.numerator);
  bool operator <(Exact other) => compareTo(other) < 0;
  bool operator <=(Exact other) => compareTo(other) <= 0;
  bool operator >(Exact other) => compareTo(other) > 0;
  bool operator >=(Exact other) => compareTo(other) >= 0;
  bool get isInteger => denominator == BigInt.one;
  Exact max(Exact other) => this >= other ? this : other;
  Exact ceilTo(Exact increment) {
    if (increment <= zero) throw ArgumentError('Increment must be positive');
    final ratio = this / increment;
    final quotient = ratio.numerator ~/ ratio.denominator;
    final remainder = ratio.numerator.remainder(ratio.denominator);
    return Exact(
          quotient + (remainder > BigInt.zero ? BigInt.one : BigInt.zero),
        ) *
        increment;
  }

  /// Round only at monetary boundaries. Half-up ties go away from zero.
  BigInt roundInteger(MoneyRounding mode) {
    final magnitude = numerator.abs();
    final whole = magnitude ~/ denominator;
    final remainder = magnitude.remainder(denominator);
    final up = switch (mode) {
      MoneyRounding.halfUp => remainder * BigInt.two >= denominator,
      MoneyRounding.halfEven =>
        remainder * BigInt.two > denominator ||
            (remainder * BigInt.two == denominator && whole.isOdd),
      MoneyRounding.down => false,
    };
    return (whole + (up ? BigInt.one : BigInt.zero)) *
        (numerator.isNegative ? -BigInt.one : BigInt.one);
  }

  @override
  int compareTo(Exact other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  @override
  bool operator ==(Object other) =>
      other is Exact &&
      numerator == other.numerator &&
      denominator == other.denominator;
  @override
  int get hashCode => Object.hash(numerator, denominator);
  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

enum MoneyRounding { halfUp, halfEven, down }

final class Currency {
  Currency(this.code, this.minorDigits) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) ||
        minorDigits < 0 ||
        minorDigits > 4) {
      throw ArgumentError('Invalid currency configuration');
    }
  }
  final String code;
  final int minorDigits;
  BigInt minor(Exact major, MoneyRounding rounding) =>
      (major * Exact(BigInt.from(10).pow(minorDigits))).roundInteger(rounding);
  Map<String, Object?> toJson() => {'code': code, 'minorDigits': minorDigits};
  factory Currency.fromJson(Map<String, dynamic> json) =>
      Currency(json['code'] as String, json['minorDigits'] as int);
}

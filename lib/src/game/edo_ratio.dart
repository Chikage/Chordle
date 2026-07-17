import 'dart:math' as math;

const int maxRatioComponent = 999999999;

final class PositiveRatio {
  const PositiveRatio(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  String get label => '$numerator/$denominator';
}

PositiveRatio parsePositiveRatio(String text) {
  final normalized = text.trim();
  if (!RegExp(r'^\d+(?:/\d+)?$').hasMatch(normalized)) {
    throw const FormatException('请输入正整数或形如 3/2 的正分数');
  }

  final parts = normalized.split('/');
  final numerator = int.tryParse(parts.first);
  final denominator = parts.length == 2 ? int.tryParse(parts.last) : 1;
  if (numerator == null || denominator == null) {
    throw const FormatException('分数必须使用整数');
  }
  if (numerator <= 0 || denominator <= 0) {
    throw const FormatException('分子和分母必须大于 0');
  }
  if (numerator > maxRatioComponent || denominator > maxRatioComponent) {
    throw const FormatException('分子和分母最多为 9 位数');
  }

  final divisor = _greatestCommonDivisor(numerator, denominator);
  return PositiveRatio(numerator ~/ divisor, denominator ~/ divisor);
}

/// Maps a rational interval to pure EDO steps using Xen Tuner Calc Steps'
/// no-suffix algorithm: round each prime's EDO mapping independently, then
/// take the exponent dot product. This intentionally differs from rounding
/// the ratio's total logarithm once.
int pureEdoStepsForRatio(PositiveRatio ratio, int edo) {
  if (edo <= 0) throw ArgumentError.value(edo, 'edo', 'must be positive');

  final exponents = <int, int>{};
  void addFactors(int value, int sign) {
    for (final entry in _primeFactors(value).entries) {
      exponents.update(
        entry.key,
        (current) => current + sign * entry.value,
        ifAbsent: () => sign * entry.value,
      );
    }
  }

  addFactors(ratio.numerator, 1);
  addFactors(ratio.denominator, -1);

  var result = 0;
  for (final entry in exponents.entries) {
    final mappedPrime = (edo * math.log(entry.key) / math.ln2).round();
    result += entry.value * mappedPrime;
  }
  return result;
}

Map<int, int> _primeFactors(int value) {
  final factors = <int, int>{};
  var remaining = value;
  while (remaining.isEven) {
    factors.update(2, (count) => count + 1, ifAbsent: () => 1);
    remaining ~/= 2;
  }
  for (var divisor = 3; divisor * divisor <= remaining; divisor += 2) {
    while (remaining % divisor == 0) {
      factors.update(divisor, (count) => count + 1, ifAbsent: () => 1);
      remaining ~/= divisor;
    }
  }
  if (remaining > 1) factors[remaining] = 1;
  return factors;
}

int _greatestCommonDivisor(int first, int second) {
  var a = first;
  var b = second;
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a;
}

import 'package:chordle/src/game/edo_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and reduces positive fractions', () {
    final ratio = parsePositiveRatio(' 6/4 ');

    expect(ratio.numerator, 3);
    expect(ratio.denominator, 2);
    expect(ratio.label, '3/2');
    expect(parsePositiveRatio('3').label, '3/1');
  });

  test('rejects zero, incomplete, and oversized fractions', () {
    expect(() => parsePositiveRatio('0/1'), throwsFormatException);
    expect(() => parsePositiveRatio('3/'), throwsFormatException);
    expect(() => parsePositiveRatio('1000000000/1'), throwsFormatException);
  });

  test('matches Calc Steps pure EDO prime-by-prime rounding', () {
    expect(pureEdoStepsForRatio(parsePositiveRatio('3/2'), 12), 7);
    expect(pureEdoStepsForRatio(parsePositiveRatio('5/4'), 12), 4);
    expect(pureEdoStepsForRatio(parsePositiveRatio('64/63'), 7), 0);
    expect(pureEdoStepsForRatio(parsePositiveRatio('81/80'), 31), 0);
  });

  test('supports ratios below the root', () {
    expect(pureEdoStepsForRatio(parsePositiveRatio('2/3'), 12), -7);
  });
}

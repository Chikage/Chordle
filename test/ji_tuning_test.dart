import 'dart:math' as math;

import 'package:chordle/src/game/chord_game.dart';
import 'package:chordle/src/game/edo_ratio.dart';
import 'package:chordle/src/game/ji_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts MIDI and EDO references to exact frequencies', () {
    expect(frequencyForMidiValue(69), closeTo(440, 0.000001));
    expect(midiValueForFrequency(440), closeTo(69, 0.000001));
    expect(frequencyForExtraStep(138, 24), closeTo(440, 0.000001));
  });

  test('random JI base keeps every ratio inside A0 through C8', () {
    final ratios = <PositiveRatio>[
      parsePositiveRatio('1/1'),
      parsePositiveRatio('3/2'),
      parsePositiveRatio('5/2'),
    ];
    final random = math.Random(17);

    for (var sample = 0; sample < 200; sample += 1) {
      final midi = randomJiBaseMidiNote(ratios, random: random);
      expect(midi, isNotNull);
      final base = midiNoteFrequency(midi!);
      for (final ratio in ratios) {
        expect(isPlayableJiFrequency(base * ratio.value), isTrue);
      }
    }
  });

  test('random JI base uses the Overtones low-note density', () {
    final ratios = <PositiveRatio>[parsePositiveRatio('3/2')];
    final random = math.Random(2048);
    final samples = <int>[
      for (var index = 0; index < 4000; index += 1)
        randomJiBaseMidiNote(ratios, random: random)!,
    ];
    final midpoint = (samples.reduce(math.min) + samples.reduce(math.max)) / 2;
    final lower = samples.where((value) => value <= midpoint).length;
    expect(lower, greaterThan(samples.length * 0.75));
  });

  test('random JI base excludes the previous implicit root', () {
    final ratios = <PositiveRatio>[parsePositiveRatio('3/2')];
    final random = math.Random(72);
    final first = randomJiBaseMidiNote(ratios, random: random)!;
    final second = randomJiBaseMidiNote(
      ratios,
      excludingMidiNote: first,
      random: random,
    )!;

    expect(second, isNot(first));
  });
}

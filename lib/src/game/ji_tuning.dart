import 'dart:math' as math;

import 'chord_game.dart';
import 'edo_ratio.dart';

double frequencyForMidiValue(double midiValue) {
  return 440.0 * math.pow(2.0, (midiValue - 69.0) / 12.0);
}

double midiValueForFrequency(double frequencyHz) {
  return 69.0 + 12.0 * (math.log(frequencyHz / 440.0) / math.ln2);
}

double frequencyForExtraStep(int step, int edo) {
  return frequencyForMidiValue(midiValueForExtraStep(step, edo));
}

int approximateExtraStepForFrequency(double frequencyHz, int edo) {
  return (midiValueForFrequency(frequencyHz) * sanitizeExtraEdo(edo) / 12.0)
      .round();
}

double get lowestJiFrequency => midiNoteFrequency(lowestPlayableMidiNote);
double get highestJiFrequency => midiNoteFrequency(highestPlayableMidiNote);

bool isPlayableJiFrequency(double frequencyHz) {
  return frequencyHz.isFinite &&
      frequencyHz >= lowestJiFrequency - 0.000001 &&
      frequencyHz <= highestJiFrequency + 0.000001;
}

int? randomJiBaseMidiNote(
  Iterable<PositiveRatio> ratios, {
  int? excludingMidiNote,
  math.Random? random,
}) {
  final values = ratios.map((ratio) => ratio.value).toList(growable: false);
  if (values.isEmpty) return null;
  final minimumRatio = values.reduce(math.min);
  final maximumRatio = values.reduce(math.max);
  final allCandidates = <int>[
    for (final midiNote in fullPianoRange.values)
      if (midiNoteFrequency(midiNote) * minimumRatio >=
              lowestJiFrequency - 0.000001 &&
          midiNoteFrequency(midiNote) * maximumRatio <=
              highestJiFrequency + 0.000001)
        midiNote,
  ];
  final candidates = excludingMidiNote != null && allCandidates.length > 1
      ? allCandidates.where((midi) => midi != excludingMidiNote).toList()
      : allCandidates;
  if (candidates.isEmpty) return null;

  var totalWeight = 0;
  for (var index = 0; index < candidates.length; index += 1) {
    totalWeight += overtoneBaseCandidateWeight(index, candidates.length);
  }
  var ticket = (random ?? math.Random()).nextInt(totalWeight);
  for (var index = 0; index < candidates.length; index += 1) {
    ticket -= overtoneBaseCandidateWeight(index, candidates.length);
    if (ticket < 0) return candidates[index];
  }
  return candidates.first;
}

String frequencyLabel(double? frequencyHz) {
  if (frequencyHz == null) return '待随机';
  final decimals = frequencyHz < 100 ? 3 : 2;
  return '${frequencyHz.toStringAsFixed(decimals)} Hz';
}

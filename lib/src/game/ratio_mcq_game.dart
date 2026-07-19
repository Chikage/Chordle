import 'dart:math' as math;

import 'chord_game.dart';
import 'edo_ratio.dart';
import 'ji_tuning.dart';

const int minRatioMcqComponent = 1;
const int maxRatioMcqComponent = 31;
const int minRatioMcqEdo = 12;
const int maxRatioMcqEdo = 72;
const int minRatioMcqRatioCount = 2;
const int maxRatioMcqRatioCount = 10;
const int minRatioMcqOptionCount = 2;
const int maxRatioMcqOptionCount = 10;

/// A positive rational option whose original numerator and denominator must
/// both fit the MCQ editor's 1–31 range.
///
/// Values are reduced immediately, so equivalent inputs such as 6/4 and 3/2
/// compare equal and can be removed with [deduplicateRatioMcqRatios].
final class RatioMcqRatio {
  factory RatioMcqRatio(int numerator, int denominator) {
    validateRatioMcqComponents(numerator, denominator);
    final divisor = _greatestCommonDivisor(numerator, denominator);
    return RatioMcqRatio._(numerator ~/ divisor, denominator ~/ divisor);
  }

  const RatioMcqRatio._(this.numerator, this.denominator);

  factory RatioMcqRatio.parse(String text) {
    final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(text);
    if (match == null) {
      throw const FormatException('比例必须写成 a/b');
    }
    final numerator = int.parse(match.group(1)!);
    final denominator = int.parse(match.group(2)!);
    try {
      return RatioMcqRatio(numerator, denominator);
    } on RangeError catch (error) {
      throw FormatException(error.message?.toString() ?? '比例分子和分母必须为 1–31');
    }
  }

  final int numerator;
  final int denominator;

  String get label => '$numerator/$denominator';

  double get value => numerator / denominator;

  PositiveRatio get positiveRatio => PositiveRatio(numerator, denominator);

  @override
  bool operator ==(Object other) {
    return other is RatioMcqRatio &&
        numerator == other.numerator &&
        denominator == other.denominator;
  }

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => label;
}

void validateRatioMcqComponents(int numerator, int denominator) {
  if (numerator < minRatioMcqComponent || numerator > maxRatioMcqComponent) {
    throw RangeError.range(
      numerator,
      minRatioMcqComponent,
      maxRatioMcqComponent,
      'numerator',
      '分子必须为 1–31 的整数',
    );
  }
  if (denominator < minRatioMcqComponent ||
      denominator > maxRatioMcqComponent) {
    throw RangeError.range(
      denominator,
      minRatioMcqComponent,
      maxRatioMcqComponent,
      'denominator',
      '分母必须为 1–31 的整数',
    );
  }
}

RatioMcqRatio parseRatioMcqRatio(String text) => RatioMcqRatio.parse(text);

List<RatioMcqRatio> deduplicateRatioMcqRatios(Iterable<RatioMcqRatio> ratios) {
  return List<RatioMcqRatio>.unmodifiable(ratios.toSet());
}

/// One selectable tuning: either an EDO from 12 through 72, or exact JI.
final class RatioMcqTuning {
  RatioMcqTuning.edo(int edo) : _edo = edo, isJi = false {
    if (edo < minRatioMcqEdo || edo > maxRatioMcqEdo) {
      throw RangeError.range(
        edo,
        minRatioMcqEdo,
        maxRatioMcqEdo,
        'edo',
        'EDO 必须为 12–72',
      );
    }
  }

  const RatioMcqTuning.ji() : _edo = null, isJi = true;

  final int? _edo;
  final bool isJi;

  bool get isEdo => !isJi;

  int? get edoOrNull => _edo;

  int get edo {
    final value = _edo;
    if (value == null) throw StateError('JI 调律没有 EDO 数值');
    return value;
  }

  String get label => isJi ? 'JI' : '$edo EDO';

  String get storageKey => isJi ? 'JI' : '$edo';

  factory RatioMcqTuning.fromStorageKey(String value) {
    final normalized = value.trim();
    if (normalized.toUpperCase() == 'JI') {
      return const RatioMcqTuning.ji();
    }
    final edo = int.tryParse(normalized);
    if (edo == null) {
      throw FormatException('无法识别调律：$value');
    }
    return RatioMcqTuning.edo(edo);
  }

  @override
  bool operator ==(Object other) {
    return other is RatioMcqTuning && isJi == other.isJi && _edo == other._edo;
  }

  @override
  int get hashCode => Object.hash(isJi, _edo);

  @override
  String toString() => label;
}

List<RatioMcqTuning> deduplicateRatioMcqTunings(
  Iterable<RatioMcqTuning> tunings,
) {
  return List<RatioMcqTuning>.unmodifiable(tunings.toSet());
}

/// An immutable generated A/B ratio question.
final class RatioMcqQuestion {
  const RatioMcqQuestion._({
    required this.tuning,
    required this.targetRatio,
    required this.options,
    required this.correctOptionIndices,
    required this.frequencyAHz,
    required this.frequencyBHz,
    required this.edoRootStep,
    required this.edoTargetStep,
    required this.edoIntervalSteps,
    required this.jiRootMidiNote,
  });

  final RatioMcqTuning tuning;
  final RatioMcqRatio targetRatio;
  final List<RatioMcqRatio> options;
  final Set<int> correctOptionIndices;
  final double frequencyAHz;
  final double frequencyBHz;
  final int? edoRootStep;
  final int? edoTargetStep;
  final int? edoIntervalSteps;
  final int? jiRootMidiNote;

  bool get requiresMultipleSelection => correctOptionIndices.length > 1;

  int get possiblePoints => correctOptionIndices.length;

  List<double> get playbackFrequencies =>
      List<double>.unmodifiable(<double>[frequencyAHz, frequencyBHz]);

  double optionBFrequencyHz(int optionIndex) {
    _checkOptionIndex(optionIndex, options.length);
    final option = options[optionIndex];
    if (tuning.isJi) {
      return frequencyAHz * option.value;
    }

    final rootStep = edoRootStep;
    if (rootStep == null) {
      throw StateError('EDO 题目缺少 A 音 Step');
    }
    final intervalSteps = pureEdoStepsForRatio(
      option.positiveRatio,
      tuning.edo,
    );
    return frequencyForExtraStep(rootStep + intervalSteps, tuning.edo);
  }

  List<double> optionPlaybackFrequencies(int optionIndex) {
    return List<double>.unmodifiable(<double>[
      frequencyAHz,
      optionBFrequencyHz(optionIndex),
    ]);
  }

  bool isCorrectOption(int optionIndex) {
    _checkOptionIndex(optionIndex, options.length);
    return correctOptionIndices.contains(optionIndex);
  }
}

/// Generates questions from one validated settings snapshot.
final class RatioMcqQuestionGenerator {
  RatioMcqQuestionGenerator({
    required Iterable<RatioMcqTuning> tunings,
    required Iterable<RatioMcqRatio> ratios,
    required this.optionCount,
    math.Random? random,
  }) : tunings = deduplicateRatioMcqTunings(tunings),
       ratios = deduplicateRatioMcqRatios(ratios),
       _random = random ?? math.Random() {
    if (this.tunings.isEmpty) {
      throw ArgumentError.value(tunings, 'tunings', '至少选择一种调律');
    }
    if (this.ratios.length < minRatioMcqRatioCount ||
        this.ratios.length > maxRatioMcqRatioCount) {
      throw RangeError.range(
        this.ratios.length,
        minRatioMcqRatioCount,
        maxRatioMcqRatioCount,
        'ratios.length',
        '约分去重后必须保留 2–10 个比例',
      );
    }
    final maximumOptions = math.min(maxRatioMcqOptionCount, this.ratios.length);
    if (optionCount < minRatioMcqOptionCount || optionCount > maximumOptions) {
      throw RangeError.range(
        optionCount,
        minRatioMcqOptionCount,
        maximumOptions,
        'optionCount',
        '选项数必须为 2–比例数量',
      );
    }
  }

  final List<RatioMcqTuning> tunings;
  final List<RatioMcqRatio> ratios;
  final int optionCount;
  final math.Random _random;

  RatioMcqQuestion nextQuestion() {
    final tuning = tunings[_random.nextInt(tunings.length)];
    final targetRatio = ratios[_random.nextInt(ratios.length)];
    final remaining =
        ratios.where((ratio) => ratio != targetRatio).toList(growable: true)
          ..shuffle(_random);
    final options = <RatioMcqRatio>[
      targetRatio,
      ...remaining.take(optionCount - 1),
    ]..shuffle(_random);

    late final double frequencyAHz;
    late final double frequencyBHz;
    int? edoRootStep;
    int? edoTargetStep;
    int? edoIntervalSteps;
    int? jiRootMidiNote;

    if (tuning.isJi) {
      jiRootMidiNote = randomJiBaseMidiNote(<PositiveRatio>[
        targetRatio.positiveRatio,
      ], random: _random);
      if (jiRootMidiNote == null) {
        throw StateError('比例 ${targetRatio.label} 无法在 A0–C8 内生成 JI 题目');
      }
      frequencyAHz = frequencyForMidiValue(jiRootMidiNote.toDouble());
      frequencyBHz = frequencyAHz * targetRatio.value;
    } else {
      final edo = tuning.edo;
      edoIntervalSteps = pureEdoStepsForRatio(targetRatio.positiveRatio, edo);
      final playableSteps = edoStepRangeForMidiRange(edo, fullPianoRange);
      edoRootStep = randomEdoBaseStep(
        <int>[edoIntervalSteps],
        playableSteps,
        random: _random,
      );
      if (edoRootStep == null) {
        throw StateError(
          '比例 ${targetRatio.label} 无法在 ${tuning.label} 的 A0–C8 内生成题目',
        );
      }
      edoTargetStep = edoRootStep + edoIntervalSteps;
      frequencyAHz = frequencyForExtraStep(edoRootStep, edo);
      frequencyBHz = frequencyForExtraStep(edoTargetStep, edo);
    }

    if (!isPlayableJiFrequency(frequencyAHz) ||
        !isPlayableJiFrequency(frequencyBHz)) {
      throw StateError(
        '生成的 ${tuning.label} 题目超出 A0–C8：'
        '${frequencyAHz.toStringAsFixed(3)} / '
        '${frequencyBHz.toStringAsFixed(3)} Hz',
      );
    }

    final correctOptionIndices = <int>{
      for (var index = 0; index < options.length; index += 1)
        if (_isCorrectOption(
          tuning: tuning,
          option: options[index],
          targetRatio: targetRatio,
          edoIntervalSteps: edoIntervalSteps,
        ))
          index,
    };
    if (correctOptionIndices.isEmpty) {
      throw StateError('生成的选项未包含正确答案');
    }

    return RatioMcqQuestion._(
      tuning: tuning,
      targetRatio: targetRatio,
      options: List<RatioMcqRatio>.unmodifiable(options),
      correctOptionIndices: Set<int>.unmodifiable(correctOptionIndices),
      frequencyAHz: frequencyAHz,
      frequencyBHz: frequencyBHz,
      edoRootStep: edoRootStep,
      edoTargetStep: edoTargetStep,
      edoIntervalSteps: edoIntervalSteps,
      jiRootMidiNote: jiRootMidiNote,
    );
  }

  bool _isCorrectOption({
    required RatioMcqTuning tuning,
    required RatioMcqRatio option,
    required RatioMcqRatio targetRatio,
    required int? edoIntervalSteps,
  }) {
    if (tuning.isJi) return option == targetRatio;
    return pureEdoStepsForRatio(option.positiveRatio, tuning.edo) ==
        edoIntervalSteps;
  }
}

final class RatioMcqSubmission {
  const RatioMcqSubmission({
    required this.earnedPoints,
    required this.possiblePoints,
    required this.correctSelections,
    required this.incorrectSelections,
    required this.selectedOptionIndices,
    required this.correctOptionIndices,
  });

  final int earnedPoints;
  final int possiblePoints;
  final int correctSelections;
  final int incorrectSelections;
  final Set<int> selectedOptionIndices;
  final Set<int> correctOptionIndices;

  bool get isPerfect => earnedPoints == possiblePoints;
}

/// Owns one current question, its radio/checkbox selection state, and the
/// cumulative `score / total` for all submitted questions.
final class RatioMcqSession {
  RatioMcqSession(this.generator) : _question = generator.nextQuestion();

  final RatioMcqQuestionGenerator generator;
  RatioMcqQuestion _question;
  final Set<int> _selectedOptionIndices = <int>{};
  RatioMcqSubmission? _lastSubmission;
  var _score = 0;
  var _total = 0;

  RatioMcqQuestion get question => _question;

  Set<int> get selectedOptionIndices =>
      Set<int>.unmodifiable(_selectedOptionIndices);

  RatioMcqSubmission? get lastSubmission => _lastSubmission;

  bool get isSubmitted => _lastSubmission != null;

  int get score => _score;

  int get total => _total;

  String get scoreLabel => '$_score/$_total';

  /// Behaves like a radio group for one-answer questions and like a checkbox
  /// toggle for questions with multiple correct answers.
  void selectOption(int optionIndex) {
    _ensureQuestionOpen();
    _checkOptionIndex(optionIndex, _question.options.length);
    if (_question.requiresMultipleSelection) {
      if (!_selectedOptionIndices.add(optionIndex)) {
        _selectedOptionIndices.remove(optionIndex);
      }
      return;
    }
    _selectedOptionIndices
      ..clear()
      ..add(optionIndex);
  }

  void setOptionSelected(int optionIndex, {required bool selected}) {
    _ensureQuestionOpen();
    _checkOptionIndex(optionIndex, _question.options.length);
    if (!_question.requiresMultipleSelection && selected) {
      _selectedOptionIndices
        ..clear()
        ..add(optionIndex);
      return;
    }
    if (selected) {
      _selectedOptionIndices.add(optionIndex);
    } else {
      _selectedOptionIndices.remove(optionIndex);
    }
  }

  RatioMcqSubmission submit() {
    _ensureQuestionOpen();
    if (_selectedOptionIndices.isEmpty) {
      throw StateError('提交前至少选择一个选项');
    }

    final correctSelections = _selectedOptionIndices
        .where(_question.correctOptionIndices.contains)
        .length;
    final incorrectSelections =
        _selectedOptionIndices.length - correctSelections;
    final earnedPoints = math.max(0, correctSelections - incorrectSelections);
    final possiblePoints = _question.possiblePoints;
    _score += earnedPoints;
    _total += possiblePoints;

    final submission = RatioMcqSubmission(
      earnedPoints: earnedPoints,
      possiblePoints: possiblePoints,
      correctSelections: correctSelections,
      incorrectSelections: incorrectSelections,
      selectedOptionIndices: Set<int>.unmodifiable(_selectedOptionIndices),
      correctOptionIndices: _question.correctOptionIndices,
    );
    _lastSubmission = submission;
    return submission;
  }

  void nextQuestion() {
    if (!isSubmitted) {
      throw StateError('当前题目尚未提交');
    }
    _question = generator.nextQuestion();
    _selectedOptionIndices.clear();
    _lastSubmission = null;
  }

  void _ensureQuestionOpen() {
    if (isSubmitted) throw StateError('当前题目已经提交');
  }
}

void _checkOptionIndex(int optionIndex, int optionCount) {
  if (optionIndex < 0 || optionIndex >= optionCount) {
    throw RangeError.index(optionIndex, List<void>.filled(optionCount, null));
  }
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

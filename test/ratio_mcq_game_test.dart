import 'dart:math' as math;

import 'package:chordle/src/game/ji_tuning.dart';
import 'package:chordle/src/game/ratio_mcq_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MCQ ratio validation', () {
    test('validates raw components before reducing the ratio', () {
      expect(RatioMcqRatio(1, 31).label, '1/31');
      expect(RatioMcqRatio(31, 1).label, '31/1');
      expect(RatioMcqRatio(30, 20).label, '3/2');
      expect(() => RatioMcqRatio(0, 1), throwsRangeError);
      expect(() => RatioMcqRatio(-1, 1), throwsRangeError);
      expect(() => RatioMcqRatio(1, 0), throwsRangeError);
      expect(() => RatioMcqRatio(32, 16), throwsRangeError);
      expect(() => RatioMcqRatio(16, 32), throwsRangeError);
    });

    test('parses a/b and deduplicates equivalent reduced ratios', () {
      final first = parseRatioMcqRatio(' 6 / 4 ');
      final second = RatioMcqRatio(3, 2);
      final unique = deduplicateRatioMcqRatios(<RatioMcqRatio>[
        first,
        second,
        RatioMcqRatio(5, 4),
      ]);

      expect(first, second);
      expect(unique, <RatioMcqRatio>[second, RatioMcqRatio(5, 4)]);
      expect(() => parseRatioMcqRatio('3'), throwsFormatException);
      expect(() => parseRatioMcqRatio('32/16'), throwsFormatException);
      expect(() => parseRatioMcqRatio('3/0'), throwsFormatException);
    });
  });

  group('MCQ tunings and settings bounds', () {
    test('supports 12 through 72 EDO plus JI', () {
      expect(RatioMcqTuning.edo(12).label, '12 EDO');
      expect(RatioMcqTuning.edo(72).storageKey, '72');
      expect(const RatioMcqTuning.ji().label, 'JI');
      expect(RatioMcqTuning.fromStorageKey('JI').isJi, isTrue);
      expect(RatioMcqTuning.fromStorageKey('31').edo, 31);
      expect(() => RatioMcqTuning.edo(11), throwsRangeError);
      expect(() => RatioMcqTuning.edo(73), throwsRangeError);
    });

    test(
      'requires a nonempty tuning set, 2-10 unique ratios, and legal options',
      () {
        final ratios = <RatioMcqRatio>[
          RatioMcqRatio(3, 2),
          RatioMcqRatio(5, 4),
        ];

        expect(
          () => RatioMcqQuestionGenerator(
            tunings: const <RatioMcqTuning>[],
            ratios: ratios,
            optionCount: 2,
          ),
          throwsArgumentError,
        );
        expect(
          () => RatioMcqQuestionGenerator(
            tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
            ratios: <RatioMcqRatio>[RatioMcqRatio(3, 2), RatioMcqRatio(6, 4)],
            optionCount: 2,
          ),
          throwsRangeError,
        );
        expect(
          () => RatioMcqQuestionGenerator(
            tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
            ratios: ratios,
            optionCount: 3,
          ),
          throwsRangeError,
        );
        expect(
          () => RatioMcqQuestionGenerator(
            tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
            ratios: <RatioMcqRatio>[
              for (var denominator = 1; denominator <= 11; denominator += 1)
                RatioMcqRatio(1, denominator),
            ],
            optionCount: 10,
          ),
          throwsRangeError,
        );
      },
    );
  });

  group('question generation', () {
    test(
      'always includes the target and counts all equal EDO steps as correct',
      () {
        final generator = RatioMcqQuestionGenerator(
          tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
          ratios: <RatioMcqRatio>[
            RatioMcqRatio(16, 15),
            RatioMcqRatio(25, 24),
            RatioMcqRatio(3, 2),
          ],
          optionCount: 3,
          random: _ZeroRandom(),
        );

        final question = generator.nextQuestion();

        expect(question.options, contains(question.targetRatio));
        expect(question.targetRatio, RatioMcqRatio(16, 15));
        expect(question.edoIntervalSteps, 1);
        expect(question.correctOptionIndices, hasLength(2));
        expect(question.requiresMultipleSelection, isTrue);
        expect(question.edoRootStep, isNotNull);
        expect(
          question.edoTargetStep,
          question.edoRootStep! + question.edoIntervalSteps!,
        );
      },
    );

    test('JI uses exact reduced-ratio identity and has one correct answer', () {
      final generator = RatioMcqQuestionGenerator(
        tunings: const <RatioMcqTuning>[RatioMcqTuning.ji()],
        ratios: <RatioMcqRatio>[RatioMcqRatio(16, 15), RatioMcqRatio(25, 24)],
        optionCount: 2,
        random: _ZeroRandom(),
      );

      final question = generator.nextQuestion();

      expect(question.correctOptionIndices, hasLength(1));
      expect(question.requiresMultipleSelection, isFalse);
      expect(question.jiRootMidiNote, isNotNull);
      expect(question.edoRootStep, isNull);
      expect(
        question.frequencyBHz / question.frequencyAHz,
        closeTo(question.targetRatio.value, 0.000000001),
      );
    });

    test('extreme ratios remain playable in 12 EDO, 72 EDO, and JI', () {
      for (final tuning in <RatioMcqTuning>[
        RatioMcqTuning.edo(12),
        RatioMcqTuning.edo(72),
        const RatioMcqTuning.ji(),
      ]) {
        final generator = RatioMcqQuestionGenerator(
          tunings: <RatioMcqTuning>[tuning],
          ratios: <RatioMcqRatio>[RatioMcqRatio(1, 31), RatioMcqRatio(31, 1)],
          optionCount: 2,
          random: math.Random(20260719),
        );

        for (var index = 0; index < 40; index += 1) {
          final question = generator.nextQuestion();
          expect(isPlayableJiFrequency(question.frequencyAHz), isTrue);
          expect(isPlayableJiFrequency(question.frequencyBHz), isTrue);
          expect(question.options, contains(question.targetRatio));
        }
      }
    });

    test('a seeded Random reproduces the same question sequence', () {
      RatioMcqQuestionGenerator makeGenerator() => RatioMcqQuestionGenerator(
        tunings: <RatioMcqTuning>[
          RatioMcqTuning.edo(19),
          const RatioMcqTuning.ji(),
        ],
        ratios: <RatioMcqRatio>[
          RatioMcqRatio(5, 4),
          RatioMcqRatio(4, 3),
          RatioMcqRatio(3, 2),
        ],
        optionCount: 2,
        random: math.Random(42),
      );

      final first = makeGenerator();
      final second = makeGenerator();
      for (var index = 0; index < 12; index += 1) {
        final a = first.nextQuestion();
        final b = second.nextQuestion();
        expect(a.tuning, b.tuning);
        expect(a.targetRatio, b.targetRatio);
        expect(a.options, b.options);
        expect(a.correctOptionIndices, b.correctOptionIndices);
        expect(a.frequencyAHz, b.frequencyAHz);
        expect(a.frequencyBHz, b.frequencyBHz);
      }
    });
  });

  group('session selection and scoring', () {
    test(
      'single-answer questions replace the radio selection and score 1 or 0',
      () {
        final session = RatioMcqSession(
          RatioMcqQuestionGenerator(
            tunings: const <RatioMcqTuning>[RatioMcqTuning.ji()],
            ratios: <RatioMcqRatio>[RatioMcqRatio(3, 2), RatioMcqRatio(5, 4)],
            optionCount: 2,
            random: _ZeroRandom(),
          ),
        );
        final correct = session.question.correctOptionIndices.single;
        final wrong = session.question.options.indices.singleWhere(
          (index) => index != correct,
        );

        session.selectOption(correct);
        session.selectOption(wrong);
        expect(session.selectedOptionIndices, <int>{wrong});
        final wrongSubmission = session.submit();
        expect(wrongSubmission.earnedPoints, 0);
        expect(session.scoreLabel, '0/1');

        session.nextQuestion();
        session.selectOption(session.question.correctOptionIndices.single);
        final correctSubmission = session.submit();
        expect(correctSubmission.earnedPoints, 1);
        expect(session.score, 1);
        expect(session.total, 2);
        expect(session.scoreLabel, '1/2');
      },
    );

    test(
      'multi-answer scoring adds correct and subtracts wrong down to zero',
      () {
        final session = RatioMcqSession(
          RatioMcqQuestionGenerator(
            tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
            ratios: <RatioMcqRatio>[
              RatioMcqRatio(16, 15),
              RatioMcqRatio(25, 24),
              RatioMcqRatio(3, 2),
            ],
            optionCount: 3,
            random: _ZeroRandom(),
          ),
        );

        Set<int> correct() => session.question.correctOptionIndices;
        int wrong() => session.question.options.indices.singleWhere(
          (index) => !correct().contains(index),
        );

        session.selectOption(correct().first);
        session.selectOption(wrong());
        final zero = session.submit();
        expect(zero.correctSelections, 1);
        expect(zero.incorrectSelections, 1);
        expect(zero.earnedPoints, 0);
        expect(zero.possiblePoints, 2);
        expect(session.scoreLabel, '0/2');

        session.nextQuestion();
        for (final index in correct()) {
          session.selectOption(index);
        }
        session.selectOption(wrong());
        final penalized = session.submit();
        expect(penalized.earnedPoints, 1);
        expect(session.scoreLabel, '1/4');

        session.nextQuestion();
        for (final index in correct()) {
          session.selectOption(index);
        }
        final perfect = session.submit();
        expect(perfect.earnedPoints, 2);
        expect(perfect.isPerfect, isTrue);
        expect(session.scoreLabel, '3/6');
      },
    );

    test(
      'multi-answer selection toggles and submitted questions are locked',
      () {
        final session = RatioMcqSession(
          RatioMcqQuestionGenerator(
            tunings: <RatioMcqTuning>[RatioMcqTuning.edo(12)],
            ratios: <RatioMcqRatio>[
              RatioMcqRatio(16, 15),
              RatioMcqRatio(25, 24),
            ],
            optionCount: 2,
            random: _ZeroRandom(),
          ),
        );
        final first = session.question.correctOptionIndices.first;

        session.selectOption(first);
        session.selectOption(first);
        expect(session.selectedOptionIndices, isEmpty);
        expect(() => session.submit(), throwsStateError);

        session.selectOption(first);
        session.submit();
        expect(() => session.selectOption(first), throwsStateError);
        expect(() => session.submit(), throwsStateError);
      },
    );
  });
}

final class _ZeroRandom implements math.Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

extension on List<Object?> {
  Iterable<int> get indices sync* {
    for (var index = 0; index < length; index += 1) {
      yield index;
    }
  }
}

import 'dart:math' as math;

import 'package:chordle/src/game/chord_game.dart';
import 'package:flutter_test/flutter_test.dart';

ChordleGame _game(List<int> answer, {int maxAttempts = 6}) {
  return ChordleGame(
    initialPuzzle: ChordPuzzle(notes: answer, label: 'test'),
    maxAttempts: maxAttempts,
  );
}

void _enter(ChordleGame game, Iterable<int> values) {
  for (final value in values) {
    game.selectNote(value);
    expect(
      game.confirmSelectedValue(missingSelectionMessage: 'missing'),
      isTrue,
    );
  }
}

List<TileState> _rowStates(ChordleGame game, int row) {
  return <TileState>[
    for (var column = 0; column < game.columns; column += 1)
      game.cell(row, column).state,
  ];
}

void main() {
  group('guess evaluation', () {
    test('marks exact positions green', () {
      expect(evaluateGuess(<int>[48, 52, 55], <int>[48, 52, 55]), <TileState>[
        TileState.correct,
        TileState.correct,
        TileState.correct,
      ]);
    });

    test('marks wrong positions yellow and missing values gray', () {
      expect(evaluateGuess(<int>[52, 48, 59], <int>[48, 52, 55]), <TileState>[
        TileState.present,
        TileState.present,
        TileState.absent,
      ]);
    });

    test('does not award one duplicate answer value twice', () {
      expect(evaluateGuess(<int>[48, 48, 55], <int>[48, 52, 55]), <TileState>[
        TileState.correct,
        TileState.absent,
        TileState.correct,
      ]);
    });

    test('accepts equivalent reduced overtone ratios', () {
      for (final guess in <List<int>>[
        <int>[12, 15],
        <int>[4, 5],
        <int>[16, 20],
      ]) {
        expect(evaluateOvertoneGuess(guess, <int>[8, 10]), <TileState>[
          TileState.correct,
          TileState.correct,
        ]);
      }
    });

    test('accepts equivalent reduced overtone ratios with three values', () {
      final cases = <(List<int>, List<List<int>>)>[
        (
          <int>[8, 12, 14],
          <List<int>>[
            <int>[4, 6, 7],
            <int>[12, 18, 21],
            <int>[16, 24, 28],
          ],
        ),
        (
          <int>[9, 12, 15],
          <List<int>>[
            <int>[3, 4, 5],
            <int>[6, 8, 10],
            <int>[12, 16, 20],
          ],
        ),
      ];

      for (final (answer, guesses) in cases) {
        for (final guess in guesses) {
          expect(
            evaluateOvertoneGuess(guess, answer),
            List<TileState>.filled(3, TileState.correct),
          );
        }
      }
    });

    test('marks reordered reduced overtone ratio values yellow', () {
      expect(evaluateOvertoneGuess(<int>[15, 12], <int>[8, 10]), <TileState>[
        TileState.present,
        TileState.present,
      ]);
    });

    test('marks a partial reduced-ratio value yellow instead of green', () {
      expect(evaluateOvertoneGuess(<int>[4, 7], <int>[8, 10]), <TileState>[
        TileState.present,
        TileState.absent,
      ]);
    });

    test('marks reordered three-value reduced ratios yellow', () {
      expect(
        evaluateOvertoneGuess(<int>[18, 21, 12], <int>[8, 12, 14]),
        <TileState>[TileState.present, TileState.present, TileState.present],
      );
    });

    test('marks partial three-value reduced-ratio matches yellow', () {
      expect(
        evaluateOvertoneGuess(<int>[6, 10, 14], <int>[9, 12, 15]),
        <TileState>[TileState.present, TileState.present, TileState.absent],
      );
    });
  });

  group('game input and lifecycle', () {
    test('accepts out-of-order values before validation', () {
      final game = _game(<int>[48, 52, 55]);

      _enter(game, <int>[55, 52, 48]);
      expect(game.submitGuess(), isTrue);

      expect(game.rowNotes(0), <int>[55, 52, 48]);
      expect(_rowStates(game, 0), <TileState>[
        TileState.present,
        TileState.correct,
        TileState.present,
      ]);
    });

    test('cells and rows become judged only after submit', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[55, 52, 48]);

      expect(game.cellIsJudged(0, 0), isFalse);
      expect(game.rowIsJudged(0), isFalse);

      game.submitGuess();

      expect(game.cellIsJudged(0, 0), isTrue);
      expect(game.rowIsJudged(0), isTrue);
      expect(game.rowIsJudged(1), isFalse);
    });

    test('rejects duplicate values in the current row', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[48]);

      game.selectNote(48);
      expect(
        game.confirmSelectedValue(missingSelectionMessage: 'missing'),
        isFalse,
      );

      expect(game.rowNotes(0), <int>[48]);
      expect(game.cell(0, 1).note, isNull);
      expect(game.currentColumn, 1);
      expect(game.message, duplicateRowNoteMessage);
    });

    test('requires a full row and uses the supplied item name', () {
      final game = _game(<int>[1, 2]);
      _enter(game, <int>[1]);

      expect(game.submitGuess(itemName: '数字'), isFalse);
      expect(game.message, '请先确认全部 2 个数字');
    });

    test('overtone mode wins with an equivalent reduced ratio', () {
      final game = _game(<int>[8, 10]);
      _enter(game, <int>[12, 15]);

      game.submitOvertoneGuess();

      expect(game.status, GameStatus.won);
      expect(_rowStates(game, 0), <TileState>[
        TileState.correct,
        TileState.correct,
      ]);
    });

    test('overtone mode wins with an equivalent three-value ratio', () {
      final game = _game(<int>[8, 12, 14]);
      _enter(game, <int>[12, 18, 21]);

      game.submitOvertoneGuess();

      expect(game.status, GameStatus.won);
      expect(_rowStates(game, 0), List<TileState>.filled(3, TileState.correct));
    });

    test('wins only after an all-green row', () {
      final game = _game(<int>[48, 52]);
      _enter(game, <int>[48, 52]);

      game.submitGuess();

      expect(game.status, GameStatus.won);
      expect(game.message, '答对了：C3  E3');
    });

    test('loses on the final attempt and exposes the answer', () {
      final game = _game(<int>[48], maxAttempts: 2);
      _enter(game, <int>[49]);
      game.submitGuess();
      _enter(game, <int>[50]);
      game.submitGuess();

      expect(game.status, GameStatus.lost);
      expect(game.message, '答案是：C3');
    });

    test('new puzzle resets all session state', () {
      final game = _game(<int>[48]);
      _enter(game, <int>[49]);
      game.submitGuess();

      game.newPuzzle(ChordPuzzle(notes: <int>[60, 64], label: 'next'));

      expect(game.puzzle.notes, <int>[60, 64]);
      expect(game.currentRow, 0);
      expect(game.currentColumn, 0);
      expect(game.selectedNote, isNull);
      expect(game.status, GameStatus.playing);
      expect(game.message, isNull);
      expect(game.cells, everyElement(const GuessCell()));
    });

    test('pure-Dart change callback is ChangeNotifier-wrapper friendly', () {
      var notifications = 0;
      final game = ChordleGame(
        initialPuzzle: ChordPuzzle(notes: <int>[48], label: 'test'),
        onChanged: (_) => notifications += 1,
      );

      expect(game.selectNote(48), isTrue);
      expect(game.selectNote(48), isFalse);
      game.confirmSelectedValue(missingSelectionMessage: 'missing');
      game.submitGuess();

      expect(notifications, 3);
      expect(game.revision, 3);
    });
  });

  group('sorting and inherited tiles', () {
    test('carried correct cell rejects a duplicate in the next row', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[47, 52, 59]);
      game.submitGuess();
      _enter(game, <int>[52]);

      expect(game.canCarryCorrectCellFromPreviousRow(0, 1), isFalse);
      expect(game.carryCorrectCellFromPreviousRow(1), isFalse);
      expect(game.cell(1, 1).note, isNull);
      expect(game.currentColumn, 1);
      expect(game.message, duplicateRowNoteMessage);
    });

    test('moved present cell rejects a duplicate in the next row', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[52, 48, 59]);
      game.submitGuess();
      _enter(game, <int>[52]);

      expect(game.canPlacePresentCellFromPreviousRow(0, 0, 1), isFalse);
      expect(game.placePresentCellFromPreviousRow(0, 1), isFalse);
      expect(game.cell(1, 1).note, isNull);
      expect(game.currentColumn, 1);
      expect(game.message, duplicateRowNoteMessage);
    });

    test('carried correct cell fixes its column and skips keyboard input', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[48, 57, 59]);
      game.submitGuess();

      expect(game.carryCorrectCellFromPreviousRow(0), isTrue);
      expect(game.cell(1, 0).note, 48);
      expect(game.cell(1, 0).state, TileState.carried);
      expect(game.cell(1, 0).carriedState, TileState.correct);
      expect(game.cellIsJudged(1, 0), isFalse);
      expect(game.currentColumn, 1);

      _enter(game, <int>[52, 55]);
      expect(game.rowNotes(1), <int>[48, 52, 55]);
      game.submitGuess();
      expect(game.status, GameStatus.won);
    });

    test('carried correct cell can replace a filled matching column', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[47, 52, 59]);
      game.submitGuess();
      _enter(game, <int>[48, 59]);

      expect(game.cell(1, 1).note, 59);
      expect(game.carryCorrectCellFromPreviousRow(1), isTrue);
      expect(game.cell(1, 1).note, 52);
      expect(game.cell(1, 1).state, TileState.carried);
      expect(game.currentColumn, 2);
    });

    test('delete skips fixed carried cells', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[48, 57, 59]);
      game.submitGuess();
      game.carryCorrectCellFromPreviousRow(0);
      _enter(game, <int>[52]);

      expect(game.deleteLast(), isTrue);
      expect(game.cell(1, 0).note, 48);
      expect(game.cell(1, 0).state, TileState.carried);
      expect(game.cell(1, 1).note, isNull);
      expect(game.currentColumn, 1);
      expect(game.canDeleteLast(), isFalse);
    });

    test('sort reorders values and keeps the next open column', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[55, 48]);

      expect(game.sortRowBy(0), isTrue);
      expect(game.rowNotes(0), <int>[48, 55]);
      expect(game.cell(0, 2).note, isNull);
      expect(game.currentColumn, 2);
    });

    test('sort preserves each value cell state', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[48, 57, 59]);
      game.submitGuess();
      game.carryCorrectCellFromPreviousRow(0);
      _enter(game, <int>[55, 52]);

      expect(game.sortRowBy(1), isTrue);
      expect(game.rowNotes(1), <int>[48, 52, 55]);
      expect(_rowStates(game, 1), <TileState>[
        TileState.carried,
        TileState.input,
        TileState.input,
      ]);
      expect(game.currentColumn, 3);
    });

    test('sort never moves a carried correct tile out of its fixed column', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[60, 62, 55]);
      game.submitGuess();
      game.carryCorrectCellFromPreviousRow(2);
      _enter(game, <int>[60, 48]);

      expect(game.sortRowBy(1), isTrue);
      expect(game.rowNotes(1), <int>[48, 60, 55]);
      expect(game.cell(1, 2).state, TileState.carried);
      expect(game.cell(1, 2).note, 55);
    });

    test('custom sort key has a deterministic note tie-breaker', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[60, 48, 55]);

      game.sortRowBy(0, sortKey: (note) => note % 12);

      expect(game.rowNotes(0), <int>[48, 60, 55]);
    });

    test('present cell moves only to a different column as input', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[52, 48, 59]);
      game.submitGuess();

      expect(game.cell(0, 0).state, TileState.present);
      expect(game.placePresentCellFromPreviousRow(0, 0), isFalse);
      expect(game.placePresentCellFromPreviousRow(0, 1), isTrue);
      expect(game.cell(1, 1).note, 52);
      expect(game.cell(1, 1).state, TileState.input);
      expect(game.cell(1, 1).carriedState, TileState.present);
      expect(game.currentColumn, 0);

      _enter(game, <int>[48, 55]);
      game.submitGuess();
      expect(game.status, GameStatus.won);
    });

    test('present cell can replace a filled different column', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[52, 48, 59]);
      game.submitGuess();
      _enter(game, <int>[48, 60]);

      expect(game.placePresentCellFromPreviousRow(0, 1), isTrue);
      expect(game.cell(1, 1).note, 52);
      expect(game.currentColumn, 2);
    });

    test('delete removes a moved present tile ahead of current column', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[52, 48, 59]);
      game.submitGuess();
      game.placePresentCellFromPreviousRow(0, 2);

      expect(game.currentColumn, 0);
      expect(game.canDeleteLast(), isTrue);
      game.deleteLast();
      expect(game.cell(1, 2).note, isNull);
      expect(game.currentColumn, 0);
      expect(game.canDeleteLast(), isFalse);
    });

    test('generic iOS-style drag API enforces source color position rules', () {
      final game = _game(<int>[48, 52, 55]);
      _enter(game, <int>[48, 55, 59]);
      game.submitGuess();

      expect(game.canCarryTile(row: 0, column: 0), isTrue);
      expect(game.canCarryTile(row: 0, column: 1), isTrue);
      expect(
        game.canReceiveCarriedTile(
          fromRow: 0,
          column: 0,
          note: 48,
          toRow: 1,
          targetColumn: 1,
        ),
        isFalse,
      );
      expect(
        game.carryTile(
          fromRow: 0,
          column: 1,
          note: 55,
          toRow: 1,
          targetColumn: 2,
        ),
        isTrue,
      );
    });
  });

  group('ranges and random normal puzzles', () {
    test('playable range keeps at least one octave', () {
      expect(
        sanitizePlayableRange(const IntRange(60, 64)),
        const IntRange(60, 72),
      );
    });

    test('playable range endpoints snap inward to white keys', () {
      expect(
        sanitizePlayableRange(const IntRange(61, 73)),
        const IntRange(62, 74),
      );
      expect(
        sanitizePlayableRange(const IntRange(21, 34)),
        const IntRange(21, 33),
      );
      expect(
        sanitizePlayableRange(const IntRange(97, 108)),
        const IntRange(96, 108),
      );
    });

    test(
      'normal puzzle stays in range, unique, sorted, and requested size',
      () {
        final random = math.Random(7);
        for (var iteration = 0; iteration < 50; iteration += 1) {
          final puzzle = ChordPuzzle.random(
            noteCount: 10,
            noteRange: const IntRange(48, 72),
            random: random,
          );
          expect(puzzle.notes, hasLength(10));
          expect(puzzle.notes.toSet(), hasLength(10));
          expect(puzzle.notes, orderedEquals(<int>[...puzzle.notes]..sort()));
          expect(puzzle.notes, everyElement(inInclusiveRange(48, 72)));
        }
      },
    );

    test('tone count clamps to one through ten', () {
      expect(sanitizeChordToneCount(-4), 1);
      expect(sanitizeChordToneCount(7), 7);
      expect(sanitizeChordToneCount(42), 10);
    });
  });

  group('Extra EDO rules and names', () {
    test('generic EDO step range preserves the full A0 to C8 span', () {
      expect(
        edoStepRangeForMidiRange(24, fullPianoRange),
        const IntRange(42, 216),
      );
      expect(
        edoStepRangeForMidiRange(13, fullPianoRange),
        const IntRange(23, 117),
      );
    });

    test('random EDO roots stay playable and differ from the last root', () {
      final range = edoStepRangeForMidiRange(24, fullPianoRange);
      final offsets = <int>[8, 14, 32];
      final random = math.Random(91);
      final first = randomEdoBaseStep(offsets, range, random: random)!;
      final second = randomEdoBaseStep(
        offsets,
        range,
        excludingStep: first,
        random: random,
      )!;

      expect(second, isNot(first));
      for (final root in <int>[first, second]) {
        expect(
          offsets.map((offset) => root + offset),
          everyElement(range.contains),
        );
      }
    });

    test('extra playable range endpoints are C notes', () {
      expect(
        sanitizeExtraPlayableRange(const IntRange(34, 77)),
        const IntRange(36, 72),
      );
      expect(
        sanitizeExtraPlayableRange(const IntRange(21, 33)),
        const IntRange(24, 36),
      );
      expect(
        sanitizeExtraPlayableRange(const IntRange(107, 108)),
        const IntRange(96, 108),
      );
    });

    test('random extra puzzle uses its sanitized range', () {
      final random = math.Random(11);
      for (var iteration = 0; iteration < 50; iteration += 1) {
        final puzzle = ChordPuzzle.randomExtra(
          noteCount: 3,
          noteRange: const IntRange(34, 77),
          edo: 12,
          random: random,
        );
        expect(puzzle.notes, everyElement(inInclusiveRange(36, 72)));
        expect(puzzle.notes, orderedEquals(<int>[...puzzle.notes]..sort()));
      }
    });

    test('POTD labels cover 24 and 53 EDO examples', () {
      expect(extraStepTileLabel(96, 24), 'C3');
      expect(extraStepTileLabel(103, 24), 'dE3');
      expect(extraStepTileLabel(49 + 53 * 5, 53), 'B4');
      expect(extraStepLabel(49 + 53 * 5, 53), 'B4');
    });

    test('7 EDO uses simple diatonic names', () {
      expect(
        <String>[
          for (var step = 0; step < 7; step += 1)
            extraStepLabel(step + 7 * 5, 7),
        ],
        <String>['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4'],
      );
    });

    test('14 EDO uses raised diatonic names', () {
      expect(
        <String>[
          for (var step = 0; step < 14; step += 1)
            extraStepLabel(step + 14 * 5, 14),
        ],
        <String>[
          'C4',
          '^C4',
          'D4',
          '^D4',
          'E4',
          '^E4',
          'F4',
          '^F4',
          'G4',
          '^G4',
          'A4',
          '^A4',
          'B4',
          '^B4',
        ],
      );
    });

    test('21 EDO uses third-tone diatonic names', () {
      expect(
        <String>[
          for (var step = 0; step < 21; step += 1)
            extraStepLabel(step + 21 * 5, 21),
        ],
        <String>[
          'C4',
          '^C4',
          'vD4',
          'D4',
          '^D4',
          'vE4',
          'E4',
          '^E4',
          'vF4',
          'F4',
          '^F4',
          'vG4',
          'G4',
          '^G4',
          'vA4',
          'A4',
          '^A4',
          'vB4',
          'B4',
          '^B4',
          'vC4',
        ],
      );
    });

    test('28 EDO uses quarter-tone diatonic names', () {
      expect(
        <String>[
          for (var step = 0; step < 28; step += 1)
            extraStepLabel(step + 28 * 5, 28),
        ],
        <String>[
          'C4',
          '^C4',
          '^^C4',
          'vD4',
          'D4',
          '^D4',
          '^^D4',
          'vE4',
          'E4',
          '^E4',
          '^^E4',
          'vF4',
          'F4',
          '^F4',
          '^^F4',
          'vG4',
          'G4',
          '^G4',
          '^^G4',
          'vA4',
          'A4',
          '^A4',
          '^^A4',
          'vB4',
          'B4',
          '^B4',
          '^^B4',
          'vC4',
        ],
      );
    });

    test('35 EDO uses fifth-tone diatonic names', () {
      expect(
        <String>[
          for (var step = 0; step < 35; step += 1)
            extraStepLabel(step + 35 * 5, 35),
        ],
        <String>[
          'C4',
          '^C4',
          '^^C4',
          'vvD4',
          'vD4',
          'D4',
          '^D4',
          '^^D4',
          'vvE4',
          'vE4',
          'E4',
          '^E4',
          '^^E4',
          'vvF4',
          'vF4',
          'F4',
          '^F4',
          '^^F4',
          'vvG4',
          'vG4',
          'G4',
          '^G4',
          '^^G4',
          'vvA4',
          'vA4',
          'A4',
          '^A4',
          '^^A4',
          'vvB4',
          'vB4',
          'B4',
          '^B4',
          '^^B4',
          'vvC4',
          'vC4',
        ],
      );
    });

    test('extra evaluation uses an inclusive fifty-cent tolerance', () {
      expect(
        evaluateExtraGuess(<int>[97, 108, 100], <int>[96, 108, 120], 24),
        <TileState>[
          TileState.extraCorrect,
          TileState.correct,
          TileState.absent,
        ],
      );
    });

    test('exact chord tones in wrong positions are yellow', () {
      expect(
        evaluateExtraGuess(<int>[108, 96], <int>[96, 108], 24),
        <TileState>[TileState.present, TileState.present],
      );
    });

    test('near chord tones in wrong positions are pink', () {
      expect(
        evaluateExtraGuess(<int>[109, 97], <int>[96, 108], 24),
        <TileState>[TileState.extraNear, TileState.extraNear],
      );
    });

    test('tolerance-only cells do not win', () {
      final game = _game(<int>[96, 108]);
      _enter(game, <int>[97, 109]);
      game.submitExtraGuess(24);

      expect(game.status, GameStatus.playing);
      expect(_rowStates(game, 0), <TileState>[
        TileState.extraCorrect,
        TileState.extraCorrect,
      ]);
    });

    test('Extra wins only on exact green cells', () {
      final game = _game(<int>[96, 108]);
      _enter(game, <int>[96, 108]);
      game.submitExtraGuess(24);

      expect(game.status, GameStatus.won);
      expect(_rowStates(game, 0), <TileState>[
        TileState.correct,
        TileState.correct,
      ]);
    });
  });

  group('MIDI and overtones', () {
    test('MIDI program clamps to zero through 127', () {
      expect(sanitizeMidiProgramNumber(-1), 0);
      expect(sanitizeMidiProgramNumber(64), 64);
      expect(sanitizeMidiProgramNumber(200), 127);
    });

    test('overtone range keeps at least two selectable values through 99', () {
      expect(
        sanitizeOvertoneRange(const IntRange(8, 16)),
        const IntRange(8, 16),
      );
      expect(sanitizeOvertoneRange(const IntRange(1, 2)), const IntRange(1, 2));
      expect(
        sanitizeOvertoneRange(const IntRange(20, 31)),
        const IntRange(20, 31),
      );
      expect(
        sanitizeOvertoneRange(const IntRange(99, 99)),
        const IntRange(98, 99),
      );
    });

    test('overtone tone count depends on the sanitized range size', () {
      expect(sanitizeOvertoneToneCount(10, const IntRange(1, 3)), 3);
      expect(sanitizeOvertoneToneCount(4, const IntRange(8, 16)), 4);
      expect(sanitizeOvertoneToneCount(10, const IntRange(8, 16)), 9);
      expect(sanitizeOvertoneToneCount(30, const IntRange(1, 99)), 10);
    });

    test('register weights prioritize complete C3-C6 chords', () {
      expect(
        chordRegisterWeight(lowestMidi: 48, highestMidi: 84),
        preferredChordRegisterWeight,
      );
      expect(
        chordRegisterWeight(lowestMidi: 47, highestMidi: 84),
        extendedChordRegisterWeight,
      );
      expect(
        chordRegisterWeight(lowestMidi: 36, highestMidi: 96),
        extendedChordRegisterWeight,
      );
      expect(
        chordRegisterWeight(lowestMidi: 35, highestMidi: 96),
        outsideChordRegisterWeight,
      );
      expect(
        chordRegisterWeight(lowestMidi: 97, highestMidi: 60),
        outsideChordRegisterWeight,
      );
    });

    test('base candidate weights center on the C3-C6 region', () {
      final centered = centeredChordRootCandidateWeight(
        lowestMidi: 60,
        highestMidi: 72,
      );
      final equallyLow = centeredChordRootCandidateWeight(
        lowestMidi: 42,
        highestMidi: 54,
      );
      final equallyHigh = centeredChordRootCandidateWeight(
        lowestMidi: 78,
        highestMidi: 90,
      );
      final farOutside = centeredChordRootCandidateWeight(
        lowestMidi: 21,
        highestMidi: 33,
      );

      expect(centered, closeTo(1, 0.000000001));
      expect(equallyLow, closeTo(equallyHigh, 0.000000001));
      expect(centered, greaterThan(equallyLow));
      expect(farOutside, lessThan(equallyLow));
    });

    test('random bases overwhelmingly keep the full chord in C3-C6', () {
      const ratioValues = <int>[8, 10, 12, 15];
      final random = math.Random(20260722);
      var preferredCount = 0;
      var outsideCount = 0;
      const drawCount = 2000;
      final intervalSemitones = 12 * math.log(15 / 8) / math.ln2;

      for (var index = 0; index < drawCount; index += 1) {
        final lowestMidi = randomOvertoneBaseMidiNote(
          ratioValues,
          random: random,
        ).toDouble();
        final highestMidi = lowestMidi + intervalSemitones;
        if (lowestMidi >= preferredChordMidiRange.lowerBound &&
            highestMidi <= preferredChordMidiRange.upperBound) {
          preferredCount += 1;
        }
        if (lowestMidi < extendedChordMidiRange.lowerBound ||
            highestMidi > extendedChordMidiRange.upperBound) {
          outsideCount += 1;
        }
      }

      expect(preferredCount, greaterThan(drawCount * 85 ~/ 100));
      expect(outsideCount, lessThan(drawCount * 2 ~/ 100));
    });

    test(
      'base candidates depend on the actual ratio instead of the range cap',
      () {
        final actualRatioCandidates = overtoneBaseCandidates(<int>[8, 10, 15]);
        final oldMultiplierCandidates = overtoneBaseCandidates(<int>[8, 99]);

        expect(
          actualRatioCandidates.last,
          greaterThan(oldMultiplierCandidates.last),
        );
        final highestActualFrequency =
            midiNoteFrequency(actualRatioCandidates.last) * 15 / 8;
        expect(isPlayableOvertoneFrequency(highestActualFrequency), isTrue);
      },
    );

    test('8:10:15 starts at the lowest tone and uses exact JI ratios', () {
      final puzzle = ChordPuzzle(
        notes: const <int>[8, 10, 15],
        label: 'test',
        baseMidiNote: 48,
      );
      final baseFrequency = midiNoteFrequency(48);

      expect(overtoneFrequencies(puzzle, puzzle.notes), <Matcher>[
        closeTo(baseFrequency, 0.000001),
        closeTo(baseFrequency * 10 / 8, 0.000001),
        closeTo(baseFrequency * 15 / 8, 0.000001),
      ]);
    });

    test(
      'random overtone puzzles use JI ratios and keep every tone playable',
      () {
        final random = math.Random(13);
        for (var iteration = 0; iteration < 200; iteration += 1) {
          final puzzle = ChordPuzzle.randomOvertones(
            toneCount: 4,
            multiplierRange: const IntRange(1, 99),
            random: random,
          );
          final frequencies = overtoneFrequencies(puzzle, puzzle.notes);

          expect(puzzle.notes, hasLength(4));
          expect(puzzle.notes, orderedEquals(<int>[...puzzle.notes]..sort()));
          expect(puzzle.notes, everyElement(inInclusiveRange(1, 99)));
          expect(frequencies, hasLength(puzzle.notes.length));
          expect(
            frequencies,
            everyElement(predicate(isPlayableOvertoneFrequency)),
          );
        }
      },
    );
  });
}

import 'dart:math' as math;

/// Immutable inclusive integer range used by the platform-neutral game core.
final class IntRange {
  const IntRange(this.lowerBound, this.upperBound)
    : assert(lowerBound <= upperBound);

  factory IntRange.sorted(int first, int second) {
    return first <= second ? IntRange(first, second) : IntRange(second, first);
  }

  final int lowerBound;
  final int upperBound;

  int get count => upperBound - lowerBound + 1;

  bool contains(int value) => value >= lowerBound && value <= upperBound;

  Iterable<int> get values sync* {
    for (var value = lowerBound; value <= upperBound; value += 1) {
      yield value;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is IntRange &&
        other.lowerBound == lowerBound &&
        other.upperBound == upperBound;
  }

  @override
  int get hashCode => Object.hash(lowerBound, upperBound);

  @override
  String toString() => '$lowerBound..$upperBound';
}

enum ChordleMode { normal, extra, overtones }

enum TileState {
  empty,
  input,
  carried,
  correct,
  extraCorrect,
  present,
  extraNear,
  absent,
}

enum GameStatus { playing, won, lost }

const int lowestPlayableMidiNote = 21;
const int highestPlayableMidiNote = 108;
const int minimumPlayableRangeSemitones = 12;
const int minChordToneCount = 1;
const int maxChordToneCount = 10;
const int defaultChordToneCount = 3;
const int minExtraEdo = 1;
const int maxExtraEdo = 72;
const int defaultExtraEdo = 24;
const double extraPitchToleranceCents = 50;
const int lowestExtraPlayableMidiNote = 24;
const int highestExtraPlayableMidiNote = 108;
const int minExtraRangeOctave = 1;
const int maxExtraRangeOctave = 8;
const int minMidiProgramNumber = 0;
const int maxMidiProgramNumber = 127;
const int defaultMidiProgramNumber = 0;
const int minOvertoneMultiplier = 1;
const int maxOvertoneMultiplier = 31;
const int minOvertoneToneCount = 2;
const int maxOvertoneToneCountLimit = 10;
const int defaultOvertoneToneCount = 4;
const IntRange defaultPlayableRange = IntRange(48, 72);
const IntRange defaultExtraPlayableRange = IntRange(48, 72);
const IntRange fullPianoRange = IntRange(
  lowestPlayableMidiNote,
  highestPlayableMidiNote,
);
const IntRange defaultOvertoneRange = IntRange(8, 16);
const String duplicateRowNoteMessage = '这一行不能填写两个相同的音';

const List<String> _pitchNames = <String>[
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const Map<String, String> _extraPitchNames = <String, String>{
  '1': 'C',
  '2': 'D',
  '3': 'E',
  '4': 'F',
  '5': 'G',
  '6': 'A',
  '7': 'B',
};

const Map<int, List<String>> _simpleExtraPitchNameTables = <int, List<String>>{
  7: <String>['C', 'D', 'E', 'F', 'G', 'A', 'B'],
  14: <String>[
    'C',
    '^C',
    'D',
    '^D',
    'E',
    '^E',
    'F',
    '^F',
    'G',
    '^G',
    'A',
    '^A',
    'B',
    '^B',
  ],
  21: <String>[
    'C',
    '^C',
    'vD',
    'D',
    '^D',
    'vE',
    'E',
    '^E',
    'vF',
    'F',
    '^F',
    'vG',
    'G',
    '^G',
    'vA',
    'A',
    '^A',
    'vB',
    'B',
    '^B',
    'vC',
  ],
  28: <String>[
    'C',
    '^C',
    '^^C',
    'vD',
    'D',
    '^D',
    '^^D',
    'vE',
    'E',
    '^E',
    '^^E',
    'vF',
    'F',
    '^F',
    '^^F',
    'vG',
    'G',
    '^G',
    '^^G',
    'vA',
    'A',
    '^A',
    '^^A',
    'vB',
    'B',
    '^B',
    '^^B',
    'vC',
  ],
  35: <String>[
    'C',
    '^C',
    '^^C',
    'vvD',
    'vD',
    'D',
    '^D',
    '^^D',
    'vvE',
    'vE',
    'E',
    '^E',
    '^^E',
    'vvF',
    'vF',
    'F',
    '^F',
    '^^F',
    'vvG',
    'vG',
    'G',
    '^G',
    '^^G',
    'vvA',
    'vA',
    'A',
    '^A',
    '^^A',
    'vvB',
    'vB',
    'B',
    '^B',
    '^^B',
    'vvC',
    'vC',
  ],
};

final List<int> playableWhiteKeyMidiNotes = List<int>.unmodifiable(
  fullPianoRange.values.where(isWhiteMidiKey),
);

final class GuessCell {
  const GuessCell({this.note, this.state = TileState.empty, this.carriedState});

  final int? note;
  final TileState state;

  /// The judged source state used by the iOS drag UI for inherited coloring.
  /// Android represents a fixed green cell with [TileState.carried], while a
  /// moved yellow cell remains [TileState.input]. Keeping both fields supports
  /// both platform behaviors without coupling the core to either UI toolkit.
  final TileState? carriedState;

  bool get isCarried => state == TileState.carried || carriedState != null;

  GuessCell copyWith({
    int? note,
    bool clearNote = false,
    TileState? state,
    TileState? carriedState,
    bool clearCarriedState = false,
  }) {
    return GuessCell(
      note: clearNote ? null : (note ?? this.note),
      state: state ?? this.state,
      carriedState: clearCarriedState
          ? null
          : (carriedState ?? this.carriedState),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GuessCell &&
        other.note == note &&
        other.state == state &&
        other.carriedState == carriedState;
  }

  @override
  int get hashCode => Object.hash(note, state, carriedState);

  @override
  String toString() {
    return 'GuessCell(note: $note, state: $state, carriedState: '
        '$carriedState)';
  }
}

final class ChordPuzzle {
  ChordPuzzle({
    required Iterable<int> notes,
    required this.label,
    String? answerLabel,
    this.baseMidiNote,
  }) : notes = List<int>.unmodifiable(notes),
       answerLabel = answerLabel ?? notes.map(noteLabel).join('  ');

  final List<int> notes;
  final String label;
  final String answerLabel;
  final int? baseMidiNote;

  static ChordPuzzle random({
    int noteCount = defaultChordToneCount,
    IntRange noteRange = defaultPlayableRange,
    math.Random? random,
  }) {
    final playableRange = sanitizePlayableRange(noteRange);
    final count = sanitizeChordToneCount(noteCount);
    final notes = _randomSortedValues(
      playableRange,
      count,
      random ?? math.Random(),
    );
    final label = notes.length == 1
        ? '${noteLabel(notes.first)} single'
        : '${notes.length}-tone';
    return ChordPuzzle(notes: notes, label: label);
  }

  static ChordPuzzle randomExtra({
    int noteCount = defaultChordToneCount,
    IntRange noteRange = defaultExtraPlayableRange,
    int edo = defaultExtraEdo,
    math.Random? random,
  }) {
    final normalizedEdo = sanitizeExtraEdo(edo);
    final playableRange = sanitizeExtraPlayableRange(noteRange);
    final count = sanitizeChordToneCount(noteCount);
    final stepRange = extraStepRangeForMidiRange(normalizedEdo, playableRange);
    final notes = _randomSortedValues(
      stepRange,
      count,
      random ?? math.Random(),
    );
    return ChordPuzzle(
      notes: notes,
      label: '${normalizedEdo}EDO',
      answerLabel: notes
          .map((step) => extraStepLabel(step, normalizedEdo))
          .join('  '),
    );
  }

  static ChordPuzzle randomOvertones({
    int toneCount = defaultOvertoneToneCount,
    IntRange multiplierRange = defaultOvertoneRange,
    math.Random? random,
  }) {
    final overtoneRange = sanitizeOvertoneRange(multiplierRange);
    final count = sanitizeOvertoneToneCount(toneCount, overtoneRange);
    final rng = random ?? math.Random();
    final multipliers = _randomSortedValues(overtoneRange, count, rng);
    final baseMidiNote = randomOvertoneBaseMidiNote(overtoneRange, random: rng);
    return ChordPuzzle(
      notes: multipliers,
      label:
          '${noteLabel(baseMidiNote)} · '
          '${overtoneRange.lowerBound}-${overtoneRange.upperBound}x',
      answerLabel: multipliers.join('  '),
      baseMidiNote: baseMidiNote,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChordPuzzle &&
        _listEquals(other.notes, notes) &&
        other.label == label &&
        other.answerLabel == answerLabel &&
        other.baseMidiNote == baseMidiNote;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(notes), label, answerLabel, baseMidiNote);

  @override
  String toString() {
    return 'ChordPuzzle(notes: $notes, label: $label, answerLabel: '
        '$answerLabel, baseMidiNote: $baseMidiNote)';
  }
}

/// Pure-Dart mutable game session.
///
/// A Flutter [ChangeNotifier] wrapper can set [onChanged] to `notifyListeners`
/// and delegate user actions to this object. [revision] is incremented once per
/// observable action, making selector-style integrations straightforward too.
final class ChordleGame {
  ChordleGame({
    ChordPuzzle? initialPuzzle,
    this.maxAttempts = 6,
    this.onChanged,
  }) : assert(maxAttempts > 0),
       _puzzle = initialPuzzle ?? ChordPuzzle.random() {
    _rebuildCells();
  }

  final int maxAttempts;
  void Function(ChordleGame game)? onChanged;

  ChordPuzzle _puzzle;
  int _currentRow = 0;
  int _currentColumn = 0;
  int? _selectedNote;
  GameStatus _status = GameStatus.playing;
  String? _message;
  final List<GuessCell> _cells = <GuessCell>[];
  int _revision = 0;

  ChordPuzzle get puzzle => _puzzle;
  int get currentRow => _currentRow;
  int get currentColumn => _currentColumn;
  int? get selectedNote => _selectedNote;
  GameStatus get status => _status;
  String? get message => _message;
  int get revision => _revision;
  int get columns => _puzzle.notes.length;
  String get answerText => _puzzle.answerLabel;
  List<GuessCell> get cells => List<GuessCell>.unmodifiable(_cells);

  bool selectNote(int note) {
    if (_selectedNote == note) {
      return false;
    }
    _selectedNote = note;
    _emitChanged();
    return true;
  }

  bool confirmSelectedNote() {
    return confirmSelectedValue(missingSelectionMessage: '先在钢琴上选择一个音');
  }

  bool confirmSelectedValue({required String missingSelectionMessage}) {
    if (_status != GameStatus.playing) {
      return false;
    }
    final note = _selectedNote;
    if (note == null) {
      _message = missingSelectionMessage;
      _emitChanged();
      return false;
    }
    final column = _nextOpenColumn(_currentColumn);
    if (column >= columns) {
      _message = '这一行已经填满';
      _emitChanged();
      return false;
    }
    if (_rowContainsNote(_currentRow, note, exceptColumn: column)) {
      _message = duplicateRowNoteMessage;
      _emitChanged();
      return false;
    }
    _setCell(
      _currentRow,
      column,
      GuessCell(note: note, state: TileState.input),
    );
    _currentColumn = _nextOpenColumn(column + 1);
    _emitChanged();
    return true;
  }

  bool deleteLast() {
    final column = _previousInputColumn();
    if (column == null) {
      return false;
    }
    _setCell(_currentRow, column, const GuessCell());
    _currentColumn = _nextOpenColumn(0);
    _emitChanged();
    return true;
  }

  bool canDeleteLast() => _previousInputColumn() != null;

  bool canSortRow(int row) {
    return _status == GameStatus.playing &&
        row == _currentRow &&
        row >= 0 &&
        row < maxAttempts &&
        _sortableCells(row).length > 1;
  }

  bool sortRow(int row) => sortRowBy(row);

  bool sortRowBy(int row, {int Function(int value)? sortKey}) {
    if (!canSortRow(row)) {
      return false;
    }
    final key = sortKey ?? (int value) => value;
    final targetColumns = _sortableColumns(row);
    final sortedCells = _sortableCells(row)
      ..sort((left, right) {
        final leftNote = left.note!;
        final rightNote = right.note!;
        final keyComparison = key(leftNote).compareTo(key(rightNote));
        return keyComparison != 0
            ? keyComparison
            : leftNote.compareTo(rightNote);
      });

    for (var offset = 0; offset < targetColumns.length; offset += 1) {
      final column = targetColumns[offset];
      _setCell(
        row,
        column,
        offset < sortedCells.length ? sortedCells[offset] : const GuessCell(),
      );
    }
    _currentColumn = _nextOpenColumn(0);
    _message = null;
    _emitChanged();
    return true;
  }

  List<int> _sortableColumns(int row) => <int>[
    for (var column = 0; column < columns; column += 1)
      if (!cell(row, column).isCarried) column,
  ];

  List<GuessCell> _sortableCells(int row) => <GuessCell>[
    for (final column in _sortableColumns(row))
      if (cell(row, column).note != null) cell(row, column),
  ];

  bool canCarryCorrectCellFromPreviousRow(int sourceRow, int column) {
    if (_status != GameStatus.playing ||
        _currentRow <= 0 ||
        sourceRow != _currentRow - 1 ||
        column < 0 ||
        column >= columns) {
      return false;
    }
    final source = cell(sourceRow, column);
    final note = source.note;
    return note != null &&
        source.state == TileState.correct &&
        !_rowContainsNote(_currentRow, note, exceptColumn: column);
  }

  bool canDragPresentCellFromPreviousRow(int sourceRow, int column) {
    if (_status != GameStatus.playing ||
        _currentRow <= 0 ||
        sourceRow != _currentRow - 1 ||
        column < 0 ||
        column >= columns) {
      return false;
    }
    final source = cell(sourceRow, column);
    return source.state == TileState.present && source.note != null;
  }

  bool canPlacePresentCellFromPreviousRow(
    int sourceRow,
    int sourceColumn,
    int targetColumn,
  ) {
    if (targetColumn < 0 ||
        targetColumn >= columns ||
        sourceColumn == targetColumn ||
        !canDragPresentCellFromPreviousRow(sourceRow, sourceColumn)) {
      return false;
    }
    final note = cell(sourceRow, sourceColumn).note!;
    return !_rowContainsNote(_currentRow, note, exceptColumn: targetColumn);
  }

  bool carryCorrectCellFromPreviousRow(int column) {
    final sourceRow = _currentRow - 1;
    if (_status != GameStatus.playing ||
        _currentRow <= 0 ||
        column < 0 ||
        column >= columns) {
      return false;
    }
    final source = cell(sourceRow, column);
    final note = source.note;
    if (note == null || source.state != TileState.correct) {
      return false;
    }
    if (_rowContainsNote(_currentRow, note, exceptColumn: column)) {
      _message = duplicateRowNoteMessage;
      _emitChanged();
      return false;
    }
    _setCell(
      _currentRow,
      column,
      GuessCell(
        note: note,
        state: TileState.carried,
        carriedState: TileState.correct,
      ),
    );
    _currentColumn = _nextOpenColumn(_currentColumn);
    _message = null;
    _emitChanged();
    return true;
  }

  bool placePresentCellFromPreviousRow(int sourceColumn, int targetColumn) {
    final sourceRow = _currentRow - 1;
    if (targetColumn < 0 ||
        targetColumn >= columns ||
        sourceColumn == targetColumn ||
        !canDragPresentCellFromPreviousRow(sourceRow, sourceColumn)) {
      return false;
    }
    final note = cell(sourceRow, sourceColumn).note!;
    if (_rowContainsNote(_currentRow, note, exceptColumn: targetColumn)) {
      _message = duplicateRowNoteMessage;
      _emitChanged();
      return false;
    }
    _setCell(
      _currentRow,
      targetColumn,
      GuessCell(
        note: note,
        state: TileState.input,
        carriedState: TileState.present,
      ),
    );
    _currentColumn = _nextOpenColumn(_currentColumn);
    _message = null;
    _emitChanged();
    return true;
  }

  bool canCarryTile({required int row, required int column}) {
    return canCarryCorrectCellFromPreviousRow(row, column) ||
        canDragPresentCellFromPreviousRow(row, column);
  }

  bool canReceiveCarriedTile({
    required int fromRow,
    required int column,
    required int note,
    required int toRow,
    required int targetColumn,
  }) {
    if (toRow != _currentRow ||
        targetColumn < 0 ||
        targetColumn >= columns ||
        fromRow != _currentRow - 1 ||
        column < 0 ||
        column >= columns) {
      return false;
    }
    final source = cell(fromRow, column);
    if (source.note != note) {
      return false;
    }
    if (source.state == TileState.correct && column != targetColumn) {
      return false;
    }
    if (source.state == TileState.present && column == targetColumn) {
      return false;
    }
    if (source.state != TileState.correct &&
        source.state != TileState.present) {
      return false;
    }
    return !_rowContainsNote(toRow, note, exceptColumn: targetColumn);
  }

  bool carryTile({
    required int fromRow,
    required int column,
    required int note,
    required int toRow,
    required int targetColumn,
  }) {
    if (!canReceiveCarriedTile(
      fromRow: fromRow,
      column: column,
      note: note,
      toRow: toRow,
      targetColumn: targetColumn,
    )) {
      if (toRow == _currentRow &&
          targetColumn >= 0 &&
          targetColumn < columns &&
          _rowContainsNote(toRow, note, exceptColumn: targetColumn)) {
        _message = duplicateRowNoteMessage;
        _emitChanged();
      }
      return false;
    }
    final source = cell(fromRow, column);
    return source.state == TileState.correct
        ? carryCorrectCellFromPreviousRow(column)
        : placePresentCellFromPreviousRow(column, targetColumn);
  }

  bool submitGuess({String itemName = '音'}) {
    return _submitGuessWithResult(
      itemName: itemName,
      resultForGuess: (guess) => evaluateGuess(guess, _puzzle.notes),
    );
  }

  bool submitExtraGuess(int edo) {
    return _submitGuessWithResult(
      itemName: '音',
      resultForGuess: (guess) => evaluateExtraGuess(guess, _puzzle.notes, edo),
    );
  }

  bool _submitGuessWithResult({
    required String itemName,
    required List<TileState> Function(List<int> guess) resultForGuess,
  }) {
    if (_status != GameStatus.playing) {
      return false;
    }
    final guess = rowNotes(_currentRow);
    if (guess.length != columns) {
      _message = '请先确认全部 $columns 个$itemName';
      _emitChanged();
      return false;
    }
    if (guess.toSet().length != guess.length) {
      _message = duplicateRowNoteMessage;
      _emitChanged();
      return false;
    }

    final result = resultForGuess(guess);
    for (var column = 0; column < result.length; column += 1) {
      _setCell(
        _currentRow,
        column,
        GuessCell(note: guess[column], state: result[column]),
      );
    }

    if (result.every((state) => state == TileState.correct)) {
      _status = GameStatus.won;
      _message = '答对了：$answerText';
      _emitChanged();
      return true;
    }
    if (_currentRow == maxAttempts - 1) {
      _status = GameStatus.lost;
      _message = '答案是：$answerText';
      _emitChanged();
      return true;
    }

    _currentRow += 1;
    _currentColumn = 0;
    _selectedNote = null;
    _emitChanged();
    return true;
  }

  void newRandomPuzzle({
    int? noteCount,
    IntRange noteRange = defaultPlayableRange,
    math.Random? random,
  }) {
    newPuzzle(
      ChordPuzzle.random(
        noteCount: sanitizeChordToneCount(noteCount ?? columns),
        noteRange: noteRange,
        random: random,
      ),
    );
  }

  void newPuzzle(ChordPuzzle nextPuzzle) {
    _puzzle = nextPuzzle;
    _currentRow = 0;
    _currentColumn = 0;
    _selectedNote = null;
    _status = GameStatus.playing;
    _message = null;
    _rebuildCells();
    _emitChanged();
  }

  bool clearMessage() {
    if (_message == null) {
      return false;
    }
    _message = null;
    _emitChanged();
    return true;
  }

  GuessCell cell(int row, int column) {
    if (row < 0 || row >= maxAttempts || column < 0 || column >= columns) {
      return const GuessCell();
    }
    return _cells[row * columns + column];
  }

  bool rowIsFull(int row) => rowNotes(row).length == columns;

  bool cellIsJudged(int row, int column) {
    return switch (cell(row, column).state) {
      TileState.correct ||
      TileState.extraCorrect ||
      TileState.present ||
      TileState.extraNear ||
      TileState.absent => true,
      TileState.empty || TileState.input || TileState.carried => false,
    };
  }

  bool rowIsJudged(int row) {
    if (row < 0 || row >= maxAttempts || columns == 0) {
      return false;
    }
    for (var column = 0; column < columns; column += 1) {
      if (!cellIsJudged(row, column)) {
        return false;
      }
    }
    return true;
  }

  List<int> rowNotes(int row) {
    if (row < 0 || row >= maxAttempts) {
      return const <int>[];
    }
    final notes = <int>[];
    for (var column = 0; column < columns; column += 1) {
      final note = cell(row, column).note;
      if (note != null) {
        notes.add(note);
      }
    }
    return notes;
  }

  int? _previousInputColumn() {
    if (_status != GameStatus.playing) {
      return null;
    }
    for (var column = columns - 1; column >= 0; column -= 1) {
      if (cell(_currentRow, column).state == TileState.input) {
        return column;
      }
    }
    return null;
  }

  int _nextOpenColumn(int startColumn) {
    var column = startColumn.clamp(0, columns);
    while (column < columns && cell(_currentRow, column).note != null) {
      column += 1;
    }
    return column;
  }

  bool _rowContainsNote(int row, int note, {int? exceptColumn}) {
    for (var column = 0; column < columns; column += 1) {
      if (column != exceptColumn && cell(row, column).note == note) {
        return true;
      }
    }
    return false;
  }

  void _setCell(int row, int column, GuessCell value) {
    if (row < 0 || row >= maxAttempts || column < 0 || column >= columns) {
      return;
    }
    _cells[row * columns + column] = value;
  }

  void _rebuildCells() {
    _cells
      ..clear()
      ..addAll(
        List<GuessCell>.filled(
          maxAttempts * columns,
          const GuessCell(),
          growable: false,
        ),
      );
  }

  void _emitChanged() {
    _revision += 1;
    onChanged?.call(this);
  }
}

List<TileState> evaluateGuess(List<int> guess, List<int> answer) {
  final result = List<TileState>.filled(guess.length, TileState.absent);
  final remaining = <int, int>{};
  for (final note in answer) {
    remaining[note] = (remaining[note] ?? 0) + 1;
  }

  for (var index = 0; index < guess.length; index += 1) {
    final note = guess[index];
    if (index < answer.length && answer[index] == note) {
      result[index] = TileState.correct;
      remaining[note] = (remaining[note] ?? 0) - 1;
    }
  }
  for (var index = 0; index < guess.length; index += 1) {
    if (result[index] == TileState.correct) {
      continue;
    }
    final note = guess[index];
    final count = remaining[note] ?? 0;
    if (count > 0) {
      result[index] = TileState.present;
      remaining[note] = count - 1;
    }
  }
  return result;
}

List<TileState> evaluateExtraGuess(List<int> guess, List<int> answer, int edo) {
  final normalizedEdo = sanitizeExtraEdo(edo);
  return <TileState>[
    for (var index = 0; index < guess.length; index += 1)
      _evaluateExtraValue(
        guess[index],
        index < answer.length ? answer[index] : null,
        answer,
        normalizedEdo,
      ),
  ];
}

TileState _evaluateExtraValue(
  int note,
  int? answerAtPosition,
  List<int> answer,
  int edo,
) {
  if (answerAtPosition == note) {
    return TileState.correct;
  }
  if (answer.contains(note)) {
    return TileState.present;
  }
  if (answerAtPosition != null &&
      extraStepCentsDistance(note, answerAtPosition, edo) <=
          extraPitchToleranceCents) {
    return TileState.extraCorrect;
  }
  if (answer.any(
    (answerNote) =>
        extraStepCentsDistance(note, answerNote, edo) <=
        extraPitchToleranceCents,
  )) {
    return TileState.extraNear;
  }
  return TileState.absent;
}

double extraStepCentsDistance(int firstStep, int secondStep, int edo) {
  return (firstStep - secondStep).abs() * 1200.0 / sanitizeExtraEdo(edo);
}

String noteLabel(int midiNote) {
  final pitch = _pitchNames[midiNote.floorMod(12)];
  final octave = midiNote ~/ 12 - 1;
  return '$pitch$octave';
}

bool isWhiteMidiKey(int midiNote) => !isBlackKey(midiNote);

bool isBlackKey(int midiNote) {
  return switch (midiNote.floorMod(12)) {
    1 || 3 || 6 || 8 || 10 => true,
    _ => false,
  };
}

String rangeLabel(IntRange range) {
  final sanitized = sanitizePlayableRange(range);
  return '${noteLabel(sanitized.lowerBound)}-'
      '${noteLabel(sanitized.upperBound)}';
}

IntRange sanitizePlayableRange(IntRange range) {
  var low = _nextWhiteKeyAtOrAbove(
    range.lowerBound.clamp(
      lowestPlayableMidiNote,
      highestPlayableMidiNote - minimumPlayableRangeSemitones,
    ),
  );
  var high = _previousWhiteKeyAtOrBelow(
    range.upperBound.clamp(
      lowestPlayableMidiNote + minimumPlayableRangeSemitones,
      highestPlayableMidiNote,
    ),
  );
  if (high - low < minimumPlayableRangeSemitones) {
    high = math.min(
      _nextWhiteKeyAtOrAbove(low + minimumPlayableRangeSemitones),
      highestPlayableMidiNote,
    );
    low = math.max(
      _previousWhiteKeyAtOrBelow(high - minimumPlayableRangeSemitones),
      lowestPlayableMidiNote,
    );
  }
  return IntRange(low, high);
}

IntRange sanitizeNormalPlayableRange(IntRange range) {
  return sanitizePlayableRange(range);
}

List<int> normalPlayableRangeEndpointValues() => playableWhiteKeyMidiNotes;

int sanitizeChordToneCount(int noteCount) {
  return noteCount.clamp(minChordToneCount, maxChordToneCount);
}

int sanitizeExtraEdo(int edo) => edo.clamp(minExtraEdo, maxExtraEdo);

IntRange sanitizeExtraPlayableRange(IntRange range) {
  final playableRange = sanitizePlayableRange(range);
  var low = _nextCAtOrAbove(playableRange.lowerBound).clamp(
    lowestExtraPlayableMidiNote,
    highestExtraPlayableMidiNote - minimumPlayableRangeSemitones,
  );
  var high = _previousCAtOrBelow(playableRange.upperBound).clamp(
    lowestExtraPlayableMidiNote + minimumPlayableRangeSemitones,
    highestExtraPlayableMidiNote,
  );
  if (high - low < minimumPlayableRangeSemitones) {
    high = math.min(
      low + minimumPlayableRangeSemitones,
      highestExtraPlayableMidiNote,
    );
    low = math.max(
      high - minimumPlayableRangeSemitones,
      lowestExtraPlayableMidiNote,
    );
  }
  return IntRange(low, high);
}

int cMidiNoteForOctave(int octave) {
  return ((octave + 1) * 12).clamp(
    lowestExtraPlayableMidiNote,
    highestExtraPlayableMidiNote,
  );
}

int octaveForCMidiNote(int midiNote) => midiNote ~/ 12 - 1;

int sanitizeMidiProgramNumber(int program) {
  return program.clamp(minMidiProgramNumber, maxMidiProgramNumber);
}

IntRange sanitizeOvertoneRange(IntRange range) {
  var low = range.lowerBound.clamp(
    minOvertoneMultiplier,
    maxOvertoneMultiplier ~/ 2,
  );
  var high = range.upperBound.clamp(
    minOvertoneMultiplier,
    maxOvertoneMultiplier,
  );
  final requiredHigh = math.max(low * 2, low + minOvertoneToneCount);
  if (high < requiredHigh) {
    high = requiredHigh;
  }
  if (high > maxOvertoneMultiplier) {
    high = maxOvertoneMultiplier;
    low = math.max(
      minOvertoneMultiplier,
      math.min(low, math.min(high ~/ 2, high - minOvertoneToneCount)),
    );
  }
  return IntRange(low, high);
}

int maxOvertoneToneCount(IntRange multiplierRange) {
  final sanitized = sanitizeOvertoneRange(multiplierRange);
  return math.max(
    minOvertoneToneCount,
    math.min(
      maxOvertoneToneCountLimit,
      sanitized.upperBound - sanitized.lowerBound,
    ),
  );
}

int sanitizeOvertoneToneCount(int noteCount, IntRange multiplierRange) {
  return noteCount.clamp(
    minOvertoneToneCount,
    maxOvertoneToneCount(multiplierRange),
  );
}

double midiNoteFrequency(int midiNote) {
  return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
}

IntRange extraStepRangeForMidiRange(int edo, IntRange noteRange) {
  final playableRange = sanitizeExtraPlayableRange(noteRange);
  return edoStepRangeForMidiRange(edo, playableRange);
}

IntRange edoStepRangeForMidiRange(int edo, IntRange noteRange) {
  final normalizedEdo = sanitizeExtraEdo(edo);
  final playableRange = IntRange.sorted(
    noteRange.lowerBound.clamp(lowestPlayableMidiNote, highestPlayableMidiNote),
    noteRange.upperBound.clamp(lowestPlayableMidiNote, highestPlayableMidiNote),
  );
  final low = (playableRange.lowerBound * normalizedEdo / 12.0 - 0.000001)
      .ceil();
  final high = (playableRange.upperBound * normalizedEdo / 12.0 + 0.000001)
      .floor();
  return high >= low ? IntRange(low, high) : IntRange(low, low);
}

double midiValueForExtraStep(int step, int edo) {
  return step * 12.0 / sanitizeExtraEdo(edo);
}

String extraStepLabel(int step, int edo) {
  final normalizedEdo = sanitizeExtraEdo(edo);
  final octave = step.floorDiv(normalizedEdo) - 1;
  final octaveStep = step.floorMod(normalizedEdo);
  final pitch = _extraPitchName(octaveStep, normalizedEdo);
  return pitch == null
      ? _legacyExtraStepLabel(octave, octaveStep)
      : '${pitch.name}${octave + pitch.octaveOffset}';
}

String extraStepTileLabel(int step, int edo) {
  final normalizedEdo = sanitizeExtraEdo(edo);
  final octave = step.floorDiv(normalizedEdo) - 1;
  final octaveStep = step.floorMod(normalizedEdo);
  final pitch = _extraPitchName(octaveStep, normalizedEdo);
  return pitch == null
      ? _legacyExtraStepTileLabel(octave, octaveStep, normalizedEdo)
      : '${pitch.name}${octave + pitch.octaveOffset}';
}

String extraRangeLabel(int edo, IntRange noteRange) {
  final stepRange = extraStepRangeForMidiRange(edo, noteRange);
  final normalizedEdo = sanitizeExtraEdo(edo);
  return '${extraStepLabel(stepRange.lowerBound, normalizedEdo)}-'
      '${extraStepLabel(stepRange.upperBound, normalizedEdo)}';
}

int randomOvertoneBaseMidiNote(
  IntRange multiplierRange, {
  math.Random? random,
}) {
  final candidates = overtoneBaseCandidates(multiplierRange);
  if (candidates.isEmpty) {
    return lowestPlayableMidiNote;
  }
  var totalWeight = 0;
  for (var index = 0; index < candidates.length; index += 1) {
    totalWeight += overtoneBaseCandidateWeight(index, candidates.length);
  }
  var ticket = (random ?? math.Random()).nextInt(totalWeight);
  for (var index = 0; index < candidates.length; index += 1) {
    ticket -= overtoneBaseCandidateWeight(index, candidates.length);
    if (ticket < 0) {
      return candidates[index];
    }
  }
  return candidates.first;
}

List<int> overtoneBaseCandidates(IntRange multiplierRange) {
  final sanitized = sanitizeOvertoneRange(multiplierRange);
  final highestFrequency = midiNoteFrequency(highestPlayableMidiNote);
  return <int>[
    for (final midiNote in fullPianoRange.values)
      if (midiNoteFrequency(midiNote) * sanitized.upperBound <=
          highestFrequency + 0.000001)
        midiNote,
  ];
}

int overtoneBaseCandidateWeight(int index, int candidateCount) {
  final lowBias = math.max(candidateCount - index, 1);
  return lowBias * lowBias;
}

int? randomEdoBaseStep(
  Iterable<int> relativeSteps,
  IntRange playableRange, {
  int? excludingStep,
  math.Random? random,
}) {
  final offsets = relativeSteps.toList(growable: false);
  if (offsets.isEmpty) return null;
  final minimumOffset = math.min(0, offsets.reduce(math.min));
  final maximumOffset = math.max(0, offsets.reduce(math.max));
  final first = playableRange.lowerBound - minimumOffset;
  final last = playableRange.upperBound - maximumOffset;
  if (last < first) return null;

  final allCandidates = <int>[
    for (var step = first; step <= last; step += 1) step,
  ];
  final candidates = excludingStep != null && allCandidates.length > 1
      ? allCandidates.where((step) => step != excludingStep).toList()
      : allCandidates;

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

final class _ExtraPitchName {
  const _ExtraPitchName(this.name, this.octaveOffset);

  final String name;
  final int octaveOffset;
}

final Map<int, List<_ExtraPitchName?>> _extraPitchNameTableCache =
    <int, List<_ExtraPitchName?>>{};

String _legacyExtraStepLabel(int octave, int octaveStep) {
  return octaveStep == 0 ? 'C$octave' : 'C$octave+$octaveStep';
}

String _legacyExtraStepTileLabel(int octave, int octaveStep, int edo) {
  return octaveStep == 0 ? 'C$octave' : 'C$octave\n+$octaveStep\\$edo';
}

_ExtraPitchName? _extraPitchName(int octaveStep, int edo) {
  final table = _extraPitchNameTable(edo);
  return octaveStep >= 0 && octaveStep < table.length
      ? table[octaveStep]
      : null;
}

List<_ExtraPitchName?> _extraPitchNameTable(int edo) {
  return _extraPitchNameTableCache.putIfAbsent(edo, () {
    final simple = _simpleExtraPitchNameTables[edo];
    if (simple != null) {
      return List<_ExtraPitchName?>.unmodifiable(
        simple.map((name) => _ExtraPitchName(name, 0)),
      );
    }
    return List<_ExtraPitchName?>.unmodifiable(
      List<_ExtraPitchName?>.generate(
        edo,
        (step) => _toExtraPitchName(_potdNumericName(step, edo)),
      ),
    );
  });
}

_ExtraPitchName? _toExtraPitchName(String? numericName) {
  if (numericName == null || numericName.isEmpty) {
    return null;
  }
  var octaveOffset = 0;
  var index = 0;
  while (index < numericName.length) {
    final marker = numericName[index];
    if (marker == "'") {
      octaveOffset += 1;
    } else if (marker == '`') {
      octaveOffset -= 1;
    } else {
      break;
    }
    index += 1;
  }
  final body = numericName.substring(index);
  if (body.isEmpty) {
    return null;
  }
  final degree = body.substring(body.length - 1);
  final pitch = _extraPitchNames[degree];
  if (pitch == null) {
    return null;
  }
  final accidental = body.substring(0, body.length - 1);
  return _ExtraPitchName('$accidental$pitch', octaveOffset);
}

String? _potdNumericName(int step, int edo) {
  if (edo <= 0) {
    return null;
  }
  final oc = edo;
  final tr = _roundHalfToEven(edo * _log2(3));
  final hp = _roundHalfToEven(edo * _log2(7));
  final ded = 2 * tr - 3 * oc;
  final xed = 8 * oc - 5 * tr;
  final zid = 7 * tr - 11 * oc;
  final maxStep = math.max(ded, xed);

  late final int mav;
  late final Map<String, int> neu;
  late final Map<String, int> neuj;
  late final Map<String, int> fls;
  if (xed > 0) {
    mav = math.max(3 * oc - hp - xed, maxStep.floorDiv(2));
    neu = <String, int>{
      '1': 0,
      '2': ded,
      '3': 2 * ded,
      '4': 2 * ded + xed,
      '5': 3 * ded + xed,
      '6': edo - ded - xed,
      '7': edo - xed,
    };
    neuj = <String, int>{
      '1': ded,
      '2': ded,
      '3': xed,
      '4': ded,
      '5': ded,
      '6': ded,
      '7': xed,
    };
    fls = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0, '6': 0, '7': 1};
  } else {
    mav = math.max(3 * oc - hp - (xed + ded), maxStep.floorDiv(2));
    neu = <String, int>{
      '1': 0,
      '2': ded,
      '3': 2 * ded,
      '5': 3 * ded + xed,
      '6': edo - ded - xed,
    };
    neuj = <String, int>{
      '1': ded,
      '2': ded,
      '3': xed + ded,
      '5': ded,
      '6': ded + xed,
    };
    fls = <String, int>{'1': 0, '2': 0, '3': 0, '5': 0, '6': 1};
  }

  var namePrefix = '';
  String? degree;
  var cha = edo;
  String? record;
  for (final entry in neu.entries) {
    if (entry.value == step) {
      degree = entry.key;
      cha = 0;
      break;
    }
    final distance = step - entry.value;
    if (distance >= 1 && distance < cha) {
      record = entry.key;
      cha = distance;
    }
  }

  if (degree == null) {
    if (record == null) {
      return null;
    }
    final zcha = neuj[record];
    if (zcha == null) {
      return null;
    }
    final ycha = zcha - cha;
    final condition = zcha == maxStep
        ? ycha <= mav
        : ycha <= mav + (zcha - maxStep).floorDiv(2);
    if (condition) {
      cha = -ycha;
      if (fls[record] == 1) {
        degree = '1';
        namePrefix = "'";
      } else {
        degree = _nextExtraDegree(record, neuj);
      }
    } else {
      degree = record;
    }
  }

  final accidental = _potdAccidental(cha, zid, xed);
  return accidental == null ? null : '$namePrefix$accidental$degree';
}

String _nextExtraDegree(String degree, Map<String, int> neuj) {
  final next = int.parse(degree) + 1;
  return neuj.containsKey('$next') ? '$next' : '${next + 1}';
}

String? _potdAccidental(int cha, int zid, int xed) {
  if (xed <= 0) {
    return cha >= 0 ? _repeat('^', cha) : _repeat('v', -cha);
  }
  if (zid == 0) {
    return null;
  }
  if (zid.floorMod(2) == 1) {
    final zzha = _roundRatioHalfToEven(cha, zid);
    final yzha = cha - zzha * zid;
    return '${_extraUpDown(yzha)}${_extraSharpFlat(zzha)}';
  }
  final zzha = _roundRatioHalfToEven(2 * cha, zid);
  final yzha = cha - zzha * (zid ~/ 2);
  return '${_extraUpDown(yzha)}${_extraHalfSharpFlat(zzha)}';
}

String _extraSharpFlat(int amount) {
  if (amount <= 0) {
    return _repeat('b', -amount);
  }
  return '${_repeat('#', amount.floorMod(2))}${_repeat('x', amount ~/ 2)}';
}

String _extraHalfSharpFlat(int twiceAmount) {
  if (twiceAmount <= 0) {
    final amount = -twiceAmount;
    return '${_repeat('d', amount.floorMod(2))}'
        '${_repeat('b', amount ~/ 2)}';
  }
  return '${_repeat('#', twiceAmount.floorMod(4) >= 2 ? 1 : 0)}'
      '${_repeat('+', twiceAmount.floorMod(2))}'
      '${_repeat('x', twiceAmount ~/ 4)}';
}

String _extraUpDown(int amount) {
  return amount <= 0 ? _repeat('v', -amount) : _repeat('^', amount);
}

int _roundRatioHalfToEven(int numerator, int denominator) {
  var n = numerator;
  var d = denominator;
  if (d < 0) {
    n = -n;
    d = -d;
  }
  final floorValue = n.floorDiv(d);
  final remainder = n - floorValue * d;
  final twice = remainder * 2;
  if (twice < d) {
    return floorValue;
  }
  if (twice > d) {
    return floorValue + 1;
  }
  return floorValue.floorMod(2) == 0 ? floorValue : floorValue + 1;
}

int _roundHalfToEven(double value) {
  final floorValue = value.floor();
  final remainder = value - floorValue;
  if (remainder < 0.5) {
    return floorValue;
  }
  if (remainder > 0.5) {
    return floorValue + 1;
  }
  return floorValue.floorMod(2) == 0 ? floorValue : floorValue + 1;
}

double _log2(num value) => math.log(value) / math.ln2;

int _nextCAtOrAbove(int midiNote) {
  return midiNote + (12 - midiNote.floorMod(12)).floorMod(12);
}

int _previousCAtOrBelow(int midiNote) {
  return midiNote - midiNote.floorMod(12);
}

int _nextWhiteKeyAtOrAbove(int midiNote) {
  var note = midiNote;
  while (!isWhiteMidiKey(note)) {
    note += 1;
  }
  return note;
}

int _previousWhiteKeyAtOrBelow(int midiNote) {
  var note = midiNote;
  while (!isWhiteMidiKey(note)) {
    note -= 1;
  }
  return note;
}

List<int> _randomSortedValues(
  IntRange range,
  int requestedCount,
  math.Random random,
) {
  final values = range.values.toList()..shuffle(random);
  final count = math.min(requestedCount, values.length);
  final result = values.take(count).toList()..sort();
  return result;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _repeat(String value, int count) {
  return count <= 0 ? '' : List<String>.filled(count, value).join();
}

extension _IntMath on int {
  int floorMod(int divisor) {
    final remainder = this % divisor;
    return remainder < 0 ? remainder + divisor.abs() : remainder;
  }

  int floorDiv(int divisor) {
    final remainder = floorMod(divisor);
    return (this - remainder) ~/ divisor;
  }
}

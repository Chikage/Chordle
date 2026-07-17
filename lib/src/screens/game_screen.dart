import 'dart:async';

import 'package:flutter/material.dart';

import '../game/chord_game.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/chord_board.dart';
import '../widgets/game_chrome.dart';
import '../widgets/game_input_panel.dart';
import '../widgets/help_dialog.dart';
import '../widgets/microtonal_keyboard.dart';
import '../widgets/overtone_number_pad.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/settings_dialogs.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.mode, super.key});

  final ChordleMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AudioService _audio = AudioService.instance;
  final SettingsService _settingsService = SettingsService.instance;

  ChordleSettings _settings = const ChordleSettings();
  late ChordleGame _game;
  Timer? _messageTimer;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _game = _makeGame(_settings);
    _game.onChanged = _handleGameChanged;
    _audio.addListener(_handleAudioChanged);
    unawaited(_loadSettingsAndAudio());
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _game.onChanged = null;
    _audio.removeListener(_handleAudioChanged);
    unawaited(_audio.allSoundOff());
    super.dispose();
  }

  Future<void> _loadSettingsAndAudio() async {
    final loaded = await _settingsService.load();
    if (!mounted) return;
    final replacement = _makeGame(loaded)..onChanged = _handleGameChanged;
    setState(() {
      _settings = loaded;
      _game.onChanged = null;
      _game = replacement;
      _settingsLoaded = true;
    });
    await _audio.prepare(_settings.instrumentProgram);
  }

  ChordleGame _makeGame(ChordleSettings settings) {
    return ChordleGame(initialPuzzle: _newPuzzleFor(settings));
  }

  ChordPuzzle _newPuzzleFor(ChordleSettings settings) {
    return switch (widget.mode) {
      ChordleMode.normal => ChordPuzzle.random(
        noteCount: sanitizeChordToneCount(settings.normalToneCount),
        noteRange: sanitizePlayableRange(
          IntRange.sorted(settings.normalLow, settings.normalHigh),
        ),
      ),
      ChordleMode.extra => ChordPuzzle.randomExtra(
        noteCount: sanitizeChordToneCount(settings.extraToneCount),
        noteRange: sanitizeExtraPlayableRange(
          IntRange.sorted(settings.extraLow, settings.extraHigh),
        ),
        edo: sanitizeExtraEdo(settings.extraEdo),
      ),
      ChordleMode.overtones => ChordPuzzle.randomOvertones(
        toneCount: sanitizeOvertoneToneCount(
          settings.overtoneToneCount,
          _overtoneRange(settings),
        ),
        multiplierRange: _overtoneRange(settings),
      ),
    };
  }

  void _handleGameChanged(ChordleGame game) {
    if (!mounted) return;
    _messageTimer?.cancel();
    if (game.message != null) {
      _messageTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) game.clearMessage();
      });
    }
    setState(() {});
  }

  void _handleAudioChanged() {
    if (mounted) setState(() {});
  }

  IntRange get _normalRange => sanitizePlayableRange(
    IntRange.sorted(_settings.normalLow, _settings.normalHigh),
  );

  IntRange get _extraRange => sanitizeExtraPlayableRange(
    IntRange.sorted(_settings.extraLow, _settings.extraHigh),
  );

  IntRange _overtoneRange(ChordleSettings settings) => sanitizeOvertoneRange(
    IntRange.sorted(settings.overtoneLow, settings.overtoneHigh),
  );

  IntRange get _currentOvertoneRange => _overtoneRange(_settings);

  int get _extraEdo => sanitizeExtraEdo(_settings.extraEdo);

  bool get _audioReady => _audio.status == AudioStatus.ready;

  String get _detailText => switch (widget.mode) {
    ChordleMode.normal => '${_game.columns} 音 · ${rangeLabel(_normalRange)}',
    ChordleMode.extra =>
      '${_game.columns} 音 · ${_extraEdo}EDO · ${extraRangeLabel(_extraEdo, _extraRange)}',
    ChordleMode.overtones =>
      '${_game.columns} 音 · ${_currentOvertoneRange.lowerBound}–${_currentOvertoneRange.upperBound}x',
  };

  AudioIndicatorState get _audioIndicator => switch (_audio.status) {
    AudioStatus.loading => AudioIndicatorState.loading,
    AudioStatus.ready => AudioIndicatorState.ready,
    AudioStatus.error => AudioIndicatorState.error,
  };

  Future<void> _playValues(
    List<int> values, {
    int velocity = 104,
    int durationMs = 1200,
  }) {
    return _audio.playValues(
      widget.mode,
      _game.puzzle,
      values,
      _extraEdo,
      velocity: velocity,
      durationMs: durationMs,
      program: _settings.instrumentProgram,
    );
  }

  Future<void> _playTarget({int durationMs = 1600}) {
    return _playValues(_game.puzzle.notes, durationMs: durationMs);
  }

  void _selectValue(int value) {
    _game.selectNote(value);
    if (_settings.keyPitchPreviewEnabled && _audioReady) {
      unawaited(_playValues(<int>[value], velocity: 92, durationMs: 520));
    }
  }

  void _confirmValue() {
    final message = switch (widget.mode) {
      ChordleMode.normal => '先在钢琴上选择一个音',
      ChordleMode.extra => '先在 EDO 标尺上选择一个音',
      ChordleMode.overtones => '先在数字键盘上选择一个数字',
    };
    _game.confirmSelectedValue(missingSelectionMessage: message);
  }

  void _submit() {
    if (widget.mode == ChordleMode.extra) {
      _game.submitExtraGuess(_extraEdo);
    } else {
      _game.submitGuess(
        itemName: widget.mode == ChordleMode.overtones ? '数字' : '音',
      );
    }
  }

  Future<void> _restart() async {
    await _audio.allSoundOff();
    if (!mounted) return;
    _game.newPuzzle(_newPuzzleFor(_settings));
    if (_audioReady) await _playTarget(durationMs: 1400);
  }

  Future<void> _openSettings() async {
    final Future<ChordleSettings?> dialogFuture;
    switch (widget.mode) {
      case ChordleMode.normal:
        dialogFuture = showNormalSettingsDialog(context, _settings);
      case ChordleMode.extra:
        dialogFuture = showExtraSettingsDialog(context, _settings);
      case ChordleMode.overtones:
        dialogFuture = showOvertoneSettingsDialog(context, _settings);
    }
    final next = await dialogFuture;
    if (next == null || !mounted) return;

    final puzzleChanged = switch (widget.mode) {
      ChordleMode.normal =>
        next.normalLow != _settings.normalLow ||
            next.normalHigh != _settings.normalHigh ||
            next.normalToneCount != _settings.normalToneCount,
      ChordleMode.extra =>
        next.extraLow != _settings.extraLow ||
            next.extraHigh != _settings.extraHigh ||
            next.extraToneCount != _settings.extraToneCount ||
            next.extraEdo != _settings.extraEdo,
      ChordleMode.overtones =>
        next.overtoneLow != _settings.overtoneLow ||
            next.overtoneHigh != _settings.overtoneHigh ||
            next.overtoneToneCount != _settings.overtoneToneCount,
    };
    setState(() => _settings = next);
    await _settingsService.save(next);
    if (!mounted) return;
    if (puzzleChanged) _game.newPuzzle(_newPuzzleFor(next));
    await _audio.prepare(next.instrumentProgram);
    if (_audioReady) await _playTarget(durationMs: 1400);
  }

  Future<void> _leave() async {
    await _audio.allSoundOff();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final valueColors = _guessedValueColors();
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_audio.allSoundOff());
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Stack(
                children: [
                  Column(
                    children: [
                      ChordleHeader(
                        modeLabel: switch (widget.mode) {
                          ChordleMode.normal => 'Normal',
                          ChordleMode.extra => 'Extra',
                          ChordleMode.overtones => 'Overtones',
                        },
                        onBack: () => unawaited(_leave()),
                        onHelp: () => unawaited(
                          showChordleHelpDialog(context, widget.mode),
                        ),
                        onSettings: () => unawaited(_openSettings()),
                      ),
                      GameStatusBar(
                        detailText: _detailText,
                        attempt: _game.currentRow + 1,
                        maxAttempts: _game.maxAttempts,
                        audioState: _audioIndicator,
                        audioMessage: _audio.errorMessage,
                        onNewPuzzle: () => unawaited(_restart()),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide =
                                constraints.maxWidth >= 760 &&
                                constraints.maxWidth >
                                    constraints.maxHeight * 1.2;
                            return wide
                                ? _buildLandscapeBody(valueColors)
                                : _buildPortraitBody(valueColors);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_game.message case final message?)
                    Positioned(
                      top: 64,
                      left: 18,
                      right: 18,
                      child: IgnorePointer(
                        child: Center(
                          child: Material(
                            color: const Color(0xFF2E2E31),
                            elevation: 8,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody(Map<int, Color> valueColors) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildBoard(),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildInput(valueColors, compact: false),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeBody(Map<int, Color> valueColors) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildBoard(),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 9,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildInput(valueColors, compact: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard() {
    final requireJudgedPlayback = !_settings.keyPitchPreviewEnabled;
    return ChordBoard(
      rows: _game.maxAttempts,
      columns: _game.columns,
      currentRow: _game.currentRow,
      currentColumn: _game.currentColumn,
      isPlaying: _game.status == GameStatus.playing,
      cellAt: (row, column) {
        final cell = _game.cell(row, column);
        BoardDragKind? dragKind;
        if (_game.canCarryCorrectCellFromPreviousRow(row, column)) {
          dragKind = BoardDragKind.correct;
        } else if (_game.canDragPresentCellFromPreviousRow(row, column)) {
          dragKind = BoardDragKind.present;
        }
        return BoardCellViewData(
          value: cell.note,
          label: cell.note == null ? '' : _valueLabel(cell.note!),
          kind: _boardKind(cell),
          dragKind: dragKind,
        );
      },
      canSortRow: _game.canSortRow,
      onSortRow: _game.sortRow,
      canPlayRow: (row) =>
          _audioReady &&
          _game.rowNotes(row).isNotEmpty &&
          (!requireJudgedPlayback || _game.rowIsJudged(row)),
      onPlayRow: (row) =>
          unawaited(_playValues(_game.rowNotes(row), durationMs: 1200)),
      canPlayCell: (row, column) =>
          _audioReady &&
          _game.cell(row, column).note != null &&
          (!requireJudgedPlayback || _game.cellIsJudged(row, column)),
      onPlayCell: (row, column, value) =>
          unawaited(_playValues(<int>[value], velocity: 92, durationMs: 520)),
      canAcceptDrag: (sourceColumn, value, targetColumn) =>
          _game.canReceiveCarriedTile(
            fromRow: _game.currentRow - 1,
            column: sourceColumn,
            note: value,
            toRow: _game.currentRow,
            targetColumn: targetColumn,
          ),
      onCarryCorrect: _game.carryCorrectCellFromPreviousRow,
      onMovePresent: _game.placePresentCellFromPreviousRow,
    );
  }

  Widget _buildInput(Map<int, Color> valueColors, {required bool compact}) {
    final selected = _game.selectedNote;
    final answer = _game.status == GameStatus.playing
        ? null
        : _game.status == GameStatus.won
        ? '已完成：${_game.answerText}'
        : '答案：${_game.answerText}';
    final selectedText = selected == null
        ? switch (widget.mode) {
            ChordleMode.normal => '未选音',
            ChordleMode.extra => '未选 EDO 音',
            ChordleMode.overtones => '未选数字',
          }
        : '选中 ${_valueSelectionLabel(selected)}';
    final input = switch (widget.mode) {
      ChordleMode.normal => PianoKeyboard(
        lowNote: _normalRange.lowerBound,
        highNote: _normalRange.upperBound,
        selectedNote: selected,
        valueColors: valueColors,
        onNotePressed: _selectValue,
        compact: compact,
      ),
      ChordleMode.extra => MicrotonalKeyboard(
        edo: _extraEdo,
        lowMidi: _extraRange.lowerBound,
        highMidi: _extraRange.upperBound,
        selectedStep: selected,
        valueColors: valueColors,
        onStepPressed: _selectValue,
        compact: compact,
      ),
      ChordleMode.overtones => OvertoneNumberPad(
        low: _currentOvertoneRange.lowerBound,
        high: _currentOvertoneRange.upperBound,
        selected: selected,
        valueColors: valueColors,
        onPressed: _selectValue,
        compact: compact,
      ),
    };

    return GameInputPanel(
      selectedText: selectedText,
      confirmText: widget.mode == ChordleMode.overtones ? '确认数字' : '确认此音',
      canConfirm: _game.status == GameStatus.playing,
      canDelete: _game.canDeleteLast(),
      canSubmit:
          _game.status == GameStatus.playing &&
          _game.rowIsFull(_game.currentRow),
      audioReady: _audioReady,
      onPlayTarget: () => unawaited(_playTarget()),
      onConfirm: _confirmValue,
      onDelete: _game.deleteLast,
      onSubmit: _submit,
      answerText: answer,
      compact: compact,
      input: input,
    );
  }

  String _valueLabel(int value) => switch (widget.mode) {
    ChordleMode.normal => noteLabel(value),
    ChordleMode.extra => extraStepTileLabel(value, _extraEdo),
    ChordleMode.overtones => '$value',
  };

  String _valueSelectionLabel(int value) => switch (widget.mode) {
    ChordleMode.normal => noteLabel(value),
    ChordleMode.extra => extraStepLabel(value, _extraEdo),
    ChordleMode.overtones => '${value}x',
  };

  Map<int, Color> _guessedValueColors() {
    final states = <int, TileState>{};
    for (var row = 0; row < _game.maxAttempts; row++) {
      for (var column = 0; column < _game.columns; column++) {
        final cell = _game.cell(row, column);
        final value = cell.note;
        if (value == null) continue;
        final candidate = cell.state;
        final previous = states[value];
        if (_statePriority(candidate) > _statePriority(previous)) {
          states[value] = candidate;
        }
      }
    }
    final colors = <int, Color>{};
    for (final entry in states.entries) {
      final color = _stateColor(entry.value);
      if (color != null) colors[entry.key] = color;
    }
    return colors;
  }

  int _statePriority(TileState? state) => switch (state) {
    TileState.correct || TileState.carried => 4,
    TileState.present => 3,
    TileState.extraCorrect => 2,
    TileState.extraNear => 1,
    _ => 0,
  };

  Color? _stateColor(TileState state) => switch (state) {
    TileState.correct || TileState.carried => ChordleColors.green,
    TileState.present => ChordleColors.yellow,
    TileState.extraCorrect => ChordleColors.extraCorrect,
    TileState.extraNear => ChordleColors.extraNear,
    _ => null,
  };

  BoardTileKind _boardKind(GuessCell cell) {
    if (cell.carriedState == TileState.correct) {
      return BoardTileKind.carried;
    }
    if (cell.carriedState == TileState.present) {
      return BoardTileKind.present;
    }
    return switch (cell.state) {
      TileState.empty => BoardTileKind.empty,
      TileState.input => BoardTileKind.input,
      TileState.carried => BoardTileKind.carried,
      TileState.correct => BoardTileKind.correct,
      TileState.extraCorrect => BoardTileKind.extraCorrect,
      TileState.present => BoardTileKind.present,
      TileState.extraNear => BoardTileKind.extraNear,
      TileState.absent => BoardTileKind.absent,
    };
  }
}

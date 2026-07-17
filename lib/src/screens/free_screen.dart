import 'dart:async';

import 'package:flutter/material.dart';

import '../game/chord_game.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/game_chrome.dart';
import '../widgets/game_input_panel.dart';
import '../widgets/microtonal_keyboard.dart';
import '../widgets/settings_dialogs.dart';

class FreeScreen extends StatefulWidget {
  const FreeScreen({super.key});

  @override
  State<FreeScreen> createState() => _FreeScreenState();
}

class _FreeScreenState extends State<FreeScreen> {
  final AudioService _audio = AudioService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  final ChordPuzzle _playbackContext = ChordPuzzle(
    notes: const <int>[],
    label: 'Free',
  );

  ChordleSettings _settings = const ChordleSettings();
  final List<int> _chord = <int>[];
  int? _selectedStep;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_handleAudioChanged);
    unawaited(_loadSettingsAndAudio());
  }

  @override
  void dispose() {
    _audio.removeListener(_handleAudioChanged);
    unawaited(_audio.allSoundOff());
    super.dispose();
  }

  Future<void> _loadSettingsAndAudio() async {
    final loaded = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _settingsLoaded = true;
    });
    await _audio.prepare(loaded.instrumentProgram);
  }

  void _handleAudioChanged() {
    if (mounted) setState(() {});
  }

  IntRange get _range => sanitizeExtraPlayableRange(
    IntRange.sorted(_settings.extraLow, _settings.extraHigh),
  );

  int get _edo => sanitizeExtraEdo(_settings.extraEdo);

  bool get _audioReady => _audio.status == AudioStatus.ready;

  Future<void> _playSteps(
    List<int> steps, {
    int velocity = 104,
    int durationMs = 1400,
  }) {
    return _audio.playValues(
      ChordleMode.extra,
      _playbackContext,
      steps,
      _edo,
      velocity: velocity,
      durationMs: durationMs,
      program: _settings.instrumentProgram,
    );
  }

  void _selectStep(int step) {
    setState(() => _selectedStep = step);
    if (_settings.keyPitchPreviewEnabled && _audioReady) {
      unawaited(_playSteps(<int>[step], velocity: 92, durationMs: 520));
    }
  }

  void _addSelectedStep() {
    final step = _selectedStep;
    if (step == null) return;
    if (_chord.contains(step)) {
      _showMessage('和弦中已有 ${extraStepLabel(step, _edo)}');
      return;
    }
    setState(() {
      _chord.add(step);
      _selectedStep = null;
    });
  }

  void _deleteLastStep() {
    if (_chord.isEmpty) return;
    setState(() => _chord.removeLast());
  }

  void _removeStep(int step) {
    setState(() => _chord.remove(step));
  }

  void _clearChord() {
    if (_chord.isEmpty) return;
    setState(() {
      _chord.clear();
      _selectedStep = null;
    });
    unawaited(_audio.allSoundOff());
  }

  Future<void> _openSettings() async {
    final previousEdo = _edo;
    final next = await showExtraSettingsDialog(
      context,
      _settings,
      freeMode: true,
    );
    if (next == null || !mounted) return;

    final nextEdo = sanitizeExtraEdo(next.extraEdo);
    final nextRange = sanitizeExtraPlayableRange(
      IntRange.sorted(next.extraLow, next.extraHigh),
    );
    final nextStepRange = extraStepRangeForMidiRange(nextEdo, nextRange);
    final clearedForEdoChange = previousEdo != nextEdo && _chord.isNotEmpty;
    final previousLength = _chord.length;

    setState(() {
      _settings = next;
      _selectedStep = null;
      if (previousEdo != nextEdo) {
        _chord.clear();
      } else {
        _chord.removeWhere((step) => !nextStepRange.contains(step));
      }
    });
    await _settingsService.save(next);
    if (!mounted) return;
    await _audio.prepare(next.instrumentProgram);
    if (!mounted) return;

    if (clearedForEdoChange) {
      _showMessage('EDO 已更改，当前和弦已清空');
    } else if (_chord.length < previousLength) {
      _showMessage('已移除新音域之外的音');
    }
  }

  Future<void> _leave() async {
    await _audio.allSoundOff();
    if (mounted) Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHelp() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Free 模式'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const Text(
            '从 EDO 标尺选择音高，再点“加入和弦”。可以试听整个和弦，点击上方单个音可单独试听，点 × 可移除。\n\n'
            'Free 目前复用 Extra 的 1–72 EDO 输入标尺与设置，后续可独立扩展。',
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: ChordleColors.dialogText,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_audio.allSoundOff());
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  ChordleHeader(
                    modeLabel: 'Free',
                    onBack: () => unawaited(_leave()),
                    onHelp: () => unawaited(_showHelp()),
                    onSettings: () => unawaited(_openSettings()),
                  ),
                  _FreeStatusBar(
                    detailText: '$_edo EDO · ${extraRangeLabel(_edo, _range)}',
                    toneCount: _chord.length,
                    audioStatus: _audio.status,
                    audioMessage: _audio.errorMessage,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= 760 &&
                            constraints.maxWidth > constraints.maxHeight * 1.2;
                        return wide
                            ? _buildLandscapeBody()
                            : _buildPortraitBody();
                      },
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

  Widget _buildPortraitBody() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildChordPreview(),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildInput(compact: false),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeBody() {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildChordPreview(),
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
                child: _buildInput(compact: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChordPreview() {
    final sortedSteps = _chord.toList()..sort();
    return _FreeChordPreview(
      steps: sortedSteps,
      edo: _edo,
      audioReady: _audioReady,
      onPlayStep: (step) =>
          unawaited(_playSteps(<int>[step], velocity: 92, durationMs: 700)),
      onRemoveStep: _removeStep,
    );
  }

  Widget _buildInput({required bool compact}) {
    final selected = _selectedStep;
    final valueColors = <int, Color>{
      for (final step in _chord) step: ChordleColors.green,
    };
    final labels = (_chord.toList()..sort())
        .map((step) => extraStepLabel(step, _edo))
        .join('  ');

    return GameInputPanel(
      selectedText: selected == null
          ? '未选 EDO 音'
          : '选中 ${extraStepLabel(selected, _edo)}',
      confirmText: '加入和弦',
      canConfirm: selected != null,
      canDelete: _chord.isNotEmpty,
      canSubmit: _chord.isNotEmpty,
      audioReady: _audioReady && _chord.isNotEmpty,
      onPlayTarget: () {
        final sortedSteps = _chord.toList()..sort();
        unawaited(_playSteps(sortedSteps));
      },
      onConfirm: _addSelectedStep,
      onDelete: _deleteLastStep,
      onSubmit: _clearChord,
      answerText: _chord.isEmpty ? '尚未加入音高' : '当前：$labels',
      submitText: '清空',
      compact: compact,
      input: MicrotonalKeyboard(
        edo: _edo,
        lowMidi: _range.lowerBound,
        highMidi: _range.upperBound,
        selectedStep: selected,
        valueColors: valueColors,
        onStepPressed: _selectStep,
        compact: compact,
      ),
    );
  }
}

class _FreeStatusBar extends StatelessWidget {
  const _FreeStatusBar({
    required this.detailText,
    required this.toneCount,
    required this.audioStatus,
    this.audioMessage,
  });

  final String detailText;
  final int toneCount;
  final AudioStatus audioStatus;
  final String? audioMessage;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (audioStatus) {
      AudioStatus.loading => '音色加载中',
      AudioStatus.ready => '音频就绪',
      AudioStatus.error => audioMessage ?? '音频引擎启动失败',
    };
    final statusColor = switch (audioStatus) {
      AudioStatus.loading => ChordleColors.yellow,
      AudioStatus.ready => ChordleColors.green,
      AudioStatus.error => ChordleColors.error,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      color: ChordleColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              detailText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ChordleColors.muted,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              statusText,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$toneCount 音',
            style: const TextStyle(
              color: ChordleColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeChordPreview extends StatelessWidget {
  const _FreeChordPreview({
    required this.steps,
    required this.edo,
    required this.audioReady,
    required this.onPlayStep,
    required this.onRemoveStep,
  });

  final List<int> steps;
  final int edo;
  final bool audioReady;
  final ValueChanged<int> onPlayStep;
  final ValueChanged<int> onRemoveStep;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChordleColors.surface,
        border: Border.all(color: ChordleColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              steps.isEmpty ? '当前和弦' : '当前和弦 · ${steps.length} 音',
              style: const TextStyle(
                color: ChordleColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: steps.isEmpty
                ? const _EmptyChordHint()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final step in steps)
                          _FreeChordTile(
                            label: extraStepLabel(step, edo),
                            onPlay: audioReady ? () => onPlayStep(step) : null,
                            onRemove: () => onRemoveStep(step),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChordHint extends StatelessWidget {
  const _EmptyChordHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: ChordleColors.border,
              size: 46,
            ),
            SizedBox(height: 10),
            Text(
              '从下方标尺选音并加入和弦',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ChordleColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeChordTile extends StatelessWidget {
  const _FreeChordTile({
    required this.label,
    required this.onPlay,
    required this.onRemove,
  });

  final String label;
  final VoidCallback? onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 66,
      child: Material(
        color: ChordleColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: ChordleColors.green, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ChordleColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: onRemove,
                  tooltip: '移除 $label',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

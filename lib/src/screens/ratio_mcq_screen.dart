import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/ratio_mcq_game.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/game_chrome.dart';
import '../widgets/ratio_mcq_help_dialog.dart';
import '../widgets/ratio_mcq_settings_dialog.dart';

class RatioMcqScreen extends StatefulWidget {
  const RatioMcqScreen({this.random, super.key});

  final math.Random? random;

  @override
  State<RatioMcqScreen> createState() => _RatioMcqScreenState();
}

class _RatioMcqScreenState extends State<RatioMcqScreen> {
  final AudioService _audio = AudioService.instance;
  final SettingsService _settingsService = SettingsService.instance;

  ChordleSettings _settings = const ChordleSettings();
  RatioMcqSession? _session;
  bool _settingsLoaded = false;
  bool _settingsDialogOpen = false;

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
      _session = _makeSession(loaded);
      _settingsLoaded = true;
    });
    if (!loaded.ratioMcqConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openSettings(firstRun: true));
      });
    }
    await _audio.prepare(loaded.instrumentProgram);
  }

  RatioMcqSession _makeSession(ChordleSettings settings) {
    final tunings = <RatioMcqTuning>[
      for (final edo in settings.ratioMcqEdos) RatioMcqTuning.edo(edo),
      if (settings.ratioMcqJiEnabled) const RatioMcqTuning.ji(),
    ];
    final ratios = <RatioMcqRatio>[
      for (final label in settings.ratioMcqRatios) parseRatioMcqRatio(label),
    ];
    return RatioMcqSession(
      RatioMcqQuestionGenerator(
        tunings: tunings,
        ratios: ratios,
        optionCount: settings.ratioMcqOptionCount,
        random: widget.random,
      ),
    );
  }

  void _handleAudioChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openSettings({bool firstRun = false}) async {
    if (_settingsDialogOpen || !mounted) return;
    _settingsDialogOpen = true;
    await _audio.allSoundOff();
    if (!mounted) {
      _settingsDialogOpen = false;
      return;
    }
    final next = await showRatioMcqSettingsDialog(
      context,
      _settings,
      firstRun: firstRun,
    );
    _settingsDialogOpen = false;
    if (!mounted) return;
    if (next == null) {
      if (firstRun) await _leave();
      return;
    }

    final replacement = _makeSession(next);
    setState(() {
      _settings = next;
      _session = replacement;
    });
    await _settingsService.save(next);
    await _audio.prepare(next.instrumentProgram);
  }

  Future<void> _leave() async {
    await _audio.allSoundOff();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _playQuestion() {
    final question = _session!.question;
    return _audio.playFrequencies(
      question.playbackFrequencies,
      durationMs: 1600,
      program: _settings.instrumentProgram,
    );
  }

  Future<void> _playQuestionTone(double frequency) {
    return _audio.playFrequencies(
      <double>[frequency],
      durationMs: 1600,
      program: _settings.instrumentProgram,
    );
  }

  void _selectOption(int index) {
    final session = _session!;
    if (session.isSubmitted) return;
    setState(() => session.selectOption(index));
  }

  void _submit() {
    final session = _session!;
    if (session.selectedOptionIndices.isEmpty || session.isSubmitted) return;
    setState(session.submit);
  }

  Future<void> _nextQuestion() async {
    if (!_session!.isSubmitted) return;
    await _audio.allSoundOff();
    if (!mounted) return;
    final session = _session!;
    if (!session.isSubmitted) return;
    setState(session.nextQuestion);
  }

  AudioIndicatorState get _audioIndicator => switch (_audio.status) {
    AudioStatus.loading => AudioIndicatorState.loading,
    AudioStatus.ready => AudioIndicatorState.ready,
    AudioStatus.error => AudioIndicatorState.error,
  };

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded || _session == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final session = _session!;
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
                    modeLabel: 'MCQ of Ratio',
                    onBack: () => unawaited(_leave()),
                    onHelp: () => unawaited(showRatioMcqHelpDialog(context)),
                    onSettings: () => unawaited(_openSettings()),
                  ),
                  _RatioMcqStatusBar(
                    tuningLabel: _tuningPrompt(session.question.tuning),
                    scoreLabel: session.scoreLabel,
                    audioState: _audioIndicator,
                    audioMessage: _audio.errorMessage,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _QuestionBody(
                            session: session,
                            audioReady: _audio.isReady,
                            onPlayA: () => unawaited(
                              _playQuestionTone(session.question.frequencyAHz),
                            ),
                            onPlayB: () => unawaited(
                              _playQuestionTone(session.question.frequencyBHz),
                            ),
                            onPlay: () => unawaited(_playQuestion()),
                            onSelectOption: _selectOption,
                            onSubmit: _submit,
                            onNextQuestion: () => unawaited(_nextQuestion()),
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
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.session,
    required this.audioReady,
    required this.onPlayA,
    required this.onPlayB,
    required this.onPlay,
    required this.onSelectOption,
    required this.onSubmit,
    required this.onNextQuestion,
  });

  final RatioMcqSession session;
  final bool audioReady;
  final VoidCallback onPlayA;
  final VoidCallback onPlayB;
  final VoidCallback onPlay;
  final ValueChanged<int> onSelectOption;
  final VoidCallback onSubmit;
  final VoidCallback onNextQuestion;

  @override
  Widget build(BuildContext context) {
    final question = session.question;
    final submitted = session.isSubmitted;
    final submission = session.lastSubmission;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RatioQuestionCard(
          tuningLabel: _tuningPrompt(question.tuning),
          audioReady: audioReady,
          onPlayA: onPlayA,
          onPlayB: onPlayB,
          onPlay: onPlay,
        ),
        const SizedBox(height: 20),
        Text(
          question.requiresMultipleSelection
              ? '请选择所有正确的有理比例（可多选）'
              : '请选择 A 到 B 的有理比例（单选）',
          style: const TextStyle(
            color: ChordleColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          question.requiresMultipleSelection
              ? '本题有多个比例在当前 EDO 中映射到相同 Step。'
              : '本题只有一个正确选项。',
          style: const TextStyle(color: ChordleColors.muted, fontSize: 13.5),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < question.options.length; index++) ...[
          _RatioOptionTile(
            index: index,
            label: question.options[index].label,
            multiple: question.requiresMultipleSelection,
            selected: session.selectedOptionIndices.contains(index),
            submitted: submitted,
            correct: question.isCorrectOption(index),
            onPressed: () => onSelectOption(index),
          ),
          if (index != question.options.length - 1) const SizedBox(height: 9),
        ],
        if (submission != null) ...[
          const SizedBox(height: 16),
          _SubmissionSummary(submission: submission),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ChordleColors.ratioMcq,
              foregroundColor: const Color(0xFF172033),
            ),
            onPressed: submitted
                ? onNextQuestion
                : session.selectedOptionIndices.isEmpty
                ? null
                : onSubmit,
            icon: Icon(
              submitted
                  ? Icons.navigate_next_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            label: Text(submitted ? '下一题' : '提交答案'),
          ),
        ),
      ],
    );
  }
}

class _RatioQuestionCard extends StatelessWidget {
  const _RatioQuestionCard({
    required this.tuningLabel,
    required this.audioReady,
    required this.onPlayA,
    required this.onPlayB,
    required this.onPlay,
  });

  final String tuningLabel;
  final bool audioReady;
  final VoidCallback onPlayA;
  final VoidCallback onPlayB;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChordleColors.surface,
        border: Border.all(
          color: ChordleColors.ratioMcq.withValues(alpha: 0.7),
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本题调律：$tuningLabel',
            style: const TextStyle(
              color: ChordleColors.ratioMcq,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final tileSize = compact ? 64.0 : 82.0;
              return Row(
                children: [
                  _ToneLetterTile(
                    letter: 'A',
                    size: tileSize,
                    enabled: audioReady,
                    onPressed: onPlayA,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: ChordleColors.muted,
                    ),
                  ),
                  _ToneLetterTile(
                    letter: 'B',
                    size: tileSize,
                    enabled: audioReady,
                    onPressed: onPlayB,
                  ),
                  const Spacer(),
                  SizedBox(
                    height: tileSize,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ChordleColors.ratioMcq,
                        foregroundColor: const Color(0xFF172033),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 13 : 19,
                        ),
                      ),
                      onPressed: audioReady ? onPlay : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.volume_up_rounded, size: 28),
                          SizedBox(height: 3),
                          Text('整组播放'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToneLetterTile extends StatelessWidget {
  const _ToneLetterTile({
    required this.letter,
    required this.size,
    required this.enabled,
    required this.onPressed,
  });

  final String letter;
  final double size;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '单独播放 $letter 音',
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: ChordleColors.elevatedSurface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: enabled ? ChordleColors.ratioMcq : ChordleColors.border,
              width: 2,
            ),
            borderRadius: borderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('ratio-tone-${letter.toLowerCase()}'),
            onTap: enabled ? onPressed : null,
            borderRadius: borderRadius,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: enabled ? ChordleColors.text : ChordleColors.muted,
                  fontSize: size * 0.46,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatioOptionTile extends StatelessWidget {
  const _RatioOptionTile({
    required this.index,
    required this.label,
    required this.multiple,
    required this.selected,
    required this.submitted,
    required this.correct,
    required this.onPressed,
  });

  final int index;
  final String label;
  final bool multiple;
  final bool selected;
  final bool submitted;
  final bool correct;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = submitted
        ? correct
              ? ChordleColors.green.withValues(alpha: 0.2)
              : selected
              ? ChordleColors.error.withValues(alpha: 0.18)
              : ChordleColors.surface
        : selected
        ? ChordleColors.ratioMcq.withValues(alpha: 0.16)
        : ChordleColors.surface;
    final borderColor = submitted
        ? correct
              ? ChordleColors.green
              : selected
              ? ChordleColors.error
              : ChordleColors.border
        : selected
        ? ChordleColors.ratioMcq
        : ChordleColors.border;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: submitted ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (multiple)
                Checkbox(
                  key: ValueKey<String>('ratio-option-checkbox-$index'),
                  value: selected,
                  onChanged: submitted ? null : (_) => onPressed(),
                )
              else
                Semantics(
                  checked: selected,
                  child: SizedBox(
                    key: ValueKey<String>('ratio-option-radio-$index'),
                    width: 48,
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: submitted
                          ? ChordleColors.muted
                          : selected
                          ? ChordleColors.ratioMcq
                          : ChordleColors.muted,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ChordleColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (submitted)
                Icon(
                  correct
                      ? Icons.check_circle_rounded
                      : selected
                      ? Icons.cancel_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: correct
                      ? ChordleColors.green
                      : selected
                      ? ChordleColors.error
                      : ChordleColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionSummary extends StatelessWidget {
  const _SubmissionSummary({required this.submission});

  final RatioMcqSubmission submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ChordleColors.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            submission.isPerfect
                ? Icons.emoji_events_rounded
                : Icons.assessment_outlined,
            color: submission.isPerfect
                ? ChordleColors.green
                : ChordleColors.ratioMcq,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本题得分 ${submission.earnedPoints}/${submission.possiblePoints}'
              ' · 选对 ${submission.correctSelections} 个'
              '${submission.incorrectSelections == 0 ? '' : ' · 选错 ${submission.incorrectSelections} 个'}',
              style: const TextStyle(
                color: ChordleColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioMcqStatusBar extends StatelessWidget {
  const _RatioMcqStatusBar({
    required this.tuningLabel,
    required this.scoreLabel,
    required this.audioState,
    this.audioMessage,
  });

  final String tuningLabel;
  final String scoreLabel;
  final AudioIndicatorState audioState;
  final String? audioMessage;

  @override
  Widget build(BuildContext context) {
    final audioText = switch (audioState) {
      AudioIndicatorState.loading => '音色加载中',
      AudioIndicatorState.ready => '音频就绪',
      AudioIndicatorState.error => audioMessage ?? '音频引擎启动失败',
    };
    final audioColor = switch (audioState) {
      AudioIndicatorState.loading => ChordleColors.yellow,
      AudioIndicatorState.ready => ChordleColors.green,
      AudioIndicatorState.error => ChordleColors.error,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      color: ChordleColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '本题：$tuningLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ChordleColors.muted,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              audioText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: audioColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '得分 $scoreLabel',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ChordleColors.ratioMcq,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _tuningPrompt(RatioMcqTuning tuning) {
  return tuning.isJi ? 'JI（纯律）' : tuning.label;
}

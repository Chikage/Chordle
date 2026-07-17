import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/chord_game.dart';
import '../game/edo_ratio.dart';
import '../game/ji_tuning.dart';
import '../models/free_chord_collection.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/game_chrome.dart';
import '../widgets/game_input_panel.dart';
import '../widgets/microtonal_keyboard.dart';
import '../widgets/ratio_number_pad.dart';
import '../widgets/settings_dialogs.dart';

class FreeScreen extends StatefulWidget {
  const FreeScreen({super.key});

  @override
  State<FreeScreen> createState() => _FreeScreenState();
}

class _FreeScreenState extends State<FreeScreen> {
  static const _sequenceToneDuration = Duration(milliseconds: 1400);
  static const _sequenceGap = Duration(milliseconds: 350);

  final AudioService _audio = AudioService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  final FreeChordCollection _collection = FreeChordCollection();
  final math.Random _random = math.Random();
  final ScrollController _groupScrollController = ScrollController();
  final Map<int, GlobalKey> _groupCardKeys = <int, GlobalKey>{};
  final Map<int, int> _lastImplicitEdoRootByGroup = <int, int>{};
  final Map<int, int> _lastImplicitJiRootByGroup = <int, int>{};
  final ChordPuzzle _playbackContext = ChordPuzzle(
    notes: const <int>[],
    label: 'Free',
  );

  ChordleSettings _settings = const ChordleSettings();
  int? _selectedStep;
  var _inputMode = _FreeInputMode.ruler;
  var _playbackMode = _FreePlaybackMode.sequential;
  var _ratioInput = '';
  _NoteSwapSelection? _noteSwapSource;
  int? _groupSwapSourceId;
  int? _playingGroupId;
  var _playbackToken = 0;
  var _isSequencePlaying = false;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_handleAudioChanged);
    unawaited(_loadSettingsAndAudio());
  }

  @override
  void dispose() {
    _playbackToken += 1;
    _groupScrollController.dispose();
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

  IntRange get _range => fullPianoRange;

  IntRange get _stepRange => edoStepRangeForMidiRange(_edo, _range);

  int get _edo => sanitizeExtraEdo(_settings.extraEdo);

  bool get _jiMode => _settings.freeJiEnabled;

  bool get _audioReady => _audio.status == AudioStatus.ready;

  FreeChordGroup get _activeGroup => _collection.activeGroup;

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

  void _stopPlaybackState() {
    _playbackToken += 1;
    _isSequencePlaying = false;
    _playingGroupId = null;
  }

  void _stopPlayback() {
    setState(_stopPlaybackState);
    unawaited(_audio.allSoundOff());
  }

  void _togglePlaybackMode() {
    if (_isSequencePlaying) return;
    setState(() {
      _playbackMode = switch (_playbackMode) {
        _FreePlaybackMode.sequential => _FreePlaybackMode.random,
        _FreePlaybackMode.random => _FreePlaybackMode.sequential,
      };
    });
  }

  Future<void> _playStepValuesNow(
    List<int> steps, {
    int velocity = 104,
    int durationMs = 1400,
  }) async {
    if (!_audioReady || steps.isEmpty) return;
    final snapshot = List<int>.of(steps);
    final token = ++_playbackToken;
    setState(() {
      _isSequencePlaying = false;
      _playingGroupId = null;
    });
    await _audio.allSoundOff();
    if (!mounted || token != _playbackToken) return;
    await _playSteps(snapshot, velocity: velocity, durationMs: durationMs);
  }

  Future<void> _playFrequencies(
    List<double> frequencies, {
    int velocity = 104,
    int durationMs = 1400,
  }) {
    return _audio.playFrequencies(
      frequencies,
      velocity: velocity,
      durationMs: durationMs,
      program: _settings.instrumentProgram,
    );
  }

  Future<void> _playFrequencyValuesNow(
    List<double> frequencies, {
    int velocity = 104,
    int durationMs = 1400,
  }) async {
    if (!_audioReady || frequencies.isEmpty) return;
    final snapshot = List<double>.of(frequencies);
    final token = ++_playbackToken;
    setState(() {
      _isSequencePlaying = false;
      _playingGroupId = null;
    });
    await _audio.allSoundOff();
    if (!mounted || token != _playbackToken) return;
    await _playFrequencies(
      snapshot,
      velocity: velocity,
      durationMs: durationMs,
    );
  }

  FreeNoteSwapResult _recalculateJiGroup(
    int groupId, {
    double? fallbackReferenceHz,
  }) {
    return _collection.recalculateJiGroup(
      groupId: groupId,
      ratioValue: (label) => parsePositiveRatio(label).value,
      approximateStep: (frequency) =>
          approximateExtraStepForFrequency(frequency, _edo),
      isPlayable: isPlayableJiFrequency,
      fallbackReferenceHz: fallbackReferenceHz,
    );
  }

  FreeNoteSwapResult _recalculateEdoGroup(
    int groupId, {
    int? fallbackReferenceStep,
  }) {
    return _collection.recalculateEdoGroup(
      groupId: groupId,
      stepsForRatio: (label) =>
          pureEdoStepsForRatio(parsePositiveRatio(label), _edo),
      isPlayable: _stepRange.contains,
      fallbackReferenceStep: fallbackReferenceStep,
    );
  }

  _PlaybackChord? _preparePlaybackChord(FreeChordGroup group) {
    if (!_jiMode) {
      final hasAbsoluteReference =
          group.rootTone != null || group.lowestStepAnchor != null;
      int? fallbackReferenceStep;
      var implicitRandomRoot = false;
      if (!hasAbsoluteReference) {
        final relativeSteps = group.tones
            .map((tone) => tone.ratioLabel)
            .whereType<String>()
            .map(
              (label) => pureEdoStepsForRatio(parsePositiveRatio(label), _edo),
            )
            .toList(growable: false);
        fallbackReferenceStep = randomEdoBaseStep(
          relativeSteps,
          _stepRange,
          excludingStep: _lastImplicitEdoRootByGroup[group.id],
          random: _random,
        );
        if (fallbackReferenceStep == null) {
          _showMessage('该组比例跨度过大，无法在 A0–C8 内选择随机 EDO 根音');
          return null;
        }
        _lastImplicitEdoRootByGroup[group.id] = fallbackReferenceStep;
        implicitRandomRoot = true;
      }

      final result = _recalculateEdoGroup(
        group.id,
        fallbackReferenceStep: fallbackReferenceStep,
      );
      if (result != FreeNoteSwapResult.swapped) {
        _showMessage(
          result == FreeNoteSwapResult.wouldDuplicate
              ? 'EDO 重算后产生重复音高，无法播放该组'
              : 'EDO 重算后有音高超出 A0–C8，无法播放该组',
        );
        return null;
      }

      final steps = <int>[
        for (final tone in group.tones)
          if (_stepRange.contains(tone.step))
            if (!implicitRandomRoot ||
                tone.ratioLabel == null ||
                pureEdoStepsForRatio(
                      parsePositiveRatio(tone.ratioLabel!),
                      _edo,
                    ) !=
                    0)
              tone.step,
      ];
      if (steps.isEmpty) return null;
      return _PlaybackChord.edo(group.id, steps);
    }

    final hasAbsoluteReference =
        group.rootTone?.frequencyHz != null ||
        group.lowestAbsoluteAnchor != null;
    double? fallbackReferenceHz;
    var implicitRandomRoot = false;
    if (!hasAbsoluteReference) {
      final ratios = group.tones
          .map((tone) => tone.ratioLabel)
          .whereType<String>()
          .map(parsePositiveRatio)
          .toList(growable: false);
      final baseMidi = randomJiBaseMidiNote(
        ratios,
        excludingMidiNote: _lastImplicitJiRootByGroup[group.id],
        random: _random,
      );
      if (baseMidi == null) {
        _showMessage('该组比例跨度过大，无法在 A0–C8 内选择随机根音');
        return null;
      }
      _lastImplicitJiRootByGroup[group.id] = baseMidi;
      fallbackReferenceHz = midiNoteFrequency(baseMidi);
      implicitRandomRoot = true;
    }

    final result = _recalculateJiGroup(
      group.id,
      fallbackReferenceHz: fallbackReferenceHz,
    );
    if (result != FreeNoteSwapResult.swapped) {
      _showMessage(
        result == FreeNoteSwapResult.wouldDuplicate
            ? 'JI 重算后产生重复频率，无法播放该组'
            : 'JI 重算后有频率超出 A0–C8，无法播放该组',
      );
      return null;
    }

    final frequencies = <double>[
      for (final tone in group.tones)
        if (tone.frequencyHz case final frequency?)
          if (!implicitRandomRoot || tone.ratioLabel != '1/1') frequency,
    ];
    if (frequencies.isEmpty) return null;
    return _PlaybackChord.ji(group.id, frequencies);
  }

  Future<void> _playGroupNow(int groupId) async {
    final group = _collection.groupById(groupId);
    if (!_audioReady || group == null || group.isEmpty) return;
    final initialChord = _preparePlaybackChord(group);
    if (initialChord == null) return;
    var chord = initialChord;

    final token = ++_playbackToken;
    setState(() {
      _clearSwapSelections();
      _isSequencePlaying = true;
      _playingGroupId = groupId;
    });
    _scheduleScrollToGroup(groupId);

    while (mounted && token == _playbackToken) {
      await _audio.allSoundOff();
      if (!mounted || token != _playbackToken) return;
      await _playPreparedChord(chord);
      await Future<void>.delayed(_sequenceToneDuration + _sequenceGap);
      if (!mounted || token != _playbackToken) return;
      final currentGroup = _collection.groupById(groupId);
      if (currentGroup == null || currentGroup.isEmpty) break;
      final nextChord = _preparePlaybackChord(currentGroup);
      if (nextChord == null) break;
      chord = nextChord;
      setState(() => _playingGroupId = groupId);
    }

    if (!mounted || token != _playbackToken) return;
    setState(_stopPlaybackState);
  }

  Future<void> _playPreparedChord(_PlaybackChord chord) {
    if (chord.frequencies != null) {
      return _playFrequencies(
        chord.frequencies!,
        durationMs: _sequenceToneDuration.inMilliseconds,
      );
    }
    return _playSteps(
      chord.steps!,
      durationMs: _sequenceToneDuration.inMilliseconds,
    );
  }

  Future<void> _playToneNow(int groupId, int toneId) async {
    final group = _collection.groupById(groupId);
    var tone = group?.toneById(toneId);
    if (group == null || tone == null) return;
    if (_jiMode) {
      if (tone.frequencyHz == null) {
        if (_preparePlaybackChord(group) == null) return;
        tone = group.toneById(toneId);
        if (mounted) setState(() {});
      }
      final frequency = tone?.frequencyHz;
      if (frequency != null) {
        await _playFrequencyValuesNow(
          <double>[frequency],
          velocity: 92,
          durationMs: 700,
        );
      }
      return;
    }
    if (tone.step < 0) {
      if (_preparePlaybackChord(group) == null) return;
      tone = group.toneById(toneId);
      if (mounted) setState(() {});
    }
    if (tone == null || !_stepRange.contains(tone.step)) return;
    await _playStepValuesNow(<int>[tone.step], velocity: 92, durationMs: 700);
  }

  Future<void> _playSequence() async {
    final groupIds = <int>[
      for (final group in _collection.groups)
        if (!group.isEmpty) group.id,
    ];
    if (!_audioReady || groupIds.isEmpty) {
      _showMessage('请先至少设置一组非空和弦');
      return;
    }

    final token = ++_playbackToken;
    setState(() {
      _clearSwapSelections();
      _isSequencePlaying = true;
      _playingGroupId = null;
    });

    while (mounted && token == _playbackToken) {
      final cycleGroupIds = List<int>.of(groupIds);
      if (_playbackMode == _FreePlaybackMode.random) {
        cycleGroupIds.shuffle(_random);
      }
      var playedAny = false;

      for (final groupId in cycleGroupIds) {
        if (!mounted || token != _playbackToken) return;
        final group = _collection.groupById(groupId);
        if (group == null || group.isEmpty) continue;
        final chord = _preparePlaybackChord(group);
        if (chord == null) continue;
        playedAny = true;
        setState(() => _playingGroupId = chord.groupId);
        _scheduleScrollToGroup(chord.groupId);
        await _audio.allSoundOff();
        if (!mounted || token != _playbackToken) return;
        await _playPreparedChord(chord);
        await Future<void>.delayed(_sequenceToneDuration + _sequenceGap);
      }

      if (!playedAny) break;
    }

    if (!mounted || token != _playbackToken) return;
    setState(_stopPlaybackState);
  }

  GlobalKey _groupCardKey(int groupId) =>
      _groupCardKeys.putIfAbsent(groupId, GlobalKey.new);

  void _scheduleScrollToGroup(int groupId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToGroup(groupId));
    });
  }

  Future<void> _scrollToGroup(int groupId) async {
    if (!mounted ||
        !_isSequencePlaying ||
        _playingGroupId != groupId ||
        !_groupScrollController.hasClients) {
      return;
    }

    var cardContext = _groupCardKeys[groupId]?.currentContext;
    if (cardContext == null) {
      final index = _collection.groupPosition(groupId);
      if (index < 0) return;
      final groupCount = _collection.groups.length;
      final position = _groupScrollController.position;
      final target = groupCount <= 1
          ? 0.0
          : position.maxScrollExtent * index / (groupCount - 1);
      await _groupScrollController.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (!mounted ||
          !_isSequencePlaying ||
          _playingGroupId != groupId ||
          !_groupScrollController.hasClients) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      cardContext = _groupCardKeys[groupId]?.currentContext;
    }

    if (cardContext == null ||
        !cardContext.mounted ||
        !mounted ||
        !_isSequencePlaying ||
        _playingGroupId != groupId) {
      return;
    }
    await Scrollable.ensureVisible(
      cardContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _cancelPlaybackForEdit() {
    _stopPlaybackState();
    unawaited(_audio.allSoundOff());
  }

  void _clearSwapSelections() {
    _noteSwapSource = null;
    _groupSwapSourceId = null;
  }

  void _selectStep(int step) {
    setState(() => _selectedStep = step);
    if (_audioReady) {
      if (_jiMode) {
        unawaited(
          _playFrequencyValuesNow(
            <double>[frequencyForExtraStep(step, _edo)],
            velocity: 92,
            durationMs: 520,
          ),
        );
      } else {
        unawaited(
          _playStepValuesNow(<int>[step], velocity: 92, durationMs: 520),
        );
      }
    }
  }

  void _toggleInputMode() {
    setState(() {
      _inputMode = switch (_inputMode) {
        _FreeInputMode.ruler => _FreeInputMode.ratio,
        _FreeInputMode.ratio => _FreeInputMode.ruler,
      };
    });
  }

  void _appendRatioKey(String key) {
    if (key == '/') {
      if (_ratioInput.isEmpty || _ratioInput.contains('/')) return;
      setState(() => _ratioInput += key);
      return;
    }
    final currentPart = _ratioInput.split('/').last;
    if (currentPart.length >= 9) {
      _showMessage('分子和分母最多输入 9 位');
      return;
    }
    setState(() => _ratioInput += key);
  }

  void _backspaceRatio() {
    if (_ratioInput.isEmpty) return;
    setState(
      () => _ratioInput = _ratioInput.substring(0, _ratioInput.length - 1),
    );
  }

  void _clearRatioInput() {
    if (_ratioInput.isEmpty) return;
    setState(() => _ratioInput = '');
  }

  void _addRatioTone() {
    final group = _activeGroup;
    late final PositiveRatio ratio;
    try {
      ratio = parsePositiveRatio(_ratioInput);
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
      return;
    }
    if (group.tones.any((tone) => tone.ratioLabel == ratio.label)) {
      _showMessage('当前和弦中已有比例 ${ratio.label}');
      return;
    }

    if (_jiMode) {
      final referenceHz =
          group.rootTone?.frequencyHz ??
          group.lowestAbsoluteAnchor?.frequencyHz;
      final frequency = referenceHz == null ? null : referenceHz * ratio.value;
      if (referenceHz == null && ratio.numerator == ratio.denominator) {
        _showMessage('隐含随机根音不会加入和弦，请输入 1/1 以外的比例');
        return;
      }
      if (frequency != null && !isPlayableJiFrequency(frequency)) {
        _showMessage('${ratio.label} 的精确频率超出 A0–C8');
        return;
      }
      if (frequency != null &&
          group.tones.any(
            (tone) =>
                tone.frequencyHz != null &&
                (tone.frequencyHz! - frequency).abs() <= 0.000001,
          )) {
        _showMessage('${ratio.label} 与当前和弦中的频率重复');
        return;
      }
      setState(() {
        _cancelPlaybackForEdit();
        _clearSwapSelections();
        _collection.addJiRatioTone(
          group.id,
          ratioLabel: ratio.label,
          approximateStep: frequency == null
              ? null
              : approximateExtraStepForFrequency(frequency, _edo),
          frequencyHz: frequency,
        );
        _ratioInput = '';
        _selectedStep = null;
      });
      _showMessage(
        frequency == null
            ? '已加入 ${ratio.label}；播放时将随机选择隐含根音'
            : '已加入 ${frequencyLabel(frequency)} · ${ratio.label}',
      );
      return;
    }

    final root = group.rootTone;
    final reference = root ?? group.lowestStepAnchor;
    final relativeSteps = pureEdoStepsForRatio(ratio, _edo);
    if (reference == null) {
      if (relativeSteps == 0) {
        _showMessage('隐含随机根音不会加入和弦，请输入 1/1 以外的比例');
        return;
      }
      final duplicatesRelativeStep = group.tones
          .map((tone) => tone.ratioLabel)
          .whereType<String>()
          .map((label) => pureEdoStepsForRatio(parsePositiveRatio(label), _edo))
          .contains(relativeSteps);
      if (duplicatesRelativeStep) {
        _showMessage('${ratio.label} 与已有比例在 $_edo EDO 中映射到相同步数');
        return;
      }
      setState(() {
        _cancelPlaybackForEdit();
        _clearSwapSelections();
        _collection.addRatioTone(
          group.id,
          ratioLabel: ratio.label,
          resolvedStep: null,
        );
        _ratioInput = '';
        _selectedStep = null;
      });
      _showMessage('已加入 ${ratio.label}；播放时将随机选择隐含 EDO 根音');
      return;
    }

    final targetStep = reference.step + relativeSteps;
    final playableSteps = _stepRange;
    if (!playableSteps.contains(targetStep)) {
      _showMessage(
        '${ratio.label} 对应 ${relativeSteps >= 0 ? '+' : ''}$relativeSteps Step，超出当前音域',
      );
      return;
    }

    final existing = group.toneAtStep(targetStep);
    if (existing != null && existing.id == reference.id) {
      _showMessage('${ratio.label} 在 $_edo EDO 中映射到参考音（0 Step）');
      return;
    }

    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      if (existing == null) {
        _collection.addStep(
          group.id,
          targetStep,
          ratioLabel: ratio.label,
          isAbsoluteAnchor: false,
        );
      } else {
        _collection.setRatioLabel(group.id, targetStep, ratio.label);
      }
      _ratioInput = '';
      _selectedStep = null;
    });

    final note = extraStepLabel(targetStep, _edo);
    final action = existing == null ? '已加入' : '已更新比例标签';
    _showMessage(
      '$action $note · ${ratio.label} · ${relativeSteps >= 0 ? '+' : ''}$relativeSteps Step',
    );
  }

  void _addSelectedStep() {
    final step = _selectedStep;
    if (step == null) return;
    if (_activeGroup.steps.contains(step)) {
      _showMessage('当前和弦中已有 ${extraStepLabel(step, _edo)}');
      return;
    }
    var recalculation = FreeNoteSwapResult.swapped;
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.addStep(
        _collection.activeGroupId,
        step,
        frequencyHz: _jiMode ? frequencyForExtraStep(step, _edo) : null,
        isAbsoluteAnchor: true,
      );
      recalculation = _jiMode
          ? _recalculateJiGroup(_collection.activeGroupId)
          : _recalculateEdoGroup(_collection.activeGroupId);
      _selectedStep = null;
    });
    if (recalculation == FreeNoteSwapResult.outOfRange) {
      _showMessage('参考音已加入，但现有比例重算后超出 A0–C8');
    } else if (recalculation == FreeNoteSwapResult.wouldDuplicate) {
      _showMessage('参考音已加入，但现有比例重算后产生重复音高');
    }
  }

  void _clearActiveChord() {
    if (_activeGroup.isEmpty) return;
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.clearGroup(_collection.activeGroupId);
      _lastImplicitEdoRootByGroup.remove(_collection.activeGroupId);
      _lastImplicitJiRootByGroup.remove(_collection.activeGroupId);
      _selectedStep = null;
      _ratioInput = '';
    });
  }

  void _addGroup() {
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.addGroup();
      _selectedStep = null;
      _ratioInput = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_groupScrollController.hasClients) return;
      unawaited(
        _groupScrollController.animateTo(
          _groupScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _selectGroup(int groupId) {
    if (groupId == _collection.activeGroupId) return;
    setState(() {
      _clearSwapSelections();
      _collection.selectGroup(groupId);
      _selectedStep = null;
      _ratioInput = '';
    });
  }

  Future<void> _deleteGroup(int groupId) async {
    final group = _collection.groupById(groupId);
    if (group == null || _collection.groups.length <= 1) return;
    var confirmed = true;
    if (!group.isEmpty) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('删除和弦组？'),
              content: const Text('该组中的全部音都会被删除。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ChordleColors.error,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('删除'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!confirmed || !mounted) return;
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.removeGroup(groupId);
      _lastImplicitEdoRootByGroup.remove(groupId);
      _lastImplicitJiRootByGroup.remove(groupId);
      _selectedStep = null;
      _ratioInput = '';
    });
  }

  void _sortGroup(int groupId) {
    setState(() {
      _cancelPlaybackForEdit();
      _noteSwapSource = null;
      if (_jiMode) {
        _collection.sortJiGroup(groupId);
      } else {
        _collection.sortGroup(groupId);
      }
    });
  }

  void _handleGroupSwap(int groupId) {
    final sourceId = _groupSwapSourceId;
    if (sourceId == null) {
      setState(() {
        _noteSwapSource = null;
        _groupSwapSourceId = groupId;
      });
      _showMessage('再点击另一组的“交换整组”完成位置交换');
      return;
    }
    if (sourceId == groupId) {
      setState(() => _groupSwapSourceId = null);
      _showMessage('已取消整组交换');
      return;
    }

    setState(() {
      _cancelPlaybackForEdit();
      _collection.swapGroups(sourceId, groupId);
      _groupSwapSourceId = null;
    });
    _showMessage('两组和弦的位置已交换');
  }

  Future<void> _showNoteActions(int groupId, int toneId) async {
    final groupPosition = _collection.groupPosition(groupId);
    final group = _collection.groupById(groupId);
    final tone = group?.toneById(toneId);
    if (groupPosition < 0 || group == null || tone == null) return;
    final isRoot = group.isRoot(tone);
    final label = _jiMode
        ? frequencyLabel(tone.frequencyHz)
        : tone.step < 0
        ? '待随机'
        : extraStepLabel(tone.step, _edo);
    final canSetRoot = _jiMode ? tone.frequencyHz != null : tone.step >= 0;
    final action = await showModalBottomSheet<_NoteAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('和弦 ${groupPosition + 1} · $label'),
              subtitle: const Text('选择要执行的操作'),
            ),
            ListTile(
              leading: Icon(isRoot ? Icons.flag_outlined : Icons.flag_rounded),
              title: Text(isRoot ? '取消根音' : '设为根音'),
              subtitle: Text(
                isRoot
                    ? '改用输入的最低音；没有时播放会随机选择隐含根音'
                    : canSetRoot
                    ? '该音将作为比例输入的 1/1'
                    : '该比例音尚无绝对音高，请先播放和弦',
              ),
              onTap: !isRoot && !canSetRoot
                  ? null
                  : () => Navigator.of(
                      sheetContext,
                    ).pop(isRoot ? _NoteAction.clearRoot : _NoteAction.setRoot),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除此音'),
              onTap: () => Navigator.of(sheetContext).pop(_NoteAction.delete),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('与其他组的音交换'),
              subtitle: const Text('选择后，再点击另一组中的目标音'),
              onTap: () => Navigator.of(sheetContext).pop(_NoteAction.swap),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _NoteAction.delete:
        setState(() {
          _cancelPlaybackForEdit();
          _clearSwapSelections();
          _collection.removeToneById(
            groupId,
            toneId,
            clearRatiosWhenRemovingRoot: false,
          );
          if (_jiMode) {
            _recalculateJiGroup(groupId);
          } else {
            _recalculateEdoGroup(groupId);
          }
          _ratioInput = '';
        });
      case _NoteAction.swap:
        setState(() {
          _groupSwapSourceId = null;
          _noteSwapSource = _NoteSwapSelection(groupId, toneId);
        });
        _showMessage('请点击其他和弦组中要交换的音');
      case _NoteAction.setRoot:
        setState(() {
          _cancelPlaybackForEdit();
          _clearSwapSelections();
          if (_jiMode) {
            _collection.setJiRoot(groupId, toneId);
            _recalculateJiGroup(groupId);
          } else {
            _collection.setRoot(groupId, tone.step, clearRatioLabels: false);
            _recalculateEdoGroup(groupId);
          }
          _ratioInput = '';
        });
        _showMessage('$label 已设为根音 1/1');
      case _NoteAction.clearRoot:
        setState(() {
          _cancelPlaybackForEdit();
          _clearSwapSelections();
          _collection.clearRoot(groupId, clearRatioLabels: false);
          if (_jiMode) {
            _recalculateJiGroup(groupId);
          } else {
            _recalculateEdoGroup(groupId);
          }
          _ratioInput = '';
        });
        _showMessage('已取消根音，改用输入的最低音或播放时随机隐含根音');
    }
  }

  void _handleNoteTap(int groupId, int toneId) {
    final source = _noteSwapSource;
    if (source == null) {
      unawaited(_playToneNow(groupId, toneId));
      return;
    }
    if (source.groupId == groupId && source.toneId == toneId) {
      setState(() => _noteSwapSource = null);
      _showMessage('已取消音交换');
      return;
    }

    final firstTone = _collection
        .groupById(source.groupId)
        ?.toneById(source.toneId);
    final secondTone = _collection.groupById(groupId)?.toneById(toneId);
    final rebaseRatio =
        firstTone?.ratioLabel != null || secondTone?.ratioLabel != null;
    final result = _jiMode
        ? _collection.swapJiTones(
            firstGroupId: source.groupId,
            firstToneId: source.toneId,
            secondGroupId: groupId,
            secondToneId: toneId,
            ratioValue: (label) => parsePositiveRatio(label).value,
            approximateStep: (frequency) =>
                approximateExtraStepForFrequency(frequency, _edo),
            isPlayable: isPlayableJiFrequency,
          )
        : _collection.swapSteps(
            firstGroupId: source.groupId,
            firstStep: firstTone?.step ?? 0,
            secondGroupId: groupId,
            secondStep: secondTone?.step ?? 0,
            stepsForRatio: (ratioLabel) =>
                pureEdoStepsForRatio(parsePositiveRatio(ratioLabel), _edo),
            isPlayable: _stepRange.contains,
          );
    switch (result) {
      case FreeNoteSwapResult.swapped:
        setState(() {
          _cancelPlaybackForEdit();
          _noteSwapSource = null;
          _ratioInput = '';
        });
        _showMessage(rebaseRatio ? '两个音已交换；比例音已按新组参考重新计算' : '两个音已交换');
      case FreeNoteSwapResult.sameGroup:
        _showMessage('只能与其他和弦组中的音交换');
      case FreeNoteSwapResult.sameNote:
        _showMessage('两个音相同，请选择其他音');
      case FreeNoteSwapResult.wouldDuplicate:
        _showMessage('按新组参考重算后会产生重复音，请选择其他音');
      case FreeNoteSwapResult.outOfRange:
        _showMessage(_jiMode ? '精确频率超出 A0–C8，请选择其他音' : '重算后超出当前音域，请选择其他音');
      case FreeNoteSwapResult.missingGroupOrNote:
        setState(() => _noteSwapSource = null);
        _showMessage('原音已不存在，请重新选择');
    }
  }

  Future<void> _openSettings() async {
    _stopPlayback();
    final previousEdo = _edo;
    final previousJiMode = _jiMode;
    final next = await showExtraSettingsDialog(
      context,
      _settings,
      freeMode: true,
    );
    if (next == null || !mounted) return;

    final nextEdo = sanitizeExtraEdo(next.extraEdo);
    final hadTones = _collection.totalToneCount > 0;

    setState(() {
      _settings = next;
      _selectedStep = null;
      _ratioInput = '';
      _clearSwapSelections();
      if (previousJiMode != next.freeJiEnabled || previousEdo != nextEdo) {
        _collection.clearAllSteps();
        _lastImplicitEdoRootByGroup.clear();
        _lastImplicitJiRootByGroup.clear();
      }
    });
    await _settingsService.save(next);
    if (!mounted) return;
    await _audio.prepare(next.instrumentProgram);
    if (!mounted) return;

    if (previousJiMode != next.freeJiEnabled && hadTones) {
      _showMessage('JI 模式已切换，全部和弦组已清空');
    } else if (previousEdo != nextEdo && hadTones) {
      _showMessage('EDO 参考尺已更改，全部和弦组已清空');
    }
  }

  Future<void> _leave() async {
    _playbackToken += 1;
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
          child: const SingleChildScrollView(
            child: Text(
              '使用和弦列表底部的“+”建立多组和弦，新增空组会自动进入编辑状态；再从 EDO 标尺加入音高。在输入区域上下滑动，可在刻度尺和数字比例键盘之间切换，比例内容统一显示在播放按钮右侧。\n\n'
              '长按组内的音可将它设为根音 1/1。随后输入 3/2、5/4 等比例并点“按比例加入”，会用纯 EDO 的逐质数取整算法计算相对 Step；未指定根音时使用输入的最低音，整组只有比例时则随机选择隐含 EDO 根音，且不播放该根音本身。\n\n'
              '设置中开启 JI 后，比例不再量化到 EDO，而是按根音或绝对最低音的精确频率比播放，卡片仅显示频率和比例。若整组只有比例而没有绝对参考，同样会按 Overtones 的低音权重随机选择隐含根音。\n\n'
              '长按音还可选择删除或进入跨组音交换；带比例标签的音进入新组后，会按新组根音重新计算，没有根音时改用该组最低音。每组的“从低到高”会排序组内音，“交换整组”需要依次选择两组。\n\n'
              '输入面板中的“顺序播放/随机播放”按钮可单击切换策略；“播放和弦”会循环播放全部非空组，单组播放也会持续循环，直到点击“停止播放”。每轮会为无参考的 EDO/JI 组选择不同隐含根音，播放期间列表会自动滚动到当前组并收起编辑按钮。\n\n'
              'Free 使用 Extra 的 1–72 EDO 标尺模板，但拥有独立的 A0–C8 全音域，并以 C4 作为标尺默认显示中心。',
            ),
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
        if (didPop) {
          _playbackToken += 1;
          unawaited(_audio.allSoundOff());
        }
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
                    detailText: _jiMode
                        ? 'JI 精确比例 · A0–C8'
                        : '$_edo EDO · A0–C8',
                    groupCount: _collection.groups.length,
                    toneCount: _collection.totalToneCount,
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
            child: _buildChordList(),
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
            child: _buildChordList(),
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

  Widget _buildChordList() {
    return _FreeChordList(
      groups: _collection.groups,
      activeGroupId: _collection.activeGroupId,
      playingGroupId: _playingGroupId,
      noteSwapSource: _noteSwapSource,
      groupSwapSourceId: _groupSwapSourceId,
      audioReady: _audioReady,
      isSequencePlaying: _isSequencePlaying,
      jiMode: _jiMode,
      scrollController: _groupScrollController,
      groupCardKey: _groupCardKey,
      edo: _edo,
      onAddGroup: _addGroup,
      onSelectGroup: _selectGroup,
      onPlayGroup: (groupId) => unawaited(_playGroupNow(groupId)),
      onSortGroup: _sortGroup,
      onSwapGroup: _handleGroupSwap,
      onDeleteGroup: (groupId) => unawaited(_deleteGroup(groupId)),
      onNoteTap: _handleNoteTap,
      onNoteLongPress: (groupId, toneId) =>
          unawaited(_showNoteActions(groupId, toneId)),
    );
  }

  Widget _buildInput({required bool compact}) {
    final selected = _selectedStep;
    final group = _activeGroup;
    final valueColors = <int, Color>{
      for (final tone in group.tones)
        if (tone.step >= 0)
          tone.step: group.isRoot(tone)
              ? ChordleColors.yellow
              : ChordleColors.green,
    };
    final labels = group.tones
        .map(
          (tone) => _jiMode
              ? '${frequencyLabel(tone.frequencyHz)}${tone.ratioLabel == null ? '' : ' ${tone.ratioLabel}'}'
              : tone.ratioLabel == null
              ? extraStepLabel(tone.step, _edo)
              : '${tone.step < 0 ? '待随机' : extraStepLabel(tone.step, _edo)} ${tone.ratioLabel}',
        )
        .join('  ');
    final groupNumber = _collection.groupPosition(group.id) + 1;
    final root = group.rootTone;
    final lowestAnchor = group.lowestAbsoluteAnchor;
    final lowestStepAnchor = group.lowestStepAnchor;
    final ratioMode = _inputMode == _FreeInputMode.ratio;
    final ratioInputLabel = _ratioInput.isEmpty ? '输入比例' : _ratioInput;
    final hasPlayableGroup = _collection.groups.any(
      (candidate) => !candidate.isEmpty,
    );
    final selectedText = ratioMode
        ? _jiMode
              ? root?.frequencyHz != null
                    ? '根音 ${frequencyLabel(root!.frequencyHz)} · $ratioInputLabel'
                    : lowestAnchor?.frequencyHz != null
                    ? '最低音 ${frequencyLabel(lowestAnchor!.frequencyHz)} · $ratioInputLabel'
                    : 'JI 隐含根音 · $ratioInputLabel'
              : root == null
              ? lowestStepAnchor == null
                    ? 'EDO 隐含根音 · $ratioInputLabel'
                    : '最低音 ${extraStepLabel(lowestStepAnchor.step, _edo)} · $ratioInputLabel'
              : '根音 ${extraStepLabel(root.step, _edo)} · $ratioInputLabel'
        : selected == null
        ? (_jiMode ? '未选绝对参考音' : '未选 EDO 音')
        : _jiMode
        ? '选中 ${frequencyLabel(frequencyForExtraStep(selected, _edo))}'
        : '选中 ${extraStepLabel(selected, _edo)}';

    return GameInputPanel(
      selectedText: selectedText,
      confirmText: ratioMode ? '按比例加入' : '加入和弦',
      canConfirm: ratioMode ? _ratioInput.isNotEmpty : selected != null,
      canDelete: !_isSequencePlaying,
      canSubmit: !group.isEmpty,
      audioReady: _isSequencePlaying || (_audioReady && hasPlayableGroup),
      onPlayTarget: _isSequencePlaying
          ? _stopPlayback
          : () => unawaited(_playSequence()),
      playText: _isSequencePlaying ? '停止播放' : '播放和弦',
      playIcon: _isSequencePlaying
          ? Icons.stop_rounded
          : Icons.play_arrow_rounded,
      onConfirm: ratioMode ? _addRatioTone : _addSelectedStep,
      onDelete: _togglePlaybackMode,
      onSubmit: _clearActiveChord,
      answerText: group.isEmpty
          ? '正在编辑和弦 $groupNumber · 尚未加入音高'
          : '和弦 $groupNumber：$labels',
      submitText: '清空本组',
      deleteText: _playbackMode == _FreePlaybackMode.sequential
          ? '顺序播放'
          : '随机播放',
      compact: compact,
      input: _FreeInputSwitcher(
        mode: _inputMode,
        compact: compact,
        onToggle: _toggleInputMode,
        child: switch (_inputMode) {
          _FreeInputMode.ruler => MicrotonalKeyboard(
            edo: _edo,
            lowMidi: _range.lowerBound,
            highMidi: _range.upperBound,
            initialCenterMidi: 60,
            selectedStep: selected,
            valueColors: valueColors,
            onStepPressed: _selectStep,
            compact: compact,
          ),
          _FreeInputMode.ratio => RatioNumberPad(
            onKeyPressed: _appendRatioKey,
            onBackspace: _backspaceRatio,
            onClear: _clearRatioInput,
            compact: compact,
          ),
        },
      ),
    );
  }
}

class _FreeStatusBar extends StatelessWidget {
  const _FreeStatusBar({
    required this.detailText,
    required this.groupCount,
    required this.toneCount,
    required this.audioStatus,
    this.audioMessage,
  });

  final String detailText;
  final int groupCount;
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
            '$groupCount 组 · $toneCount 音',
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

class _FreeChordList extends StatelessWidget {
  const _FreeChordList({
    required this.groups,
    required this.activeGroupId,
    required this.playingGroupId,
    required this.noteSwapSource,
    required this.groupSwapSourceId,
    required this.audioReady,
    required this.isSequencePlaying,
    required this.jiMode,
    required this.scrollController,
    required this.groupCardKey,
    required this.edo,
    required this.onAddGroup,
    required this.onSelectGroup,
    required this.onPlayGroup,
    required this.onSortGroup,
    required this.onSwapGroup,
    required this.onDeleteGroup,
    required this.onNoteTap,
    required this.onNoteLongPress,
  });

  final List<FreeChordGroup> groups;
  final int activeGroupId;
  final int? playingGroupId;
  final _NoteSwapSelection? noteSwapSource;
  final int? groupSwapSourceId;
  final bool audioReady;
  final bool isSequencePlaying;
  final bool jiMode;
  final ScrollController scrollController;
  final GlobalKey Function(int groupId) groupCardKey;
  final int edo;
  final VoidCallback onAddGroup;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<int> onPlayGroup;
  final ValueChanged<int> onSortGroup;
  final ValueChanged<int> onSwapGroup;
  final ValueChanged<int> onDeleteGroup;
  final void Function(int groupId, int step) onNoteTap;
  final void Function(int groupId, int step) onNoteLongPress;

  @override
  Widget build(BuildContext context) {
    final interactionHint = noteSwapSource != null
        ? '交换音：点击其他和弦组中的目标音'
        : groupSwapSourceId != null
        ? '交换整组：点击另一组的“交换整组”'
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChordleColors.surface,
        border: Border.all(color: ChordleColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSequencePlaying && interactionHint != null)
            Container(
              color: ChordleColors.selected.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                interactionHint,
                style: const TextStyle(
                  color: ChordleColors.selected,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: groups.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: isSequencePlaying ? 7 : 10),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _FreeChordGroupCard(
                  key: groupCardKey(group.id),
                  group: group,
                  groupNumber: index + 1,
                  edo: edo,
                  jiMode: jiMode,
                  compact: isSequencePlaying,
                  active: group.id == activeGroupId,
                  playing: group.id == playingGroupId,
                  groupSwapSelected: group.id == groupSwapSourceId,
                  noteSwapSource: noteSwapSource,
                  canDeleteGroup: groups.length > 1,
                  audioReady: audioReady,
                  onSelect: () => onSelectGroup(group.id),
                  onPlay: () => onPlayGroup(group.id),
                  onSort: () => onSortGroup(group.id),
                  onSwapGroup: () => onSwapGroup(group.id),
                  onDelete: () => onDeleteGroup(group.id),
                  onNoteTap: (toneId) => onNoteTap(group.id, toneId),
                  onNoteLongPress: (toneId) =>
                      onNoteLongPress(group.id, toneId),
                );
              },
            ),
          ),
          if (!isSequencePlaying) ...[
            const Divider(height: 1),
            SizedBox(
              height: 48,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: onAddGroup,
                  tooltip: '添加和弦',
                  icon: const Icon(Icons.add_rounded, size: 24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FreeChordGroupCard extends StatelessWidget {
  const _FreeChordGroupCard({
    required this.group,
    required this.groupNumber,
    required this.edo,
    required this.jiMode,
    required this.compact,
    required this.active,
    required this.playing,
    required this.groupSwapSelected,
    required this.noteSwapSource,
    required this.canDeleteGroup,
    required this.audioReady,
    required this.onSelect,
    required this.onPlay,
    required this.onSort,
    required this.onSwapGroup,
    required this.onDelete,
    required this.onNoteTap,
    required this.onNoteLongPress,
    super.key,
  });

  final FreeChordGroup group;
  final int groupNumber;
  final int edo;
  final bool jiMode;
  final bool compact;
  final bool active;
  final bool playing;
  final bool groupSwapSelected;
  final _NoteSwapSelection? noteSwapSource;
  final bool canDeleteGroup;
  final bool audioReady;
  final VoidCallback onSelect;
  final VoidCallback onPlay;
  final VoidCallback onSort;
  final VoidCallback onSwapGroup;
  final VoidCallback onDelete;
  final ValueChanged<int> onNoteTap;
  final ValueChanged<int> onNoteLongPress;

  @override
  Widget build(BuildContext context) {
    final borderColor = playing
        ? ChordleColors.yellow
        : groupSwapSelected
        ? ChordleColors.selected
        : active
        ? ChordleColors.green
        : ChordleColors.border;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? ChordleColors.elevatedSurface
            : ChordleColors.background,
        border: Border.all(color: borderColor, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 7 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '和弦 $groupNumber · ${group.length} 音',
                    style: const TextStyle(
                      color: ChordleColors.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (playing)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: ChordleColors.yellow,
                      size: 20,
                    ),
                  ),
                if (!compact) ...[
                  IconButton(
                    onPressed: audioReady && !group.isEmpty ? onPlay : null,
                    tooltip: '播放和弦 $groupNumber',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    onPressed: canDeleteGroup ? onDelete : null,
                    tooltip: '删除和弦组',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 21),
                  ),
                ],
              ],
            ),
            SizedBox(height: compact ? 4 : 7),
            if (group.isEmpty)
              InkWell(
                onTap: compact ? null : onSelect,
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 8 : 17,
                    horizontal: 8,
                  ),
                  child: const Text(
                    '从下方标尺选音并加入和弦',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ChordleColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 370 : 402),
                  child: GridView.builder(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.tones.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      mainAxisExtent: compact ? 56 : 66,
                    ),
                    itemBuilder: (context, index) {
                      final tone = group.tones[index];
                      return _FreeChordTile(
                        label: jiMode
                            ? frequencyLabel(tone.frequencyHz)
                            : tone.step < 0
                            ? '待随机'
                            : extraStepLabel(tone.step, edo),
                        ratioLabel: group.isRoot(tone)
                            ? '1/1 · 根音'
                            : tone.ratioLabel ?? (jiMode ? '' : '刻度尺'),
                        isRoot: group.isRoot(tone),
                        swapSource:
                            noteSwapSource?.groupId == group.id &&
                            noteSwapSource?.toneId == tone.id,
                        onTap: compact ? null : () => onNoteTap(tone.id),
                        onLongPress: compact
                            ? null
                            : () => onNoteLongPress(tone.id),
                      );
                    },
                  ),
                ),
              ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: active ? null : onSelect,
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: Text(active ? '正在编辑' : '编辑此组'),
                  ),
                  TextButton.icon(
                    onPressed: group.length >= 2 ? onSort : null,
                    icon: const Icon(Icons.sort_rounded, size: 18),
                    label: const Text('从低到高'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canDeleteGroup ? onSwapGroup : null,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: Text(groupSwapSelected ? '选择目标组' : '交换整组'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FreeChordTile extends StatelessWidget {
  const _FreeChordTile({
    required this.label,
    required this.ratioLabel,
    required this.isRoot,
    required this.swapSource,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final String ratioLabel;
  final bool isRoot;
  final bool swapSource;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: swapSource
          ? ChordleColors.selected.withValues(alpha: 0.24)
          : ChordleColors.elevatedSurface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: swapSource
              ? ChordleColors.selected
              : isRoot
              ? ChordleColors.yellow
              : ChordleColors.green,
          width: swapSource ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ChordleColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ratioLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isRoot
                            ? ChordleColors.yellow
                            : ChordleColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (swapSource)
              const Positioned(
                top: 3,
                right: 4,
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: ChordleColors.selected,
                  size: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FreeInputSwitcher extends StatefulWidget {
  const _FreeInputSwitcher({
    required this.mode,
    required this.compact,
    required this.onToggle,
    required this.child,
  });

  final _FreeInputMode mode;
  final bool compact;
  final VoidCallback onToggle;
  final Widget child;

  @override
  State<_FreeInputSwitcher> createState() => _FreeInputSwitcherState();
}

class _FreeInputSwitcherState extends State<_FreeInputSwitcher> {
  int? _pointer;
  Offset? _startPosition;
  var _multiplePointers = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      _multiplePointers = true;
      return;
    }
    _pointer = event.pointer;
    _startPosition = event.position;
    _multiplePointers = false;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final start = _startPosition;
    final delta = start == null ? Offset.zero : event.position - start;
    final shouldToggle =
        !_multiplePointers &&
        delta.dy.abs() >= 48 &&
        delta.dy.abs() > delta.dx.abs() * 1.25;
    _resetPointer();
    if (shouldToggle) widget.onToggle();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _resetPointer();
  }

  void _resetPointer() {
    _pointer = null;
    _startPosition = null;
    _multiplePointers = false;
  }

  @override
  Widget build(BuildContext context) {
    final ratioMode = widget.mode == _FreeInputMode.ratio;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: widget.compact ? 27 : 31,
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ChordleColors.surface,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(
                  ratioMode ? Icons.dialpad_rounded : Icons.straighten_rounded,
                  size: 17,
                  color: ChordleColors.selected,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    ratioMode ? '数字比例输入' : 'EDO 刻度尺输入',
                    style: const TextStyle(
                      color: ChordleColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.swap_vert_rounded,
                  size: 17,
                  color: ChordleColors.muted,
                ),
                const SizedBox(width: 4),
                const Text(
                  '上下滑动切换',
                  style: TextStyle(
                    color: ChordleColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

enum _FreeInputMode { ruler, ratio }

enum _FreePlaybackMode { sequential, random }

enum _NoteAction { delete, swap, setRoot, clearRoot }

final class _NoteSwapSelection {
  const _NoteSwapSelection(this.groupId, this.toneId);

  final int groupId;
  final int toneId;
}

final class _PlaybackChord {
  const _PlaybackChord.edo(this.groupId, this.steps) : frequencies = null;

  const _PlaybackChord.ji(this.groupId, this.frequencies) : steps = null;

  final int groupId;
  final List<int>? steps;
  final List<double>? frequencies;
}

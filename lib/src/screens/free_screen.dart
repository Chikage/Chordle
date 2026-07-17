import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/chord_game.dart';
import '../game/edo_ratio.dart';
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
  final ScrollController _groupScrollController = ScrollController();
  final ChordPuzzle _playbackContext = ChordPuzzle(
    notes: const <int>[],
    label: 'Free',
  );

  ChordleSettings _settings = const ChordleSettings();
  int? _selectedStep;
  var _inputMode = _FreeInputMode.ruler;
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

  IntRange get _range => sanitizeExtraPlayableRange(
    IntRange.sorted(_settings.extraLow, _settings.extraHigh),
  );

  int get _edo => sanitizeExtraEdo(_settings.extraEdo);

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

  Future<void> _playNow(
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

  Future<void> _playSequence({required bool randomOrder}) async {
    final playable = <_PlaybackChord>[
      for (final group in _collection.groups)
        if (!group.isEmpty) _PlaybackChord(group.id, List<int>.of(group.steps)),
    ];
    if (!_audioReady || playable.isEmpty) {
      _showMessage('请先至少设置一组非空和弦');
      return;
    }
    if (randomOrder) playable.shuffle(math.Random());

    final token = ++_playbackToken;
    setState(() {
      _isSequencePlaying = true;
      _playingGroupId = null;
    });

    for (final chord in playable) {
      if (!mounted || token != _playbackToken) return;
      setState(() => _playingGroupId = chord.groupId);
      await _audio.allSoundOff();
      if (!mounted || token != _playbackToken) return;
      await _playSteps(
        chord.steps,
        durationMs: _sequenceToneDuration.inMilliseconds,
      );
      await Future<void>.delayed(_sequenceToneDuration + _sequenceGap);
    }

    if (!mounted || token != _playbackToken) return;
    setState(() {
      _isSequencePlaying = false;
      _playingGroupId = null;
    });
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
    if (_settings.keyPitchPreviewEnabled && _audioReady) {
      unawaited(_playNow(<int>[step], velocity: 92, durationMs: 520));
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
    final root = group.rootTone;
    if (root == null) {
      _showMessage('请先长按当前和弦中的一个音，将其设为根音');
      return;
    }

    late final PositiveRatio ratio;
    try {
      ratio = parsePositiveRatio(_ratioInput);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }

    final relativeSteps = pureEdoStepsForRatio(ratio, _edo);
    final targetStep = root.step + relativeSteps;
    final playableSteps = extraStepRangeForMidiRange(_edo, _range);
    if (!playableSteps.contains(targetStep)) {
      _showMessage(
        '${ratio.label} 对应 ${relativeSteps >= 0 ? '+' : ''}$relativeSteps Step，超出当前音域',
      );
      return;
    }

    final existing = group.toneAtStep(targetStep);
    if (existing != null && group.isRoot(existing)) {
      _showMessage('${ratio.label} 在 $_edo EDO 中映射到根音（0 Step）');
      return;
    }

    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      if (existing == null) {
        _collection.addStep(group.id, targetStep, ratioLabel: ratio.label);
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
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.addStep(_collection.activeGroupId, step);
      _selectedStep = null;
    });
  }

  void _deleteLastStep() {
    if (_activeGroup.isEmpty) return;
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.deleteLastStep(_collection.activeGroupId);
      _ratioInput = '';
    });
  }

  void _clearActiveChord() {
    if (_activeGroup.isEmpty) return;
    setState(() {
      _cancelPlaybackForEdit();
      _clearSwapSelections();
      _collection.clearGroup(_collection.activeGroupId);
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
      _selectedStep = null;
      _ratioInput = '';
    });
  }

  void _sortGroup(int groupId) {
    setState(() {
      _cancelPlaybackForEdit();
      _noteSwapSource = null;
      _collection.sortGroup(groupId);
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

  Future<void> _showNoteActions(int groupId, int step) async {
    final groupPosition = _collection.groupPosition(groupId);
    final group = _collection.groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (groupPosition < 0 || group == null || tone == null) return;
    final isRoot = group.isRoot(tone);
    final label = extraStepLabel(step, _edo);
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
              subtitle: Text(isRoot ? '同时清除本组比例标签' : '该音将作为比例输入的 1/1'),
              onTap: () => Navigator.of(
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
          _collection.removeStep(groupId, step);
          _ratioInput = '';
        });
      case _NoteAction.swap:
        setState(() {
          _groupSwapSourceId = null;
          _noteSwapSource = _NoteSwapSelection(groupId, step);
        });
        _showMessage('请点击其他和弦组中要交换的音');
      case _NoteAction.setRoot:
        setState(() {
          _cancelPlaybackForEdit();
          _clearSwapSelections();
          _collection.setRoot(groupId, step);
          _ratioInput = '';
        });
        _showMessage('$label 已设为根音 1/1');
      case _NoteAction.clearRoot:
        setState(() {
          _cancelPlaybackForEdit();
          _clearSwapSelections();
          _collection.clearRoot(groupId);
          _ratioInput = '';
        });
        _showMessage('已取消根音并清除本组比例标签');
    }
  }

  void _handleNoteTap(int groupId, int step) {
    final source = _noteSwapSource;
    if (source == null) {
      unawaited(_playNow(<int>[step], velocity: 92, durationMs: 700));
      return;
    }
    if (source.groupId == groupId && source.step == step) {
      setState(() => _noteSwapSource = null);
      _showMessage('已取消音交换');
      return;
    }

    final firstTone = _collection
        .groupById(source.groupId)
        ?.toneAtStep(source.step);
    final secondTone = _collection.groupById(groupId)?.toneAtStep(step);
    final rebaseRatio =
        firstTone?.ratioLabel != null || secondTone?.ratioLabel != null;
    final playableSteps = extraStepRangeForMidiRange(_edo, _range);
    final result = _collection.swapSteps(
      firstGroupId: source.groupId,
      firstStep: source.step,
      secondGroupId: groupId,
      secondStep: step,
      stepsForRatio: (ratioLabel) =>
          pureEdoStepsForRatio(parsePositiveRatio(ratioLabel), _edo),
      isPlayable: playableSteps.contains,
    );
    switch (result) {
      case FreeNoteSwapResult.swapped:
        setState(() {
          _cancelPlaybackForEdit();
          _noteSwapSource = null;
          _ratioInput = '';
        });
        _showMessage(rebaseRatio ? '两个音已交换；比例音已按新组根音或最低音重新计算' : '两个音已交换');
      case FreeNoteSwapResult.sameGroup:
        _showMessage('只能与其他和弦组中的音交换');
      case FreeNoteSwapResult.sameNote:
        _showMessage('两个音相同，请选择其他音');
      case FreeNoteSwapResult.wouldDuplicate:
        _showMessage('按新组参考音重算后会产生重复音，请选择其他音');
      case FreeNoteSwapResult.outOfRange:
        _showMessage('按新组参考音重算后超出当前音域，请选择其他音');
      case FreeNoteSwapResult.missingGroupOrNote:
        setState(() => _noteSwapSource = null);
        _showMessage('原音已不存在，请重新选择');
    }
  }

  Future<void> _openSettings() async {
    _stopPlayback();
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
    final hadTones = _collection.totalToneCount > 0;
    var removedForRange = 0;

    setState(() {
      _settings = next;
      _selectedStep = null;
      _ratioInput = '';
      _clearSwapSelections();
      if (previousEdo != nextEdo) {
        _collection.clearAllSteps();
      } else {
        removedForRange = _collection.retainSteps(nextStepRange.contains);
      }
    });
    await _settingsService.save(next);
    if (!mounted) return;
    await _audio.prepare(next.instrumentProgram);
    if (!mounted) return;

    if (previousEdo != nextEdo && hadTones) {
      _showMessage('EDO 已更改，全部和弦组已清空');
    } else if (removedForRange > 0) {
      _showMessage('已移除新音域之外的音');
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
              '使用“添加和弦”建立多组和弦，先选择要编辑的组，再从 EDO 标尺加入音高。在输入区域上下滑动，可在刻度尺和数字比例键盘之间切换。\n\n'
              '长按组内的音可将它设为根音 1/1。随后输入 3/2、5/4 等比例并点“按比例加入”，会用纯 EDO 的逐质数取整算法计算相对 Step，并将音名与约分后的比例分行保留。\n\n'
              '长按音还可选择删除或进入跨组音交换；带比例标签的音进入新组后，会按新组根音重新计算，没有根音时改用该组最低音。每组的“从低到高”会排序组内音，“交换整组”需要依次选择两组。顺序播放按列表次序播放全部非空组；随机播放会打乱后各播放一次。\n\n'
              'Free 目前复用 Extra 的 1–72 EDO 输入标尺与设置，后续可独立扩展。',
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
                    detailText: '$_edo EDO · ${extraRangeLabel(_edo, _range)}',
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
      scrollController: _groupScrollController,
      edo: _edo,
      onAddGroup: _addGroup,
      onPlaySequential: () => unawaited(_playSequence(randomOrder: false)),
      onPlayRandom: () => unawaited(_playSequence(randomOrder: true)),
      onStop: _stopPlayback,
      onSelectGroup: _selectGroup,
      onPlayGroup: (groupId) {
        final group = _collection.groupById(groupId);
        if (group != null) unawaited(_playNow(group.steps));
      },
      onSortGroup: _sortGroup,
      onSwapGroup: _handleGroupSwap,
      onDeleteGroup: (groupId) => unawaited(_deleteGroup(groupId)),
      onNoteTap: _handleNoteTap,
      onNoteLongPress: (groupId, step) =>
          unawaited(_showNoteActions(groupId, step)),
    );
  }

  Widget _buildInput({required bool compact}) {
    final selected = _selectedStep;
    final group = _activeGroup;
    final valueColors = <int, Color>{
      for (final tone in group.tones)
        tone.step: group.isRoot(tone)
            ? ChordleColors.yellow
            : ChordleColors.green,
    };
    final labels = group.tones
        .map(
          (tone) => tone.ratioLabel == null
              ? extraStepLabel(tone.step, _edo)
              : '${extraStepLabel(tone.step, _edo)} ${tone.ratioLabel}',
        )
        .join('  ');
    final groupNumber = _collection.groupPosition(group.id) + 1;
    final root = group.rootTone;
    final ratioMode = _inputMode == _FreeInputMode.ratio;
    final selectedText = ratioMode
        ? root == null
              ? '比例输入 · 请先设置根音'
              : '根音 ${extraStepLabel(root.step, _edo)} · ${_ratioInput.isEmpty ? '输入比例' : _ratioInput}'
        : selected == null
        ? '未选 EDO 音'
        : '选中 ${extraStepLabel(selected, _edo)}';

    return GameInputPanel(
      selectedText: selectedText,
      confirmText: ratioMode ? '按比例加入' : '加入和弦',
      canConfirm: ratioMode
          ? root != null && _ratioInput.isNotEmpty
          : selected != null,
      canDelete: !group.isEmpty,
      canSubmit: !group.isEmpty,
      audioReady: _audioReady && !group.isEmpty,
      onPlayTarget: () => unawaited(_playNow(group.steps)),
      onConfirm: ratioMode ? _addRatioTone : _addSelectedStep,
      onDelete: _deleteLastStep,
      onSubmit: _clearActiveChord,
      answerText: group.isEmpty
          ? '正在编辑和弦 $groupNumber · 尚未加入音高'
          : '和弦 $groupNumber：$labels',
      submitText: '清空本组',
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
            selectedStep: selected,
            valueColors: valueColors,
            onStepPressed: _selectStep,
            compact: compact,
          ),
          _FreeInputMode.ratio => RatioNumberPad(
            value: _ratioInput,
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
    required this.scrollController,
    required this.edo,
    required this.onAddGroup,
    required this.onPlaySequential,
    required this.onPlayRandom,
    required this.onStop,
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
  final ScrollController scrollController;
  final int edo;
  final VoidCallback onAddGroup;
  final VoidCallback onPlaySequential;
  final VoidCallback onPlayRandom;
  final VoidCallback onStop;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<int> onPlayGroup;
  final ValueChanged<int> onSortGroup;
  final ValueChanged<int> onSwapGroup;
  final ValueChanged<int> onDeleteGroup;
  final void Function(int groupId, int step) onNoteTap;
  final void Function(int groupId, int step) onNoteLongPress;

  @override
  Widget build(BuildContext context) {
    final hasPlayableGroup = groups.any((group) => !group.isEmpty);
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
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAddGroup,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('添加和弦'),
                ),
                OutlinedButton.icon(
                  onPressed: audioReady && hasPlayableGroup
                      ? onPlaySequential
                      : null,
                  icon: const Icon(Icons.playlist_play_rounded, size: 20),
                  label: const Text('顺序播放'),
                ),
                OutlinedButton.icon(
                  onPressed: audioReady && hasPlayableGroup
                      ? onPlayRandom
                      : null,
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('随机播放'),
                ),
                OutlinedButton.icon(
                  onPressed: isSequencePlaying ? onStop : null,
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('停止'),
                ),
              ],
            ),
          ),
          if (interactionHint != null)
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
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _FreeChordGroupCard(
                  group: group,
                  groupNumber: index + 1,
                  edo: edo,
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
                  onNoteTap: (step) => onNoteTap(group.id, step),
                  onNoteLongPress: (step) => onNoteLongPress(group.id, step),
                );
              },
            ),
          ),
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
  });

  final FreeChordGroup group;
  final int groupNumber;
  final int edo;
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
        padding: const EdgeInsets.all(10),
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
            ),
            const SizedBox(height: 7),
            if (group.isEmpty)
              InkWell(
                onTap: onSelect,
                borderRadius: BorderRadius.circular(7),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 17, horizontal: 8),
                  child: Text(
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tone in group.tones)
                    _FreeChordTile(
                      label: extraStepLabel(tone.step, edo),
                      ratioLabel: group.isRoot(tone)
                          ? '${tone.ratioLabel ?? '1/1'} · 根音'
                          : tone.ratioLabel ?? '刻度尺',
                      isRoot: group.isRoot(tone),
                      swapSource:
                          noteSwapSource?.groupId == group.id &&
                          noteSwapSource?.step == tone.step,
                      onTap: () => onNoteTap(tone.step),
                      onLongPress: () => onNoteLongPress(tone.step),
                    ),
                ],
              ),
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
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      height: 66,
      child: Material(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          fontSize: 15,
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

enum _NoteAction { delete, swap, setRoot, clearRoot }

final class _NoteSwapSelection {
  const _NoteSwapSelection(this.groupId, this.step);

  final int groupId;
  final int step;
}

final class _PlaybackChord {
  const _PlaybackChord(this.groupId, this.steps);

  final int groupId;
  final List<int> steps;
}

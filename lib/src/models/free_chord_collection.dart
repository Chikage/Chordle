final class FreeChordTone {
  FreeChordTone._(
    this.id,
    this.step, {
    this.ratioLabel,
    this.frequencyHz,
    this.isAbsoluteAnchor = false,
  });

  final int id;
  int step;
  String? ratioLabel;
  double? frequencyHz;
  bool isAbsoluteAnchor;
}

final class FreeChordGroup {
  FreeChordGroup._(this.id);

  final int id;
  final List<FreeChordTone> _tones = <FreeChordTone>[];
  int? _rootToneId;

  List<FreeChordTone> get tones => List<FreeChordTone>.unmodifiable(_tones);
  List<int> get steps =>
      List<int>.unmodifiable(_tones.map((tone) => tone.step));
  FreeChordTone? get rootTone => toneById(_rootToneId);
  bool get isEmpty => _tones.isEmpty;
  int get length => _tones.length;

  FreeChordTone? toneById(int? toneId) {
    if (toneId == null) return null;
    for (final tone in _tones) {
      if (tone.id == toneId) return tone;
    }
    return null;
  }

  FreeChordTone? toneAtStep(int step) {
    for (final tone in _tones) {
      if (tone.step == step) return tone;
    }
    return null;
  }

  FreeChordTone? get lowestAbsoluteAnchor {
    FreeChordTone? lowest;
    for (final tone in _tones) {
      if (!tone.isAbsoluteAnchor || tone.frequencyHz == null) continue;
      if (lowest == null || tone.frequencyHz! < lowest.frequencyHz!) {
        lowest = tone;
      }
    }
    return lowest;
  }

  FreeChordTone? get lowestStepAnchor {
    FreeChordTone? lowest;
    for (final tone in _tones) {
      if (!tone.isAbsoluteAnchor && tone.ratioLabel != null) continue;
      if (lowest == null || tone.step < lowest.step) lowest = tone;
    }
    return lowest;
  }

  bool isRoot(FreeChordTone tone) => tone.id == _rootToneId;

  void _clearDerivedRatioLabels() {
    for (final tone in _tones) {
      tone.ratioLabel = null;
    }
  }
}

enum FreeNoteSwapResult {
  swapped,
  missingGroupOrNote,
  sameGroup,
  sameNote,
  wouldDuplicate,
  outOfRange,
}

final class FreeChordCollection {
  FreeChordCollection() {
    final first = _newGroup();
    _groups.add(first);
    _activeGroupId = first.id;
  }

  final List<FreeChordGroup> _groups = <FreeChordGroup>[];
  var _nextGroupId = 1;
  var _nextToneId = 1;
  late int _activeGroupId;

  List<FreeChordGroup> get groups => List<FreeChordGroup>.unmodifiable(_groups);
  int get activeGroupId => _activeGroupId;
  FreeChordGroup get activeGroup => groupById(_activeGroupId)!;
  int get totalToneCount =>
      _groups.fold(0, (total, group) => total + group._tones.length);

  FreeChordGroup? groupById(int groupId) {
    for (final group in _groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  int groupPosition(int groupId) =>
      _groups.indexWhere((group) => group.id == groupId);

  int addGroup() {
    final group = _newGroup();
    _groups.add(group);
    _activeGroupId = group.id;
    return group.id;
  }

  bool selectGroup(int groupId) {
    if (groupById(groupId) == null || groupId == _activeGroupId) return false;
    _activeGroupId = groupId;
    return true;
  }

  bool removeGroup(int groupId) {
    if (_groups.length <= 1) return false;
    final index = groupPosition(groupId);
    if (index < 0) return false;
    _groups.removeAt(index);
    if (_activeGroupId == groupId) {
      _activeGroupId = _groups[index.clamp(0, _groups.length - 1)].id;
    }
    return true;
  }

  bool addStep(
    int groupId,
    int step, {
    String? ratioLabel,
    double? frequencyHz,
    bool isAbsoluteAnchor = false,
  }) {
    final group = groupById(groupId);
    if (group == null || group.toneAtStep(step) != null) return false;
    group._tones.add(
      FreeChordTone._(
        _nextToneId++,
        step,
        ratioLabel: ratioLabel,
        frequencyHz: frequencyHz,
        isAbsoluteAnchor: isAbsoluteAnchor,
      ),
    );
    return true;
  }

  bool addJiRatioTone(
    int groupId, {
    required String ratioLabel,
    required int? approximateStep,
    required double? frequencyHz,
  }) => addRatioTone(
    groupId,
    ratioLabel: ratioLabel,
    resolvedStep: approximateStep,
    frequencyHz: frequencyHz,
  );

  bool addRatioTone(
    int groupId, {
    required String ratioLabel,
    required int? resolvedStep,
    double? frequencyHz,
  }) {
    final group = groupById(groupId);
    if (group == null ||
        group._tones.any((tone) => tone.ratioLabel == ratioLabel)) {
      return false;
    }
    final toneId = _nextToneId++;
    group._tones.add(
      FreeChordTone._(
        toneId,
        resolvedStep ?? -toneId,
        ratioLabel: ratioLabel,
        frequencyHz: frequencyHz,
      ),
    );
    return true;
  }

  bool setRatioLabel(int groupId, int step, String ratioLabel) {
    final group = groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (group == null || tone == null || group.isRoot(tone)) return false;
    tone.ratioLabel = ratioLabel;
    return true;
  }

  bool setRoot(int groupId, int step, {bool clearRatioLabels = true}) {
    final group = groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (group == null || tone == null) return false;
    group._rootToneId = tone.id;
    if (clearRatioLabels) {
      group._clearDerivedRatioLabels();
    } else {
      tone.ratioLabel = null;
    }
    return true;
  }

  bool setJiRoot(int groupId, int toneId) {
    final group = groupById(groupId);
    final tone = group?.toneById(toneId);
    if (group == null || tone == null || tone.frequencyHz == null) return false;
    group._rootToneId = tone.id;
    tone.ratioLabel = null;
    return true;
  }

  bool clearRoot(int groupId, {bool clearRatioLabels = true}) {
    final group = groupById(groupId);
    if (group == null || group._rootToneId == null) return false;
    group._rootToneId = null;
    if (clearRatioLabels) group._clearDerivedRatioLabels();
    return true;
  }

  bool deleteLastStep(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._tones.isEmpty) return false;
    _removeTone(group, group._tones.last, clearRatiosWhenRemovingRoot: true);
    return true;
  }

  bool removeStep(int groupId, int step) {
    final group = groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (group == null || tone == null) return false;
    _removeTone(group, tone, clearRatiosWhenRemovingRoot: true);
    return true;
  }

  bool removeToneById(
    int groupId,
    int toneId, {
    bool clearRatiosWhenRemovingRoot = true,
  }) {
    final group = groupById(groupId);
    final tone = group?.toneById(toneId);
    if (group == null || tone == null) return false;
    _removeTone(
      group,
      tone,
      clearRatiosWhenRemovingRoot: clearRatiosWhenRemovingRoot,
    );
    return true;
  }

  bool clearGroup(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._tones.isEmpty) return false;
    group._tones.clear();
    group._rootToneId = null;
    return true;
  }

  bool sortGroup(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._tones.length < 2) return false;
    final before = List<int>.of(group.steps);
    group._tones.sort((first, second) => first.step.compareTo(second.step));
    for (var index = 0; index < before.length; index += 1) {
      if (before[index] != group._tones[index].step) return true;
    }
    return false;
  }

  bool sortJiGroup(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._tones.length < 2) return false;
    final before = group._tones.map((tone) => tone.id).toList();
    group._tones.sort((first, second) {
      final firstFrequency = first.frequencyHz ?? double.infinity;
      final secondFrequency = second.frequencyHz ?? double.infinity;
      final frequencyOrder = firstFrequency.compareTo(secondFrequency);
      if (frequencyOrder != 0) return frequencyOrder;
      return first.id.compareTo(second.id);
    });
    return !_sameOrder(before, group._tones.map((tone) => tone.id));
  }

  bool swapGroups(int firstGroupId, int secondGroupId) {
    final firstIndex = groupPosition(firstGroupId);
    final secondIndex = groupPosition(secondGroupId);
    if (firstIndex < 0 || secondIndex < 0 || firstIndex == secondIndex) {
      return false;
    }
    final first = _groups[firstIndex];
    _groups[firstIndex] = _groups[secondIndex];
    _groups[secondIndex] = first;
    return true;
  }

  FreeNoteSwapResult swapSteps({
    required int firstGroupId,
    required int firstStep,
    required int secondGroupId,
    required int secondStep,
    int Function(String ratioLabel)? stepsForRatio,
    bool Function(int step)? isPlayable,
  }) {
    final firstGroup = groupById(firstGroupId);
    final secondGroup = groupById(secondGroupId);
    final firstTone = firstGroup?.toneAtStep(firstStep);
    final secondTone = secondGroup?.toneAtStep(secondStep);
    if (firstGroup == null ||
        secondGroup == null ||
        firstTone == null ||
        secondTone == null) {
      return FreeNoteSwapResult.missingGroupOrNote;
    }
    if (firstGroupId == secondGroupId) return FreeNoteSwapResult.sameGroup;
    if (firstStep == secondStep) return FreeNoteSwapResult.sameNote;

    final firstSnapshot = _GroupSnapshot(firstGroup);
    final secondSnapshot = _GroupSnapshot(secondGroup);
    final firstWasRoot = firstGroup.isRoot(firstTone);
    final secondWasRoot = secondGroup.isRoot(secondTone);
    final firstContent = _ToneContent(firstTone);
    final secondContent = _ToneContent(secondTone);
    firstContent.applyTo(secondTone);
    secondContent.applyTo(firstTone);
    if (firstWasRoot) firstGroup._rootToneId = null;
    if (secondWasRoot) secondGroup._rootToneId = null;

    FreeNoteSwapResult validateRawGroup(FreeChordGroup group) {
      final resolved = group._tones.where((tone) => tone.step >= 0).toList();
      if (isPlayable != null &&
          resolved.any((tone) => !isPlayable(tone.step))) {
        return FreeNoteSwapResult.outOfRange;
      }
      for (var first = 0; first < resolved.length; first += 1) {
        for (var second = first + 1; second < resolved.length; second += 1) {
          if (resolved[first].step == resolved[second].step) {
            return FreeNoteSwapResult.wouldDuplicate;
          }
        }
      }
      return FreeNoteSwapResult.swapped;
    }

    final firstResult = stepsForRatio == null
        ? validateRawGroup(firstGroup)
        : _applyEdoReference(
            firstGroup,
            stepsForRatio: stepsForRatio,
            isPlayable: isPlayable ?? (_) => true,
          );
    final secondResult = stepsForRatio == null
        ? validateRawGroup(secondGroup)
        : _applyEdoReference(
            secondGroup,
            stepsForRatio: stepsForRatio,
            isPlayable: isPlayable ?? (_) => true,
          );
    final result = firstResult != FreeNoteSwapResult.swapped
        ? firstResult
        : secondResult;
    if (result != FreeNoteSwapResult.swapped) {
      firstSnapshot.restore(firstGroup);
      secondSnapshot.restore(secondGroup);
    }
    return result;
  }

  FreeNoteSwapResult swapJiTones({
    required int firstGroupId,
    required int firstToneId,
    required int secondGroupId,
    required int secondToneId,
    required double Function(String ratioLabel) ratioValue,
    required int Function(double frequencyHz) approximateStep,
    required bool Function(double frequencyHz) isPlayable,
  }) {
    final firstGroup = groupById(firstGroupId);
    final secondGroup = groupById(secondGroupId);
    final firstTone = firstGroup?.toneById(firstToneId);
    final secondTone = secondGroup?.toneById(secondToneId);
    if (firstGroup == null ||
        secondGroup == null ||
        firstTone == null ||
        secondTone == null) {
      return FreeNoteSwapResult.missingGroupOrNote;
    }
    if (firstGroupId == secondGroupId) return FreeNoteSwapResult.sameGroup;
    if (firstToneId == secondToneId) return FreeNoteSwapResult.sameNote;

    final firstSnapshot = _GroupSnapshot(firstGroup);
    final secondSnapshot = _GroupSnapshot(secondGroup);
    final firstWasRoot = firstGroup.isRoot(firstTone);
    final secondWasRoot = secondGroup.isRoot(secondTone);

    final firstContent = _ToneContent(firstTone);
    final secondContent = _ToneContent(secondTone);
    firstContent.applyTo(secondTone);
    secondContent.applyTo(firstTone);
    if (firstWasRoot) firstGroup._rootToneId = null;
    if (secondWasRoot) secondGroup._rootToneId = null;

    final firstResult = _applyJiReference(
      firstGroup,
      ratioValue: ratioValue,
      approximateStep: approximateStep,
      isPlayable: isPlayable,
    );
    final secondResult = _applyJiReference(
      secondGroup,
      ratioValue: ratioValue,
      approximateStep: approximateStep,
      isPlayable: isPlayable,
    );
    final result = firstResult != FreeNoteSwapResult.swapped
        ? firstResult
        : secondResult;
    if (result != FreeNoteSwapResult.swapped) {
      firstSnapshot.restore(firstGroup);
      secondSnapshot.restore(secondGroup);
    }
    return result;
  }

  FreeNoteSwapResult recalculateJiGroup({
    required int groupId,
    required double Function(String ratioLabel) ratioValue,
    required int Function(double frequencyHz) approximateStep,
    required bool Function(double frequencyHz) isPlayable,
    double? fallbackReferenceHz,
  }) {
    final group = groupById(groupId);
    if (group == null) return FreeNoteSwapResult.missingGroupOrNote;
    final snapshot = _GroupSnapshot(group);
    final result = _applyJiReference(
      group,
      ratioValue: ratioValue,
      approximateStep: approximateStep,
      isPlayable: isPlayable,
      fallbackReferenceHz: fallbackReferenceHz,
    );
    if (result != FreeNoteSwapResult.swapped) snapshot.restore(group);
    return result;
  }

  FreeNoteSwapResult recalculateEdoGroup({
    required int groupId,
    required int Function(String ratioLabel) stepsForRatio,
    required bool Function(int step) isPlayable,
    int? fallbackReferenceStep,
  }) {
    final group = groupById(groupId);
    if (group == null) return FreeNoteSwapResult.missingGroupOrNote;
    final snapshot = _GroupSnapshot(group);
    final result = _applyEdoReference(
      group,
      stepsForRatio: stepsForRatio,
      isPlayable: isPlayable,
      fallbackReferenceStep: fallbackReferenceStep,
    );
    if (result != FreeNoteSwapResult.swapped) snapshot.restore(group);
    return result;
  }

  int clearAllSteps() {
    final removed = totalToneCount;
    for (final group in _groups) {
      group._tones.clear();
      group._rootToneId = null;
    }
    return removed;
  }

  int retainSteps(bool Function(int step) keep) {
    var removed = 0;
    for (final group in _groups) {
      final root = group.rootTone;
      final rootRemoved = root != null && !keep(root.step);
      final before = group._tones.length;
      group._tones.removeWhere((tone) => !keep(tone.step));
      removed += before - group._tones.length;
      if (rootRemoved) {
        group._rootToneId = null;
        group._clearDerivedRatioLabels();
      }
    }
    return removed;
  }

  FreeNoteSwapResult _applyJiReference(
    FreeChordGroup group, {
    required double Function(String ratioLabel) ratioValue,
    required int Function(double frequencyHz) approximateStep,
    required bool Function(double frequencyHz) isPlayable,
    double? fallbackReferenceHz,
  }) {
    final referenceHz =
        group.rootTone?.frequencyHz ??
        group.lowestAbsoluteAnchor?.frequencyHz ??
        fallbackReferenceHz;
    for (final tone in group._tones) {
      final label = tone.ratioLabel;
      if (label == null) continue;
      if (referenceHz == null) {
        tone
          ..frequencyHz = null
          ..step = -tone.id;
        continue;
      }
      final frequency = referenceHz * ratioValue(label);
      if (!isPlayable(frequency)) return FreeNoteSwapResult.outOfRange;
      tone
        ..frequencyHz = frequency
        ..step = approximateStep(frequency)
        ..isAbsoluteAnchor = false;
    }

    final resolved = group._tones
        .where((tone) => tone.frequencyHz != null)
        .toList(growable: false);
    for (var first = 0; first < resolved.length; first += 1) {
      for (var second = first + 1; second < resolved.length; second += 1) {
        final firstHz = resolved[first].frequencyHz!;
        final secondHz = resolved[second].frequencyHz!;
        if ((firstHz - secondHz).abs() <= 0.000001) {
          return FreeNoteSwapResult.wouldDuplicate;
        }
      }
    }
    return FreeNoteSwapResult.swapped;
  }

  FreeNoteSwapResult _applyEdoReference(
    FreeChordGroup group, {
    required int Function(String ratioLabel) stepsForRatio,
    required bool Function(int step) isPlayable,
    int? fallbackReferenceStep,
  }) {
    final referenceStep =
        group.rootTone?.step ??
        group.lowestStepAnchor?.step ??
        fallbackReferenceStep;
    for (final tone in group._tones) {
      final label = tone.ratioLabel;
      if (label == null) continue;
      if (referenceStep == null) {
        tone
          ..step = -tone.id
          ..frequencyHz = null
          ..isAbsoluteAnchor = false;
        continue;
      }
      final step = referenceStep + stepsForRatio(label);
      if (!isPlayable(step)) return FreeNoteSwapResult.outOfRange;
      tone
        ..step = step
        ..frequencyHz = null
        ..isAbsoluteAnchor = false;
    }

    final resolved = group._tones
        .where((tone) => isPlayable(tone.step))
        .toList(growable: false);
    for (var first = 0; first < resolved.length; first += 1) {
      for (var second = first + 1; second < resolved.length; second += 1) {
        if (resolved[first].step == resolved[second].step) {
          return FreeNoteSwapResult.wouldDuplicate;
        }
      }
    }
    return FreeNoteSwapResult.swapped;
  }

  void _removeTone(
    FreeChordGroup group,
    FreeChordTone tone, {
    required bool clearRatiosWhenRemovingRoot,
  }) {
    final removedRoot = group.isRoot(tone);
    group._tones.remove(tone);
    if (removedRoot) {
      group._rootToneId = null;
      if (clearRatiosWhenRemovingRoot) group._clearDerivedRatioLabels();
    }
  }

  FreeChordGroup _newGroup() => FreeChordGroup._(_nextGroupId++);
}

final class _ToneContent {
  _ToneContent(FreeChordTone tone)
    : step = tone.step,
      ratioLabel = tone.ratioLabel,
      frequencyHz = tone.frequencyHz,
      isAbsoluteAnchor = tone.isAbsoluteAnchor;

  final int step;
  final String? ratioLabel;
  final double? frequencyHz;
  final bool isAbsoluteAnchor;

  void applyTo(FreeChordTone tone) {
    tone
      ..step = step
      ..ratioLabel = ratioLabel
      ..frequencyHz = frequencyHz
      ..isAbsoluteAnchor = isAbsoluteAnchor;
  }
}

final class _GroupSnapshot {
  _GroupSnapshot(FreeChordGroup group)
    : rootToneId = group._rootToneId,
      contents = <int, _ToneContent>{
        for (final tone in group._tones) tone.id: _ToneContent(tone),
      };

  final int? rootToneId;
  final Map<int, _ToneContent> contents;

  void restore(FreeChordGroup group) {
    group._rootToneId = rootToneId;
    for (final tone in group._tones) {
      contents[tone.id]?.applyTo(tone);
    }
  }
}

bool _sameOrder(List<int> first, Iterable<int> second) {
  final other = second.toList(growable: false);
  if (first.length != other.length) return false;
  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != other[index]) return false;
  }
  return true;
}

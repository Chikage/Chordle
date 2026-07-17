final class FreeChordTone {
  FreeChordTone._(this.id, this.step, {this.ratioLabel});

  final int id;
  int step;
  String? ratioLabel;
}

final class FreeChordGroup {
  FreeChordGroup._(this.id);

  final int id;
  final List<FreeChordTone> _tones = <FreeChordTone>[];
  int? _rootToneId;

  List<FreeChordTone> get tones => List<FreeChordTone>.unmodifiable(_tones);
  List<int> get steps =>
      List<int>.unmodifiable(_tones.map((tone) => tone.step));
  FreeChordTone? get rootTone => _toneById(_rootToneId);
  bool get isEmpty => _tones.isEmpty;
  int get length => _tones.length;

  FreeChordTone? toneAtStep(int step) {
    for (final tone in _tones) {
      if (tone.step == step) return tone;
    }
    return null;
  }

  bool isRoot(FreeChordTone tone) => tone.id == _rootToneId;

  FreeChordTone? _toneById(int? toneId) {
    if (toneId == null) return null;
    for (final tone in _tones) {
      if (tone.id == toneId) return tone;
    }
    return null;
  }

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

  bool addStep(int groupId, int step, {String? ratioLabel}) {
    final group = groupById(groupId);
    if (group == null || group.toneAtStep(step) != null) return false;
    group._tones.add(
      FreeChordTone._(_nextToneId++, step, ratioLabel: ratioLabel),
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

  bool setRoot(int groupId, int step) {
    final group = groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (group == null || tone == null) return false;
    group._rootToneId = tone.id;
    group._clearDerivedRatioLabels();
    return true;
  }

  bool clearRoot(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._rootToneId == null) return false;
    group._rootToneId = null;
    group._clearDerivedRatioLabels();
    return true;
  }

  bool deleteLastStep(int groupId) {
    final group = groupById(groupId);
    if (group == null || group._tones.isEmpty) return false;
    _removeTone(group, group._tones.last);
    return true;
  }

  bool removeStep(int groupId, int step) {
    final group = groupById(groupId);
    final tone = group?.toneAtStep(step);
    if (group == null || tone == null) return false;
    _removeTone(group, tone);
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
    if (firstGroup == null || secondGroup == null) {
      return FreeNoteSwapResult.missingGroupOrNote;
    }
    if (firstGroupId == secondGroupId) return FreeNoteSwapResult.sameGroup;
    if (firstStep == secondStep) return FreeNoteSwapResult.sameNote;

    final firstTone = firstGroup.toneAtStep(firstStep);
    final secondTone = secondGroup.toneAtStep(secondStep);
    if (firstTone == null || secondTone == null) {
      return FreeNoteSwapResult.missingGroupOrNote;
    }
    final firstRatio = firstTone.ratioLabel;
    final secondRatio = secondTone.ratioLabel;
    final firstRootRemoved = firstGroup.isRoot(firstTone);
    final secondRootRemoved = secondGroup.isRoot(secondTone);

    int destinationReference(
      FreeChordGroup group,
      FreeChordTone incomingSlot,
      int provisionalIncomingStep,
      bool rootRemoved,
    ) {
      final root = rootRemoved ? null : group.rootTone;
      if (root != null && root.id != incomingSlot.id) return root.step;

      int? lowest;
      for (final tone in group._tones) {
        if (tone.id == incomingSlot.id) continue;
        if (lowest == null || tone.step < lowest) lowest = tone.step;
      }
      return lowest ?? provisionalIncomingStep;
    }

    int recalculatedStep(
      String? ratioLabel,
      int provisionalStep,
      int referenceStep,
    ) {
      if (ratioLabel == null || stepsForRatio == null) return provisionalStep;
      return referenceStep + stepsForRatio(ratioLabel);
    }

    final nextFirstStep = recalculatedStep(
      secondRatio,
      secondStep,
      destinationReference(firstGroup, firstTone, secondStep, firstRootRemoved),
    );
    final nextSecondStep = recalculatedStep(
      firstRatio,
      firstStep,
      destinationReference(
        secondGroup,
        secondTone,
        firstStep,
        secondRootRemoved,
      ),
    );

    if ((isPlayable != null && !isPlayable(nextFirstStep)) ||
        (isPlayable != null && !isPlayable(nextSecondStep))) {
      return FreeNoteSwapResult.outOfRange;
    }
    if (firstGroup._tones.any(
          (tone) => tone.id != firstTone.id && tone.step == nextFirstStep,
        ) ||
        secondGroup._tones.any(
          (tone) => tone.id != secondTone.id && tone.step == nextSecondStep,
        )) {
      return FreeNoteSwapResult.wouldDuplicate;
    }

    if (firstRootRemoved) {
      firstGroup._rootToneId = null;
      firstGroup._clearDerivedRatioLabels();
    }
    if (secondRootRemoved) {
      secondGroup._rootToneId = null;
      secondGroup._clearDerivedRatioLabels();
    }
    firstTone
      ..step = nextFirstStep
      ..ratioLabel = secondRatio;
    secondTone
      ..step = nextSecondStep
      ..ratioLabel = firstRatio;
    return FreeNoteSwapResult.swapped;
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

  void _removeTone(FreeChordGroup group, FreeChordTone tone) {
    final removedRoot = group.isRoot(tone);
    group._tones.remove(tone);
    if (removedRoot) {
      group._rootToneId = null;
      group._clearDerivedRatioLabels();
    }
  }

  FreeChordGroup _newGroup() => FreeChordGroup._(_nextGroupId++);
}

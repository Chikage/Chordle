import 'package:chordle/src/game/edo_ratio.dart';
import 'package:chordle/src/models/free_chord_collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manages multiple chord groups and active selection', () {
    final collection = FreeChordCollection();
    final firstId = collection.activeGroupId;

    collection.addStep(firstId, 96);
    final secondId = collection.addGroup();
    collection.addStep(secondId, 104);

    expect(collection.groups.length, 2);
    expect(collection.activeGroupId, secondId);
    expect(collection.groupById(firstId)?.steps, <int>[96]);
    expect(collection.groupById(secondId)?.steps, <int>[104]);
    expect(collection.totalToneCount, 2);
  });

  test('sorts notes inside one chord from low to high', () {
    final collection = FreeChordCollection();
    final groupId = collection.activeGroupId;
    collection.addStep(groupId, 108);
    collection.addStep(groupId, 96);
    collection.addStep(groupId, 102);

    expect(collection.sortGroup(groupId), isTrue);
    expect(collection.activeGroup.steps, <int>[96, 102, 108]);
  });

  test('tracks one root and clears stale ratio labels when root changes', () {
    final collection = FreeChordCollection();
    final groupId = collection.activeGroupId;
    collection.addStep(groupId, 96);
    collection.addStep(groupId, 103);

    expect(collection.setRoot(groupId, 96), isTrue);
    expect(collection.activeGroup.rootTone?.step, 96);
    expect(collection.activeGroup.rootTone?.ratioLabel, isNull);
    expect(collection.setRatioLabel(groupId, 103, '3/2'), isTrue);
    expect(collection.activeGroup.toneAtStep(103)?.ratioLabel, '3/2');

    expect(collection.setRoot(groupId, 103), isTrue);
    expect(collection.activeGroup.rootTone?.step, 103);
    expect(collection.activeGroup.toneAtStep(96)?.ratioLabel, isNull);
    expect(collection.activeGroup.rootTone?.ratioLabel, isNull);
  });

  test('removing the root clears the remaining ratio labels', () {
    final collection = FreeChordCollection();
    final groupId = collection.activeGroupId;
    collection.addStep(groupId, 96);
    collection.addStep(groupId, 103, ratioLabel: '3/2');
    collection.setRoot(groupId, 96);
    collection.setRatioLabel(groupId, 103, '3/2');

    expect(collection.removeStep(groupId, 96), isTrue);
    expect(collection.activeGroup.rootTone, isNull);
    expect(collection.activeGroup.toneAtStep(103)?.ratioLabel, isNull);
  });

  test('swaps notes between groups while preventing duplicates', () {
    final collection = FreeChordCollection();
    final firstId = collection.activeGroupId;
    collection.addStep(firstId, 96);
    collection.addStep(firstId, 100);
    final secondId = collection.addGroup();
    collection.addStep(secondId, 104);
    collection.addStep(secondId, 108);

    expect(
      collection.swapSteps(
        firstGroupId: firstId,
        firstStep: 96,
        secondGroupId: secondId,
        secondStep: 104,
      ),
      FreeNoteSwapResult.swapped,
    );
    expect(collection.groupById(firstId)?.steps, <int>[104, 100]);
    expect(collection.groupById(secondId)?.steps, <int>[96, 108]);

    collection.addStep(firstId, 108);
    expect(
      collection.swapSteps(
        firstGroupId: firstId,
        firstStep: 104,
        secondGroupId: secondId,
        secondStep: 108,
      ),
      FreeNoteSwapResult.wouldDuplicate,
    );
  });

  test('rebases a transferred ratio tone to the destination root', () {
    final collection = FreeChordCollection();
    final firstId = collection.activeGroupId;
    collection.addStep(firstId, 100);
    collection.addStep(firstId, 114, ratioLabel: '3/2');
    collection.setRoot(firstId, 100);
    collection.setRatioLabel(firstId, 114, '3/2');

    final secondId = collection.addGroup();
    collection.addStep(secondId, 120);
    collection.addStep(secondId, 130);
    collection.setRoot(secondId, 120);

    expect(
      collection.swapSteps(
        firstGroupId: firstId,
        firstStep: 114,
        secondGroupId: secondId,
        secondStep: 130,
        stepsForRatio: (label) =>
            pureEdoStepsForRatio(parsePositiveRatio(label), 24),
        isPlayable: (_) => true,
      ),
      FreeNoteSwapResult.swapped,
    );
    expect(collection.groupById(firstId)?.toneAtStep(130)?.ratioLabel, isNull);
    expect(collection.groupById(secondId)?.toneAtStep(134)?.ratioLabel, '3/2');
  });

  test(
    'rebases a transferred ratio tone to the lowest tone without a root',
    () {
      final collection = FreeChordCollection();
      final firstId = collection.activeGroupId;
      collection.addStep(firstId, 60);
      collection.addStep(firstId, 67, ratioLabel: '3/2');
      collection.setRoot(firstId, 60);
      collection.setRatioLabel(firstId, 67, '3/2');

      final secondId = collection.addGroup();
      collection.addStep(secondId, 72);
      collection.addStep(secondId, 80);

      expect(
        collection.swapSteps(
          firstGroupId: firstId,
          firstStep: 67,
          secondGroupId: secondId,
          secondStep: 80,
          stepsForRatio: (label) =>
              pureEdoStepsForRatio(parsePositiveRatio(label), 12),
          isPlayable: (_) => true,
        ),
        FreeNoteSwapResult.swapped,
      );
      expect(collection.groupById(secondId)?.toneAtStep(79)?.ratioLabel, '3/2');
    },
  );

  test('swaps whole chord positions without changing the active group', () {
    final collection = FreeChordCollection();
    final firstId = collection.activeGroupId;
    final secondId = collection.addGroup();

    expect(collection.swapGroups(firstId, secondId), isTrue);
    expect(collection.groups.map((group) => group.id), <int>[
      secondId,
      firstId,
    ]);
    expect(collection.activeGroupId, secondId);
  });
}

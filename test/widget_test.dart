import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordle/src/app.dart';
import 'package:chordle/src/screens/mode_selection_screen.dart';
import 'package:chordle/src/theme.dart';
import 'package:chordle/src/widgets/chord_board.dart';
import 'package:chordle/src/widgets/microtonal_keyboard.dart';

void main() {
  testWidgets('shows all four Chordle modes', (tester) async {
    await tester.pumpWidget(const ChordleApp());

    expect(find.text('Chordle'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Extra'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Overtones'), findsOneWidget);
  });

  testWidgets('opens the Free chord editor from the home screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'loadSettings' => <String, Object>{},
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const ChordleApp());

    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();

    expect(find.text('加入和弦'), findsOneWidget);
    expect(find.text('添加和弦'), findsOneWidget);
    expect(find.text('顺序播放'), findsOneWidget);
    expect(find.text('随机播放'), findsOneWidget);
    expect(find.text('播放和弦'), findsOneWidget);
    expect(find.text('停止播放'), findsNothing);
    expect(find.text('从下方标尺选音并加入和弦'), findsOneWidget);
    expect(find.text('EDO 刻度尺输入'), findsOneWidget);

    await tester.tap(find.text('随机播放'));
    await tester.pump();
    expect(find.text('停止播放'), findsNothing);

    await tester.drag(find.text('EDO 刻度尺输入'), const Offset(0, -80));
    await tester.pump();

    expect(find.text('数字比例输入'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('按比例加入'), findsOneWidget);

    await tester.tap(find.text('添加和弦'));
    await tester.pump();

    expect(find.textContaining('和弦 2'), findsWidgets);
  });

  testWidgets('Free always previews the full ruler and hides range settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var previewCalls = 0;
    Map<Object?, Object?>? savedSettings;
    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'playTones') previewCalls += 1;
          if (call.method == 'saveSettings') {
            savedSettings = call.arguments! as Map<Object?, Object?>;
          }
          return switch (call.method) {
            'loadSettings' => <String, Object>{
              'extraLow': 48,
              'extraHigh': 60,
              'keyPitchPreviewEnabled': false,
            },
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const ChordleApp());
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();

    final keyboard = tester.widget<MicrotonalKeyboard>(
      find.byType(MicrotonalKeyboard),
    );
    expect(keyboard.lowMidi, 21);
    expect(keyboard.highMidi, 108);
    expect(keyboard.initialCenterMidi, 60);

    await tester.tapAt(tester.getCenter(find.byType(MicrotonalKeyboard)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(previewCalls, 1);
    expect(find.text('选中 C4'), findsOneWidget);

    await tester.tap(find.byTooltip('游戏设置'));
    await tester.pumpAndSettle();

    expect(find.text('JI 精确比例模式'), findsOneWidget);
    expect(find.text('选择按键时预听音高'), findsNothing);
    expect(find.textContaining('音域两端'), findsNothing);
    expect(find.byType(RangeSlider), findsNothing);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings?['extraLow'], 48);
    expect(savedSettings?['extraHigh'], 60);
    expect(savedSettings?['keyPitchPreviewEnabled'], false);
  });

  testWidgets('adds a ratio-derived tone from a selected root', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'loadSettings' => <String, Object>{},
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const ChordleApp());
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();

    final keyboard = tester.widget<MicrotonalKeyboard>(
      find.byType(MicrotonalKeyboard),
    );
    keyboard.onStepPressed(110);
    await tester.pump();
    await tester.tap(find.text('加入和弦'));
    await tester.pump();
    await tester.longPress(find.text('刻度尺'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为根音'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.drag(find.text('EDO 刻度尺输入'), const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('/'));
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('按比例加入'));
    await tester.pump();

    expect(find.text('3/2'), findsOneWidget);
    expect(find.text('添加和弦'), findsOneWidget);
    expect(find.text('正在编辑'), findsOneWidget);
    expect(find.text('从低到高'), findsOneWidget);
    expect(find.byTooltip('播放和弦 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放和弦'));
    await tester.pump();
    expect(find.text('停止播放'), findsOneWidget);
    expect(find.text('添加和弦'), findsNothing);
    expect(find.text('正在编辑'), findsNothing);
    expect(find.text('从低到高'), findsNothing);
    expect(find.byTooltip('播放和弦 1'), findsNothing);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);

    await tester.tap(find.text('停止播放'));
    await tester.pump();
    expect(find.text('播放和弦'), findsOneWidget);
    expect(find.text('添加和弦'), findsOneWidget);
    expect(find.text('正在编辑'), findsOneWidget);
    expect(find.text('从低到高'), findsOneWidget);
    expect(find.byTooltip('播放和弦 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Free playback scrolls to the chord currently being played', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'loadSettings' => <String, Object>{},
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const ChordleApp());
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 6; index++) {
      if (index > 0) {
        await tester.tap(find.text('添加和弦'));
        await tester.pumpAndSettle();
      }
      final keyboard = tester.widget<MicrotonalKeyboard>(
        find.byType(MicrotonalKeyboard),
      );
      keyboard.onStepPressed(100 + index);
      await tester.pump();
      await tester.tap(find.text('加入和弦'));
      await tester.pump();
    }

    final listView = tester.widget<ListView>(find.byType(ListView));
    final scrollController = listView.controller!;
    scrollController.jumpTo(0);
    await tester.pump();

    await tester.tap(find.text('播放和弦'));
    await tester.pump();
    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(scrollController.offset, greaterThan(0));
    final playingIndicator = find.byIcon(Icons.graphic_eq_rounded);
    expect(playingIndicator, findsOneWidget);
    final listRect = tester.getRect(find.byType(ListView));
    final indicatorCenter = tester.getCenter(playingIndicator);
    expect(indicatorCenter.dy, greaterThanOrEqualTo(listRect.top));
    expect(indicatorCenter.dy, lessThanOrEqualTo(listRect.bottom));

    await tester.tap(find.text('停止播放'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'EDO ratio-only chords loop with changing implicit roots globally and per group',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final playedChords = <List<Object?>>[];
      const channel = MethodChannel('icu.ringona.chordle/platform');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'playTones') {
              final arguments = call.arguments! as Map<Object?, Object?>;
              playedChords.add(
                List<Object?>.of(arguments['tones']! as List<Object?>),
              );
            }
            return switch (call.method) {
              'loadSettings' => <String, Object>{},
              'prepareAudio' => true,
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      String signature(List<Object?> chord) {
        final tone = chord.single! as Map<Object?, Object?>;
        return '${tone['key']}:${(tone['cents']! as num).toStringAsFixed(5)}';
      }

      await tester.pumpWidget(const ChordleApp());
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('EDO 刻度尺输入'), const Offset(0, -80));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.tap(find.text('/'));
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('按比例加入'));
      await tester.pump();

      expect(find.text('待随机'), findsOneWidget);
      expect(find.text('3/2'), findsOneWidget);

      await tester.tap(find.text('播放和弦'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(playedChords, hasLength(greaterThanOrEqualTo(2)));
      expect(playedChords[0], hasLength(1));
      expect(playedChords[1], hasLength(1));
      expect(signature(playedChords[1]), isNot(signature(playedChords[0])));

      await tester.tap(find.text('停止播放'));
      await tester.pump();
      playedChords.clear();

      await tester.tap(find.byTooltip('播放和弦 1'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(playedChords, hasLength(greaterThanOrEqualTo(2)));
      expect(signature(playedChords[1]), isNot(signature(playedChords[0])));
      expect(find.text('停止播放'), findsOneWidget);

      await tester.tap(find.text('停止播放'));
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('JI mode plays an unrooted ratio with an implicit random root', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playedChords = <List<Object?>>[];
    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'playTones') {
            final arguments = call.arguments! as Map<Object?, Object?>;
            playedChords.add(
              List<Object?>.of(arguments['tones']! as List<Object?>),
            );
          }
          return switch (call.method) {
            'loadSettings' => <String, Object>{},
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const ChordleApp());
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('游戏设置'));
    await tester.pumpAndSettle();

    expect(find.text('JI 精确比例模式'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('JI 精确比例 · A0–C8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.drag(find.text('EDO 刻度尺输入'), const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('/'));
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('按比例加入'));
    await tester.pump();

    expect(find.text('待随机'), findsOneWidget);
    expect(find.text('3/2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放和弦'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(playedChords, hasLength(greaterThanOrEqualTo(2)));
    expect(playedChords[0], hasLength(1));
    expect(playedChords[1], hasLength(1));
    expect(playedChords[1], isNot(equals(playedChords[0])));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.endsWith('Hz'),
      ),
      findsWidgets,
    );

    await tester.tap(find.text('停止播放'));
    await tester.pump(const Duration(seconds: 2));
  });

  for (final (platform, fontFamily) in <(TargetPlatform, String)>[
    (TargetPlatform.android, 'serif'),
    (TargetPlatform.iOS, '.AppleSystemUIFontSerif'),
  ]) {
    testWidgets('uses the native $platform serif wordmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildChordleTheme().copyWith(platform: platform),
          home: ModeSelectionScreen(
            onModeSelected: (_) {},
            onFreeSelected: () {},
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('Chordle'));
      expect(title.style?.fontFamily, fontFamily);
      expect(title.style?.fontWeight, FontWeight.w900);
    });
  }

  testWidgets('ten-column board fits a narrow phone viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 359,
              height: 180,
              child: ChordBoard(
                rows: 6,
                columns: 10,
                currentRow: 0,
                currentColumn: 0,
                isPlaying: true,
                cellAt: (_, _) =>
                    const BoardCellViewData(kind: BoardTileKind.empty),
                canSortRow: (_) => false,
                onSortRow: (_) {},
                canPlayRow: (_) => false,
                onPlayRow: (_) {},
                canPlayCell: (_, _) => false,
                onPlayCell: (_, _, _) {},
                canAcceptDrag: (_, _, _) => false,
                onCarryCorrect: (_) {},
                onMovePresent: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

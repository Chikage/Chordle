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
    expect(find.text('从下方标尺选音并加入和弦'), findsOneWidget);
    expect(find.text('EDO 刻度尺输入'), findsOneWidget);

    await tester.drag(find.text('EDO 刻度尺输入'), const Offset(0, -80));
    await tester.pump();

    expect(find.text('数字比例输入'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('按比例加入'), findsOneWidget);

    await tester.tap(find.text('添加和弦'));
    await tester.pump();

    expect(find.textContaining('和弦 2'), findsWidgets);
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

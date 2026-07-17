import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordle/src/app.dart';
import 'package:chordle/src/screens/mode_selection_screen.dart';
import 'package:chordle/src/theme.dart';
import 'package:chordle/src/widgets/chord_board.dart';

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
    expect(find.text('从下方标尺选音并加入和弦'), findsOneWidget);
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

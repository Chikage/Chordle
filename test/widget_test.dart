import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordle/src/app.dart';
import 'package:chordle/src/screens/mode_selection_screen.dart';
import 'package:chordle/src/theme.dart';
import 'package:chordle/src/widgets/chord_board.dart';

void main() {
  testWidgets('shows all three Chordle modes', (tester) async {
    await tester.pumpWidget(const ChordleApp());

    expect(find.text('Chordle'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Extra'), findsOneWidget);
    expect(find.text('Overtones'), findsOneWidget);
  });

  for (final (platform, fontFamily) in <(TargetPlatform, String)>[
    (TargetPlatform.android, 'serif'),
    (TargetPlatform.iOS, '.New York'),
  ]) {
    testWidgets('uses the native $platform serif wordmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildChordleTheme().copyWith(platform: platform),
          home: ModeSelectionScreen(onModeSelected: (_) {}),
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

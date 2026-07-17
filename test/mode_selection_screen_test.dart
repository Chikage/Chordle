import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordle/src/screens/mode_selection_screen.dart';
import 'package:chordle/src/theme.dart';

void main() {
  testWidgets('uses the icon palette for the colored mode buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildChordleTheme(),
        home: ModeSelectionScreen(
          onModeSelected: (_) {},
          onFreeSelected: () {},
        ),
      ),
    );

    Color? buttonColor(String label) {
      final finder = find.ancestor(
        of: find.text(label),
        matching: find.byType(FilledButton),
      );
      final button = tester.widget<FilledButton>(finder);
      return button.style?.backgroundColor?.resolve(<WidgetState>{});
    }

    expect(buttonColor('Normal'), ChordleColors.green);
    expect(buttonColor('Extra'), ChordleColors.yellow);
    expect(buttonColor('Overtones'), ChordleColors.iconGray);
    expect(
      find.ancestor(
        of: find.text('Free'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
  });
}

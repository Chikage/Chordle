import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          onRatioMcqSelected: () {},
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
    expect(buttonColor('MCQ of Ratio'), ChordleColors.ratioMcq);
    expect(buttonColor('Overtones'), ChordleColors.iconGray);
    expect(
      find.ancestor(
        of: find.text('Free'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('places Ratio MCQ between Extra and Overtones', (tester) async {
    var gameModeSelected = false;
    var ratioMcqSelections = 0;
    var freeSelected = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildChordleTheme(),
        home: ModeSelectionScreen(
          onModeSelected: (_) => gameModeSelected = true,
          onRatioMcqSelected: () => ratioMcqSelections += 1,
          onFreeSelected: () => freeSelected = true,
        ),
      ),
    );

    final extraY = tester.getCenter(find.text('Extra')).dy;
    final ratioMcqY = tester.getCenter(find.text('MCQ of Ratio')).dy;
    final overtonesY = tester.getCenter(find.text('Overtones')).dy;

    expect(extraY, lessThan(ratioMcqY));
    expect(ratioMcqY, lessThan(overtonesY));

    await tester.tap(find.text('MCQ of Ratio'));

    expect(ratioMcqSelections, 1);
    expect(gameModeSelected, isFalse);
    expect(freeSelected, isFalse);
  });

  testWidgets('keeps the GitHub repository link visible at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildChordleTheme(),
        home: ModeSelectionScreen(
          onModeSelected: (_) {},
          onRatioMcqSelected: () {},
          onFreeSelected: () {},
        ),
      ),
    );

    final link = find.byKey(const Key('github_repository_link'));
    expect(link, findsOneWidget);
    expect(find.byType(FaIcon), findsOneWidget);
    expect(find.byTooltip('Chikage/Chordle on GitHub'), findsOneWidget);
    expect(tester.getTopLeft(link).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(link).dy, lessThanOrEqualTo(600));
  });
}

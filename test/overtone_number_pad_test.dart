import 'package:chordle/src/game/chord_game.dart';
import 'package:chordle/src/screens/game_screen.dart';
import 'package:chordle/src/theme.dart';
import 'package:chordle/src/widgets/overtone_number_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lays out digits, backspace, and confirm in two rows of six', (
    tester,
  ) async {
    final digits = <int>[];
    var backspaces = 0;
    var confirms = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildChordleTheme(),
        home: Scaffold(
          body: OvertoneNumberPad(
            onDigitPressed: digits.add,
            onBackspace: () => backspaces += 1,
            onConfirm: () => confirms += 1,
            canBackspace: true,
            canConfirm: true,
          ),
        ),
      ),
    );

    final pad = find.byType(OvertoneNumberPad);
    expect(
      find.descendant(of: pad, matching: find.byType(Row)),
      findsNWidgets(2),
    );
    for (var digit = 0; digit <= 9; digit += 1) {
      expect(
        find.byKey(ValueKey<String>('overtone-digit-$digit')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-1')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-0')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-退格')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-确认数字')));

    expect(digits, <int>[1, 0]);
    expect(backspaces, 1);
    expect(confirms, 1);
  });

  testWidgets('enters a two-digit value from the in-game keypad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const channel = MethodChannel('icu.ringona.chordle/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'loadSettings' => <String, Object>{
              'overtoneLow': 8,
              'overtoneHigh': 16,
              'overtoneToneCount': 2,
            },
            'prepareAudio' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildChordleTheme(),
        home: const GameScreen(mode: ChordleMode.overtones),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-0')));
    expect(find.text('未输入数字'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-1')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-2')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-3')));
    await tester.pump();
    expect(find.text('输入 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('overtone-退格')));
    await tester.tap(find.byKey(const ValueKey<String>('overtone-digit-0')));
    await tester.pump();
    expect(find.text('输入 10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('overtone-确认数字')));
    await tester.pump();
    expect(find.text('未输入数字'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

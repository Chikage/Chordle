import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordle/src/screens/ratio_mcq_screen.dart';
import 'package:chordle/src/theme.dart';
import 'package:chordle/src/widgets/settings_dialogs.dart';

const MethodChannel _platformChannel = MethodChannel(
  'icu.ringona.chordle/platform',
);

void main() {
  testWidgets('opens Ratio MCQ settings automatically on first entry', (
    tester,
  ) async {
    await _useSurface(tester, const Size(390, 844));
    _mockPlatformChannel(_ratioSettings(configured: false));

    await _pumpScreen(tester);

    expect(find.text('MCQ of Ratio 设置'), findsOneWidget);
    expect(find.textContaining('首次进入请先完成四项设置'), findsOneWidget);
    expect(find.text('尚未选择调律'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('待设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires explicit first-run MCQ selections before saving', (
    tester,
  ) async {
    await _useSurface(tester, const Size(390, 844));
    _mockPlatformChannel(_ratioSettings(configured: false));

    await _pumpScreen(tester);
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('MCQ of Ratio 设置'), findsOneWidget);
    expect(find.text('请至少选择一种 EDO 调律或 JI'), findsOneWidget);
  });

  testWidgets('defers the full tuning list until the selector is opened', (
    tester,
  ) async {
    await _useSurface(tester, const Size(390, 844));
    _mockPlatformChannel(_ratioSettings(configured: false));

    await _pumpScreen(tester);

    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-tuning-selector-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ratio-tuning-selector-title')),
      findsOneWidget,
    );
    final visibleTuningTiles = find.byType(CheckboxListTile).evaluate().length;
    expect(visibleTuningTiles, greaterThan(1));
    expect(visibleTuningTiles, lessThan(62));
    expect(
      find.byKey(const ValueKey<String>('ratio-tuning-edo-12')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ratio-tuning-edo-72')),
      findsNothing,
    );

    await tester.tap(find.text('常用组合'));
    await tester.pump();
    await tester.tap(find.text('应用选择'));
    await tester.pumpAndSettle();

    expect(find.text('12、19、24、31、53 EDO + JI'), findsOneWidget);
  });

  testWidgets('uses visible dark text on the ratio input fields', (
    tester,
  ) async {
    await _useSurface(tester, const Size(390, 844));
    _mockPlatformChannel(_ratioSettings(configured: false));

    await _pumpScreen(tester);

    for (final key in <String>[
      'ratio-numerator-field',
      'ratio-denominator-field',
    ]) {
      final field = tester.widget<TextField>(find.byKey(ValueKey<String>(key)));
      expect(field.style?.color, ChordleColors.dialogText);
      expect(field.decoration?.filled, isTrue);
      expect(field.decoration?.fillColor, Colors.white);
    }

    await tester.enterText(
      find.byKey(const ValueKey<String>('ratio-numerator-field')),
      '31',
    );
    expect(find.text('31'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves the first-run settings and shows the first question', (
    tester,
  ) async {
    await _useSurface(tester, const Size(390, 844));
    Map<Object?, Object?>? savedSettings;
    _mockPlatformChannel(
      _ratioSettings(configured: false),
      onSaveSettings: (call) {
        savedSettings = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>,
        );
      },
    );

    await _pumpScreen(tester);
    expect(find.text('MCQ of Ratio 设置'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-tuning-selector-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('ratio-tuning-edo-12')));
    await tester.pump();
    await tester.tap(find.text('应用选择'));
    await tester.pumpAndSettle();

    await _addRatio(tester, numerator: '3', denominator: '2');
    await _addRatio(tester, numerator: '4', denominator: '3');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings?['ratioMcqConfigured'], isTrue);
    expect(find.text('MCQ of Ratio 设置'), findsNothing);
    expect(find.text('本题调律：12 EDO'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('整组播放'), findsOneWidget);
  });

  testWidgets('saves the selected MIDI program and uses it for playback', (
    tester,
  ) async {
    await _useSurface(tester, const Size(800, 1000));
    Map<Object?, Object?>? savedSettings;
    Map<Object?, Object?>? playArguments;
    _mockPlatformChannel(
      _ratioSettings(configured: true),
      onSaveSettings: (call) {
        savedSettings = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>,
        );
      },
      onPlayTones: (call) {
        playArguments = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>,
        );
      },
    );

    await _pumpScreen(tester);
    await tester.tap(find.byTooltip('游戏设置'));
    await tester.pumpAndSettle();

    final programSlider = tester.widget<MidiProgramSlider>(
      find.byKey(const ValueKey<String>('ratio-midi-program-slider')),
    );
    programSlider.onChanged(40);
    await tester.pump();
    expect(find.text('音色（MIDI program number）：40'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(savedSettings?['instrumentProgram'], 40);

    await tester.tap(find.text('整组播放'));
    await tester.pumpAndSettle();
    expect(playArguments?['program'], 40);
  });

  testWidgets('scores one selected answer out of two equal 12 EDO steps', (
    tester,
  ) async {
    await _useSurface(tester, const Size(800, 1000));
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[12],
        ratios: const <String>['9/8', '10/9'],
      ),
    );

    await _pumpScreen(tester);

    expect(find.text('本题调律：12 EDO'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.text('9/8'));
    await tester.pump();
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pump();

    expect(find.textContaining('本题得分 1/2'), findsOneWidget);
    expect(find.text('得分 1/2'), findsOneWidget);
    expect(tester.widget<Text>(find.text('得分 1/2')).textAlign, TextAlign.end);
  });

  testWidgets('uses radio option controls for JI questions', (tester) async {
    await _useSurface(tester, const Size(800, 1000));
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[],
        jiEnabled: true,
        ratios: const <String>['9/8', '10/9'],
      ),
    );

    await _pumpScreen(tester);

    expect(find.text('本题调律：JI（纯律）'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('ratio-option-radio-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ratio-option-radio-1')),
      findsOneWidget,
    );
  });

  testWidgets('plays both A and B through the platform channel', (
    tester,
  ) async {
    await _useSurface(tester, const Size(800, 1000));
    Map<Object?, Object?>? playArguments;
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[12],
        ratios: const <String>['9/8', '10/9'],
      ),
      onPlayTones: (call) {
        playArguments = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>,
        );
      },
    );

    await _pumpScreen(tester);
    await tester.tap(find.text('整组播放'));
    await tester.pumpAndSettle();

    expect(playArguments, isNotNull);
    final tones = playArguments!['tones'] as List<Object?>;
    expect(tones, hasLength(2));
  });

  testWidgets('plays A and B individually when their tiles are tapped', (
    tester,
  ) async {
    await _useSurface(tester, const Size(800, 1000));
    final playArguments = <Map<Object?, Object?>>[];
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[12],
        ratios: const <String>['9/8', '10/9'],
      ),
      onPlayTones: (call) {
        playArguments.add(
          Map<Object?, Object?>.from(call.arguments as Map<Object?, Object?>),
        );
      },
    );

    await _pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey<String>('ratio-tone-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('ratio-tone-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('整组播放'));
    await tester.pumpAndSettle();

    expect(playArguments, hasLength(3));
    final aTones = playArguments[0]['tones'] as List<Object?>;
    final bTones = playArguments[1]['tones'] as List<Object?>;
    final groupTones = playArguments[2]['tones'] as List<Object?>;
    expect(aTones, hasLength(1));
    expect(bTones, hasLength(1));
    expect(groupTones, hasLength(2));
    expect(aTones.single, groupTones[0]);
    expect(bTones.single, groupTones[1]);
  });

  testWidgets('shows option previews only after submit and plays B or A+B', (
    tester,
  ) async {
    await _useSurface(tester, const Size(800, 1000));
    final playArguments = <Map<Object?, Object?>>[];
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[12],
        ratios: const <String>['9/8', '3/2'],
      ),
      onPlayTones: (call) {
        playArguments.add(
          Map<Object?, Object?>.from(call.arguments as Map<Object?, Object?>),
        );
      },
    );

    await _pumpScreen(tester);
    expect(
      find.byKey(const ValueKey<String>('ratio-option-play-b-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('ratio-option-play-chord-0')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-option-radio-0')),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('ratio-option-play-b-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ratio-option-play-chord-0')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-option-play-b-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-option-play-chord-0')),
    );
    await tester.pumpAndSettle();

    expect(playArguments, hasLength(2));
    final bTones = playArguments[0]['tones'] as List<Object?>;
    final chordTones = playArguments[1]['tones'] as List<Object?>;
    expect(bTones, hasLength(1));
    expect(chordTones, hasLength(2));
    expect(bTones.single, chordTones[1]);
  });

  testWidgets('lays out the A/B prompt on a 320px-wide screen', (tester) async {
    await _useSurface(tester, const Size(320, 700));
    _mockPlatformChannel(
      _ratioSettings(
        configured: true,
        edos: const <int>[12],
        ratios: const <String>['9/8', '10/9'],
      ),
    );

    await _pumpScreen(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('整组播放'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('ratio-option-checkbox-0')),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('ratio-option-play-chord-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _addRatio(
  WidgetTester tester, {
  required String numerator,
  required String denominator,
}) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('ratio-numerator-field')),
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('ratio-numerator-field')),
    numerator,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('ratio-denominator-field')),
    denominator,
  );
  await tester.ensureVisible(find.text('增加'));
  await tester.tap(find.text('增加'));
  await tester.pump();
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildChordleTheme(),
      home: RatioMcqScreen(random: _ZeroRandom()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _useSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _mockPlatformChannel(
  Map<String, Object> settings, {
  ValueChanged<MethodCall>? onPlayTones,
  ValueChanged<MethodCall>? onSaveSettings,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_platformChannel, (call) async {
    return switch (call.method) {
      'loadSettings' => settings,
      'prepareAudio' => true,
      'playTones' => () {
        onPlayTones?.call(call);
        return null;
      }(),
      'saveSettings' => () {
        onSaveSettings?.call(call);
        return null;
      }(),
      'allSoundOff' => null,
      _ => null,
    };
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_platformChannel, null));
}

Map<String, Object> _ratioSettings({
  required bool configured,
  List<int> edos = const <int>[12],
  bool jiEnabled = false,
  List<String> ratios = const <String>['3/2', '4/3'],
}) {
  return <String, Object>{
    'ratioMcqEdos': edos,
    'ratioMcqJiEnabled': jiEnabled,
    'ratioMcqRatios': ratios,
    'ratioMcqOptionCount': 2,
    'ratioMcqConfigured': configured,
    'instrumentProgram': 0,
  };
}

final class _ZeroRandom implements math.Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

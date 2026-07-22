import 'package:chordle/src/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists the Free JI mode setting in the Flutter settings map', () {
    final settings = ChordleSettings.fromMap(const <Object?, Object?>{
      'freeJiEnabled': true,
    });

    expect(settings.freeJiEnabled, isTrue);
    expect(settings.toMap()['freeJiEnabled'], isTrue);
    expect(settings.copyWith(freeJiEnabled: false).freeJiEnabled, isFalse);
  });

  test('uses a valid minimal default for Ratio MCQ settings', () {
    const settings = ChordleSettings();

    expect(settings.ratioMcqEdos, <int>[12]);
    expect(settings.ratioMcqJiEnabled, isFalse);
    expect(settings.ratioMcqRatios, <String>['3/2', '4/3']);
    expect(settings.ratioMcqOptionCount, 2);
    expect(settings.ratioMcqConfigured, isFalse);
    expect(settings.toMap()['ratioMcqEdos'], '[12]');
    expect(settings.toMap()['ratioMcqRatios'], '["3/2","4/3"]');
  });

  test('round-trips Ratio MCQ lists as stable strings without reordering', () {
    const original = ChordleSettings(
      ratioMcqEdos: <int>[72, 12, 31],
      ratioMcqJiEnabled: true,
      ratioMcqRatios: <String>['31/30', '3/2', '5/4'],
      ratioMcqOptionCount: 3,
      ratioMcqConfigured: true,
    );

    final encoded = original.toMap();
    expect(encoded['ratioMcqEdos'], '[72,12,31]');
    expect(encoded['ratioMcqRatios'], '["31/30","3/2","5/4"]');

    final restored = ChordleSettings.fromMap(encoded);
    expect(restored.ratioMcqEdos, <int>[72, 12, 31]);
    expect(restored.ratioMcqJiEnabled, isTrue);
    expect(restored.ratioMcqRatios, <String>['31/30', '3/2', '5/4']);
    expect(restored.ratioMcqOptionCount, 3);
    expect(restored.ratioMcqConfigured, isTrue);

    final copied = restored.copyWith(
      ratioMcqEdos: <int>[24, 12],
      ratioMcqRatios: <String>['7/4', '6/5', '9/8'],
    );
    expect(copied.ratioMcqEdos, <int>[24, 12]);
    expect(copied.ratioMcqRatios, <String>['7/4', '6/5', '9/8']);
  });

  test('accepts iterable values and sanitizes Ratio MCQ boundaries', () {
    final settings = ChordleSettings.fromMap(<Object?, Object?>{
      'ratioMcqEdos': <Object?>[11, 12, 12.5, '24', 72, 73, 24],
      'ratioMcqJiEnabled': false,
      'ratioMcqRatios': <Object?>[
        '6/4',
        '3/2',
        '127/1',
        '128/1',
        '126/84',
        '254/2',
        '0/1',
        '-1/2',
        '4/3',
        '5/4',
        '6/5',
        '7/6',
        '8/7',
        '9/8',
        '10/9',
        '11/10',
        '12/11',
      ],
      'ratioMcqOptionCount': 99,
    });

    expect(settings.ratioMcqEdos, <int>[12, 24, 72]);
    expect(settings.ratioMcqRatios, <String>[
      '3/2',
      '127/1',
      '4/3',
      '5/4',
      '6/5',
      '7/6',
      '8/7',
      '9/8',
      '10/9',
      '11/10',
    ]);
    expect(settings.ratioMcqOptionCount, 10);
  });

  test('decodes string lists and repairs undersized invalid settings', () {
    final settings = ChordleSettings.fromMap(const <Object?, Object?>{
      'ratioMcqEdos': '[11,73,"bad"]',
      'ratioMcqJiEnabled': false,
      'ratioMcqRatios': '["0/1","128/1","3/2"]',
      'ratioMcqOptionCount': 1,
      'ratioMcqConfigured': 'true',
    });

    expect(settings.ratioMcqEdos, <int>[12]);
    expect(settings.ratioMcqRatios, <String>['3/2', '4/3']);
    expect(settings.ratioMcqOptionCount, 2);
    expect(settings.ratioMcqConfigured, isTrue);
  });

  test('allows a JI-only tuning selection', () {
    final settings = ChordleSettings.fromMap(const <Object?, Object?>{
      'ratioMcqEdos': <int>[],
      'ratioMcqJiEnabled': true,
      'ratioMcqRatios': '5/4;3/2',
      'ratioMcqOptionCount': 8,
    });

    expect(settings.ratioMcqEdos, isEmpty);
    expect(settings.ratioMcqJiEnabled, isTrue);
    expect(settings.ratioMcqRatios, <String>['5/4', '3/2']);
    expect(settings.ratioMcqOptionCount, 2);
  });
}

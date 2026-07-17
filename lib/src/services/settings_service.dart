import 'package:flutter/services.dart';

class ChordleSettings {
  const ChordleSettings({
    this.normalLow = 48,
    this.normalHigh = 72,
    this.normalToneCount = 3,
    this.extraLow = 48,
    this.extraHigh = 72,
    this.extraToneCount = 3,
    this.extraEdo = 24,
    this.overtoneLow = 8,
    this.overtoneHigh = 16,
    this.overtoneToneCount = 4,
    this.instrumentProgram = 0,
    this.keyPitchPreviewEnabled = false,
  });

  final int normalLow;
  final int normalHigh;
  final int normalToneCount;
  final int extraLow;
  final int extraHigh;
  final int extraToneCount;
  final int extraEdo;
  final int overtoneLow;
  final int overtoneHigh;
  final int overtoneToneCount;
  final int instrumentProgram;
  final bool keyPitchPreviewEnabled;

  ChordleSettings copyWith({
    int? normalLow,
    int? normalHigh,
    int? normalToneCount,
    int? extraLow,
    int? extraHigh,
    int? extraToneCount,
    int? extraEdo,
    int? overtoneLow,
    int? overtoneHigh,
    int? overtoneToneCount,
    int? instrumentProgram,
    bool? keyPitchPreviewEnabled,
  }) {
    return ChordleSettings(
      normalLow: normalLow ?? this.normalLow,
      normalHigh: normalHigh ?? this.normalHigh,
      normalToneCount: normalToneCount ?? this.normalToneCount,
      extraLow: extraLow ?? this.extraLow,
      extraHigh: extraHigh ?? this.extraHigh,
      extraToneCount: extraToneCount ?? this.extraToneCount,
      extraEdo: extraEdo ?? this.extraEdo,
      overtoneLow: overtoneLow ?? this.overtoneLow,
      overtoneHigh: overtoneHigh ?? this.overtoneHigh,
      overtoneToneCount: overtoneToneCount ?? this.overtoneToneCount,
      instrumentProgram: instrumentProgram ?? this.instrumentProgram,
      keyPitchPreviewEnabled:
          keyPitchPreviewEnabled ?? this.keyPitchPreviewEnabled,
    );
  }

  Map<String, Object> toMap() => <String, Object>{
    'normalLow': normalLow,
    'normalHigh': normalHigh,
    'normalToneCount': normalToneCount,
    'extraLow': extraLow,
    'extraHigh': extraHigh,
    'extraToneCount': extraToneCount,
    'extraEdo': extraEdo,
    'overtoneLow': overtoneLow,
    'overtoneHigh': overtoneHigh,
    'overtoneToneCount': overtoneToneCount,
    'instrumentProgram': instrumentProgram,
    'keyPitchPreviewEnabled': keyPitchPreviewEnabled,
  };

  factory ChordleSettings.fromMap(Map<Object?, Object?> values) {
    int integer(List<String> keys, int fallback) {
      for (final key in keys) {
        final value = values[key];
        if (value is num) return value.toInt();
      }
      return fallback;
    }

    return ChordleSettings(
      normalLow: integer(const [
        'normalLow',
        'playableRangeLow',
        'normalPlayableRangeLow',
        'normalRangeLow',
        'playable_range_low',
      ], 48),
      normalHigh: integer(const [
        'normalHigh',
        'playableRangeHigh',
        'normalPlayableRangeHigh',
        'normalRangeHigh',
        'playable_range_high',
      ], 72),
      normalToneCount: integer(const [
        'normalToneCount',
        'chordToneCount',
        'normalChordToneCount',
        'chord_tone_count',
      ], 3),
      extraLow: integer(const [
        'extraLow',
        'extraPlayableRangeLow',
        'extraRangeLow',
        'extra_playable_range_low',
      ], 48),
      extraHigh: integer(const [
        'extraHigh',
        'extraPlayableRangeHigh',
        'extraRangeHigh',
        'extra_playable_range_high',
      ], 72),
      extraToneCount: integer(const [
        'extraToneCount',
        'extraChordToneCount',
        'extra_chord_tone_count',
        'chord_tone_count',
      ], 3),
      extraEdo: integer(const ['extraEdo', 'extra_edo'], 24),
      overtoneLow: integer(const [
        'overtoneLow',
        'overtoneRangeLow',
        'overtone_range_low',
      ], 8),
      overtoneHigh: integer(const [
        'overtoneHigh',
        'overtoneRangeHigh',
        'overtone_range_high',
      ], 16),
      overtoneToneCount: integer(const [
        'overtoneToneCount',
        'overtone_tone_count',
      ], 4),
      instrumentProgram: integer(const [
        'instrumentProgram',
        'instrument_program',
      ], 0),
      keyPitchPreviewEnabled:
          values['keyPitchPreviewEnabled'] as bool? ?? false,
    );
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();
  static const MethodChannel _channel = MethodChannel(
    'icu.ringona.chordle/platform',
  );

  Future<ChordleSettings> load() async {
    try {
      final values = await _channel.invokeMapMethod<Object?, Object?>(
        'loadSettings',
      );
      return ChordleSettings.fromMap(values ?? const <Object?, Object?>{});
    } on PlatformException {
      return const ChordleSettings();
    } on MissingPluginException {
      return const ChordleSettings();
    }
  }

  Future<void> save(ChordleSettings settings) async {
    try {
      await _channel.invokeMethod<void>('saveSettings', settings.toMap());
    } on PlatformException {
      // Keep the game usable if native persistence is temporarily unavailable.
    } on MissingPluginException {
      // Unit and widget tests do not install the native channel.
    }
  }
}

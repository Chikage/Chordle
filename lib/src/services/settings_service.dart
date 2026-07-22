import 'dart:convert';

import 'package:flutter/services.dart';

const List<int> _defaultRatioMcqEdos = <int>[12];
const List<String> _defaultRatioMcqRatios = <String>['3/2', '4/3'];
const int _minRatioMcqEdo = 12;
const int _maxRatioMcqEdo = 72;
const int _maxRatioMcqComponent = 127;
const int _minRatioMcqRatioCount = 2;
const int _maxRatioMcqRatioCount = 10;

class ChordleSettings {
  const ChordleSettings({
    this.normalLow = 48,
    this.normalHigh = 72,
    this.normalToneCount = 3,
    this.extraLow = 48,
    this.extraHigh = 72,
    this.extraToneCount = 3,
    this.extraEdo = 24,
    this.freeJiEnabled = false,
    this.ratioMcqEdos = _defaultRatioMcqEdos,
    this.ratioMcqJiEnabled = false,
    this.ratioMcqRatios = _defaultRatioMcqRatios,
    this.ratioMcqOptionCount = 2,
    this.ratioMcqConfigured = false,
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
  final bool freeJiEnabled;
  final List<int> ratioMcqEdos;
  final bool ratioMcqJiEnabled;
  final List<String> ratioMcqRatios;
  final int ratioMcqOptionCount;
  final bool ratioMcqConfigured;
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
    bool? freeJiEnabled,
    List<int>? ratioMcqEdos,
    bool? ratioMcqJiEnabled,
    List<String>? ratioMcqRatios,
    int? ratioMcqOptionCount,
    bool? ratioMcqConfigured,
    int? overtoneLow,
    int? overtoneHigh,
    int? overtoneToneCount,
    int? instrumentProgram,
    bool? keyPitchPreviewEnabled,
  }) {
    final nextRatioMcqJiEnabled = ratioMcqJiEnabled ?? this.ratioMcqJiEnabled;
    final nextRatioMcqEdos = _sanitizeRatioMcqEdos(
      ratioMcqEdos ?? this.ratioMcqEdos,
      jiEnabled: nextRatioMcqJiEnabled,
    );
    final nextRatioMcqRatios = _sanitizeRatioMcqRatios(
      ratioMcqRatios ?? this.ratioMcqRatios,
    );
    final nextRatioMcqOptionCount = _sanitizeRatioMcqOptionCount(
      ratioMcqOptionCount ?? this.ratioMcqOptionCount,
      nextRatioMcqRatios.length,
    );

    return ChordleSettings(
      normalLow: normalLow ?? this.normalLow,
      normalHigh: normalHigh ?? this.normalHigh,
      normalToneCount: normalToneCount ?? this.normalToneCount,
      extraLow: extraLow ?? this.extraLow,
      extraHigh: extraHigh ?? this.extraHigh,
      extraToneCount: extraToneCount ?? this.extraToneCount,
      extraEdo: extraEdo ?? this.extraEdo,
      freeJiEnabled: freeJiEnabled ?? this.freeJiEnabled,
      ratioMcqEdos: nextRatioMcqEdos,
      ratioMcqJiEnabled: nextRatioMcqJiEnabled,
      ratioMcqRatios: nextRatioMcqRatios,
      ratioMcqOptionCount: nextRatioMcqOptionCount,
      ratioMcqConfigured: ratioMcqConfigured ?? this.ratioMcqConfigured,
      overtoneLow: overtoneLow ?? this.overtoneLow,
      overtoneHigh: overtoneHigh ?? this.overtoneHigh,
      overtoneToneCount: overtoneToneCount ?? this.overtoneToneCount,
      instrumentProgram: instrumentProgram ?? this.instrumentProgram,
      keyPitchPreviewEnabled:
          keyPitchPreviewEnabled ?? this.keyPitchPreviewEnabled,
    );
  }

  Map<String, Object> toMap() {
    final sanitizedEdos = _sanitizeRatioMcqEdos(
      ratioMcqEdos,
      jiEnabled: ratioMcqJiEnabled,
    );
    final sanitizedRatios = _sanitizeRatioMcqRatios(ratioMcqRatios);
    return <String, Object>{
      'normalLow': normalLow,
      'normalHigh': normalHigh,
      'normalToneCount': normalToneCount,
      'extraLow': extraLow,
      'extraHigh': extraHigh,
      'extraToneCount': extraToneCount,
      'extraEdo': extraEdo,
      'freeJiEnabled': freeJiEnabled,
      'ratioMcqEdos': jsonEncode(sanitizedEdos),
      'ratioMcqJiEnabled': ratioMcqJiEnabled,
      'ratioMcqRatios': jsonEncode(sanitizedRatios),
      'ratioMcqOptionCount': _sanitizeRatioMcqOptionCount(
        ratioMcqOptionCount,
        sanitizedRatios.length,
      ),
      'ratioMcqConfigured': ratioMcqConfigured,
      'overtoneLow': overtoneLow,
      'overtoneHigh': overtoneHigh,
      'overtoneToneCount': overtoneToneCount,
      'instrumentProgram': instrumentProgram,
      'keyPitchPreviewEnabled': keyPitchPreviewEnabled,
    };
  }

  factory ChordleSettings.fromMap(Map<Object?, Object?> values) {
    int integer(List<String> keys, int fallback) {
      for (final key in keys) {
        final value = values[key];
        if (value is num) return value.toInt();
      }
      return fallback;
    }

    bool boolean(List<String> keys, bool fallback) {
      for (final key in keys) {
        final value = values[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          switch (value.trim().toLowerCase()) {
            case 'true':
            case '1':
              return true;
            case 'false':
            case '0':
              return false;
          }
        }
      }
      return fallback;
    }

    Object? firstValue(List<String> keys) {
      for (final key in keys) {
        if (values.containsKey(key)) return values[key];
      }
      return null;
    }

    final ratioMcqJiEnabled = boolean(const <String>[
      'ratioMcqJiEnabled',
      'ratio_mcq_ji_enabled',
    ], false);
    final ratioMcqEdos = _sanitizeRatioMcqEdos(
      _decodeStableList(
        firstValue(const <String>['ratioMcqEdos', 'ratio_mcq_edos']),
      ),
      jiEnabled: ratioMcqJiEnabled,
    );
    final ratioMcqRatios = _sanitizeRatioMcqRatios(
      _decodeStableList(
        firstValue(const <String>['ratioMcqRatios', 'ratio_mcq_ratios']),
      ),
    );

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
      freeJiEnabled: boolean(const <String>[
        'freeJiEnabled',
        'free_ji_enabled',
      ], false),
      ratioMcqEdos: ratioMcqEdos,
      ratioMcqJiEnabled: ratioMcqJiEnabled,
      ratioMcqRatios: ratioMcqRatios,
      ratioMcqOptionCount: _sanitizeRatioMcqOptionCount(
        integer(const <String>[
          'ratioMcqOptionCount',
          'ratio_mcq_option_count',
        ], 2),
        ratioMcqRatios.length,
      ),
      ratioMcqConfigured: boolean(const <String>[
        'ratioMcqConfigured',
        'ratio_mcq_configured',
      ], false),
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
      keyPitchPreviewEnabled: boolean(const <String>[
        'keyPitchPreviewEnabled',
        'key_pitch_preview_enabled',
      ], false),
    );
  }
}

Iterable<Object?> _decodeStableList(Object? value) {
  if (value == null) return const <Object?>[];
  if (value is Iterable<Object?>) return value;
  if (value is Iterable) return value.cast<Object?>();
  if (value is! String) return <Object?>[value];

  final normalized = value.trim();
  if (normalized.isEmpty) return const <Object?>[];
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is Iterable<Object?>) return decoded;
    if (decoded is Iterable) return decoded.cast<Object?>();
    return <Object?>[decoded];
  } on FormatException {
    return normalized
        .split(RegExp(r'[,;\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
  }
}

List<int> _sanitizeRatioMcqEdos(
  Iterable<Object?> values, {
  required bool jiEnabled,
}) {
  final sanitized = <int>[];
  final seen = <int>{};
  for (final value in values) {
    final edo = switch (value) {
      num number when number.isFinite && number == number.truncate() =>
        number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (edo == null ||
        edo < _minRatioMcqEdo ||
        edo > _maxRatioMcqEdo ||
        !seen.add(edo)) {
      continue;
    }
    sanitized.add(edo);
  }
  if (sanitized.isEmpty && !jiEnabled) {
    sanitized.addAll(_defaultRatioMcqEdos);
  }
  return List<int>.unmodifiable(sanitized);
}

List<String> _sanitizeRatioMcqRatios(Iterable<Object?> values) {
  final sanitized = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final ratio = _sanitizeRatioMcqRatio(value?.toString());
    if (ratio == null || !seen.add(ratio)) continue;
    sanitized.add(ratio);
    if (sanitized.length == _maxRatioMcqRatioCount) break;
  }
  for (final fallback in _defaultRatioMcqRatios) {
    if (sanitized.length >= _minRatioMcqRatioCount) break;
    if (seen.add(fallback)) sanitized.add(fallback);
  }
  return List<String>.unmodifiable(sanitized);
}

String? _sanitizeRatioMcqRatio(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^\s*(\d+)\s*(?:/\s*(\d+)\s*)?$').firstMatch(value);
  if (match == null) return null;
  final numerator = int.tryParse(match.group(1)!);
  final denominator = int.tryParse(match.group(2) ?? '1');
  if (numerator == null ||
      denominator == null ||
      numerator < 1 ||
      numerator > _maxRatioMcqComponent ||
      denominator < 1 ||
      denominator > _maxRatioMcqComponent) {
    return null;
  }
  final divisor = _greatestCommonDivisor(numerator, denominator);
  return '${numerator ~/ divisor}/${denominator ~/ divisor}';
}

int _sanitizeRatioMcqOptionCount(int value, int ratioCount) {
  if (value < _minRatioMcqRatioCount) return _minRatioMcqRatioCount;
  if (value > ratioCount) return ratioCount;
  return value;
}

int _greatestCommonDivisor(int first, int second) {
  var left = first;
  var right = second;
  while (right != 0) {
    final remainder = left % right;
    left = right;
    right = remainder;
  }
  return left;
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

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/chord_game.dart';

enum AudioStatus { loading, ready, error }

class PlaybackTone {
  const PlaybackTone({required this.key, this.cents = 0});

  final int key;
  final double cents;

  Map<String, Object> toMap() => <String, Object>{
    'key': key.clamp(0, 127),
    'cents': cents,
  };
}

class AudioService extends ChangeNotifier {
  AudioService._();

  static final AudioService instance = AudioService._();
  static const MethodChannel _channel = MethodChannel(
    'icu.ringona.chordle/platform',
  );

  AudioStatus _status = AudioStatus.loading;
  String? _errorMessage;
  int? _preparedProgram;

  AudioStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == AudioStatus.ready;

  Future<void> prepare(int program) async {
    final normalizedProgram = program.clamp(0, 127);
    if (_status == AudioStatus.ready && _preparedProgram == normalizedProgram) {
      return;
    }
    _status = AudioStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final ready = await _channel.invokeMethod<bool>(
        'prepareAudio',
        <String, Object>{'program': normalizedProgram},
      );
      if (ready != true) {
        throw PlatformException(code: 'audio_unavailable', message: '音色加载失败');
      }
      _preparedProgram = normalizedProgram;
      _status = AudioStatus.ready;
    } on PlatformException catch (error) {
      _status = AudioStatus.error;
      _errorMessage = error.message ?? '音频引擎启动失败';
    } on MissingPluginException {
      _status = AudioStatus.error;
      _errorMessage = '当前平台未提供 FluidSynth 音频引擎';
    }
    notifyListeners();
  }

  Future<void> playTones(
    List<PlaybackTone> tones, {
    int velocity = 104,
    int durationMs = 1200,
    int program = 0,
  }) async {
    if (tones.isEmpty) {
      return;
    }
    await prepare(program);
    if (!isReady) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('playTones', <String, Object>{
        'tones': tones.map((tone) => tone.toMap()).toList(growable: false),
        'velocity': velocity.clamp(1, 127),
        'durationMs': math.max(50, durationMs),
        'program': program.clamp(0, 127),
      });
    } on PlatformException catch (error) {
      _status = AudioStatus.error;
      _errorMessage = error.message ?? '播放失败';
      notifyListeners();
    }
  }

  Future<void> playValues(
    ChordleMode mode,
    ChordPuzzle puzzle,
    List<int> values,
    int extraEdo, {
    int velocity = 104,
    int durationMs = 1200,
    int program = 0,
  }) {
    final tones = switch (mode) {
      ChordleMode.normal =>
        values.map((value) => PlaybackTone(key: value)).toList(growable: false),
      ChordleMode.extra =>
        values
            .map((step) {
              final edo = extraEdo.clamp(1, 72);
              final midiValue = step * 12.0 / edo;
              final key = midiValue.round().clamp(0, 108);
              return PlaybackTone(key: key, cents: (midiValue - key) * 100.0);
            })
            .toList(growable: false),
      ChordleMode.overtones => _overtoneTones(puzzle, values),
    };
    return playTones(
      tones,
      velocity: velocity,
      durationMs: durationMs,
      program: program,
    );
  }

  Future<void> playFrequencies(
    List<double> frequencies, {
    int velocity = 104,
    int durationMs = 1200,
    int program = 0,
  }) {
    final tones = frequencies
        .where((frequency) => frequency.isFinite && frequency > 0)
        .map((frequency) {
          final midiValue =
              69.0 + 12.0 * (math.log(frequency / 440.0) / math.ln2);
          final key = midiValue.round().clamp(0, 108);
          return PlaybackTone(key: key, cents: (midiValue - key) * 100.0);
        })
        .toList(growable: false);
    return playTones(
      tones,
      velocity: velocity,
      durationMs: durationMs,
      program: program,
    );
  }

  Future<void> allSoundOff() async {
    try {
      await _channel.invokeMethod<void>('allSoundOff');
    } on PlatformException {
      // Lifecycle shutdown is best effort.
    } on MissingPluginException {
      // Tests and unsupported targets do not install the native channel.
    }
  }

  List<PlaybackTone> _overtoneTones(ChordPuzzle puzzle, List<int> multipliers) {
    final baseMidiNote = puzzle.baseMidiNote;
    if (baseMidiNote == null) {
      return const <PlaybackTone>[];
    }
    final baseFrequency = 440.0 * math.pow(2, (baseMidiNote - 69) / 12.0);
    return multipliers
        .map((multiplier) {
          final frequency = baseFrequency * multiplier;
          final midiValue =
              69.0 + 12.0 * (math.log(frequency / 440.0) / math.ln2);
          final key = midiValue.round().clamp(0, 108);
          return PlaybackTone(key: key, cents: (midiValue - key) * 100.0);
        })
        .toList(growable: false);
  }
}

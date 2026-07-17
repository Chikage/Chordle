import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/chord_game.dart';
import '../services/settings_service.dart';
import '../theme.dart';

Future<ChordleSettings?> showNormalSettingsDialog(
  BuildContext context,
  ChordleSettings settings,
) {
  var range = sanitizePlayableRange(
    IntRange.sorted(settings.normalLow, settings.normalHigh),
  );
  var toneCount = sanitizeChordToneCount(settings.normalToneCount);
  var program = sanitizeMidiProgramNumber(settings.instrumentProgram);
  var preview = settings.keyPitchPreviewEnabled;

  return showDialog<ChordleSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final lowIndex = playableWhiteKeyMidiNotes.indexOf(range.lowerBound);
        final highIndex = playableWhiteKeyMidiNotes.indexOf(range.upperBound);
        return _SettingsDialog(
          title: '游戏设置',
          onSave: () => Navigator.of(dialogContext).pop(
            settings.copyWith(
              normalLow: range.lowerBound,
              normalHigh: range.upperBound,
              normalToneCount: toneCount,
              instrumentProgram: program,
              keyPitchPreviewEnabled: preview,
            ),
          ),
          children: [
            Text('出题音域：${rangeLabel(range)}'),
            const _HintText(
              '默认 3 音、C3–C5；音数可设为 1–10，音域可在 A0–C8 内选择，最小跨度为一个八度。',
            ),
            _LabeledSlider(
              label: '播放音数：$toneCount',
              value: toneCount.toDouble(),
              min: minChordToneCount.toDouble(),
              max: maxChordToneCount.toDouble(),
              divisions: maxChordToneCount - minChordToneCount,
              onChanged: (value) => setState(
                () => toneCount = sanitizeChordToneCount(value.round()),
              ),
            ),
            _ProgramSlider(
              value: program,
              onChanged: (value) => setState(() => program = value),
            ),
            _PreviewSwitch(
              value: preview,
              onChanged: (value) => setState(() => preview = value),
            ),
            Text(
              '音域两端：${noteLabel(range.lowerBound)} / ${noteLabel(range.upperBound)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            RangeSlider(
              values: RangeValues(lowIndex.toDouble(), highIndex.toDouble()),
              min: 0,
              max: (playableWhiteKeyMidiNotes.length - 1).toDouble(),
              divisions: playableWhiteKeyMidiNotes.length - 1,
              onChanged: (values) => setState(() {
                final low = playableWhiteKeyMidiNotes[values.start.round()];
                final high = playableWhiteKeyMidiNotes[values.end.round()];
                range = sanitizePlayableRange(IntRange.sorted(low, high));
              }),
            ),
            _PresetButtons(
              leftLabel: '默认',
              rightLabel: '全键盘',
              onLeft: () => setState(() {
                range = defaultPlayableRange;
                toneCount = defaultChordToneCount;
                program = defaultMidiProgramNumber;
                preview = false;
              }),
              onRight: () => setState(() => range = fullPianoRange),
            ),
          ],
        );
      },
    ),
  );
}

Future<ChordleSettings?> showExtraSettingsDialog(
  BuildContext context,
  ChordleSettings settings,
) {
  var range = sanitizeExtraPlayableRange(
    IntRange.sorted(settings.extraLow, settings.extraHigh),
  );
  var toneCount = sanitizeChordToneCount(settings.extraToneCount);
  var edo = sanitizeExtraEdo(settings.extraEdo);
  var program = sanitizeMidiProgramNumber(settings.instrumentProgram);
  var preview = settings.keyPitchPreviewEnabled;

  return showDialog<ChordleSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => _SettingsDialog(
        title: 'Extra 设置',
        onSave: () => Navigator.of(dialogContext).pop(
          settings.copyWith(
            extraLow: range.lowerBound,
            extraHigh: range.upperBound,
            extraToneCount: toneCount,
            extraEdo: edo,
            instrumentProgram: program,
            keyPitchPreviewEnabled: preview,
          ),
        ),
        children: [
          Text('$edo EDO', style: const TextStyle(fontWeight: FontWeight.w800)),
          Row(
            children: [
              _StepButton(
                text: '−',
                enabled: edo > minExtraEdo,
                onPressed: () =>
                    setState(() => edo = sanitizeExtraEdo(edo - 1)),
              ),
              Expanded(
                child: Slider(
                  value: edo.toDouble(),
                  min: minExtraEdo.toDouble(),
                  max: maxExtraEdo.toDouble(),
                  divisions: maxExtraEdo - minExtraEdo,
                  label: '$edo EDO',
                  onChanged: (value) =>
                      setState(() => edo = sanitizeExtraEdo(value.round())),
                ),
              ),
              _StepButton(
                text: '+',
                enabled: edo < maxExtraEdo,
                onPressed: () =>
                    setState(() => edo = sanitizeExtraEdo(edo + 1)),
              ),
            ],
          ),
          Text('出题音域：${rangeLabel(range)} · ${extraRangeLabel(edo, range)}'),
          const _HintText(
            'Extra 会按当前 EDO 把八度等分；音域两端只允许选择 C，并使用 1–72 EDO 标尺模板绘制键盘刻度。',
          ),
          _LabeledSlider(
            label: '播放音数：$toneCount',
            value: toneCount.toDouble(),
            min: minChordToneCount.toDouble(),
            max: maxChordToneCount.toDouble(),
            divisions: maxChordToneCount - minChordToneCount,
            onChanged: (value) => setState(
              () => toneCount = sanitizeChordToneCount(value.round()),
            ),
          ),
          _ProgramSlider(
            value: program,
            onChanged: (value) => setState(() => program = value),
          ),
          _PreviewSwitch(
            value: preview,
            onChanged: (value) => setState(() => preview = value),
          ),
          Text(
            '音域两端：${noteLabel(range.lowerBound)} / ${noteLabel(range.upperBound)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          RangeSlider(
            values: RangeValues(
              octaveForCMidiNote(range.lowerBound).toDouble(),
              octaveForCMidiNote(range.upperBound).toDouble(),
            ),
            min: minExtraRangeOctave.toDouble(),
            max: maxExtraRangeOctave.toDouble(),
            divisions: maxExtraRangeOctave - minExtraRangeOctave,
            onChanged: (values) => setState(() {
              range = sanitizeExtraPlayableRange(
                IntRange.sorted(
                  cMidiNoteForOctave(values.start.round()),
                  cMidiNoteForOctave(values.end.round()),
                ),
              );
            }),
          ),
          _PresetButtons(
            leftLabel: '默认',
            rightLabel: '全 C 范围',
            onLeft: () => setState(() {
              range = defaultExtraPlayableRange;
              toneCount = defaultChordToneCount;
              edo = defaultExtraEdo;
              program = defaultMidiProgramNumber;
              preview = false;
            }),
            onRight: () => setState(
              () => range = const IntRange(
                lowestExtraPlayableMidiNote,
                highestExtraPlayableMidiNote,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<ChordleSettings?> showOvertoneSettingsDialog(
  BuildContext context,
  ChordleSettings settings,
) {
  var range = sanitizeOvertoneRange(
    IntRange.sorted(settings.overtoneLow, settings.overtoneHigh),
  );
  var toneCount = sanitizeOvertoneToneCount(settings.overtoneToneCount, range);
  var program = sanitizeMidiProgramNumber(settings.instrumentProgram);
  var preview = settings.keyPitchPreviewEnabled;

  return showDialog<ChordleSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final toneMax = maxOvertoneToneCount(range);
        return _SettingsDialog(
          title: 'Overtones 设置',
          onSave: () => Navigator.of(dialogContext).pop(
            settings.copyWith(
              overtoneLow: range.lowerBound,
              overtoneHigh: range.upperBound,
              overtoneToneCount: toneCount,
              instrumentProgram: program,
              keyPitchPreviewEnabled: preview,
            ),
          ),
          children: [
            Text('倍频范围：${range.lowerBound}–${range.upperBound}x'),
            const _HintText('可选 1–31 内的正整数子区间；最高值至少为最低值的 2 倍，区间端点会包含在内。'),
            _LabeledSlider(
              label: '音的个数：$toneCount（最多 $toneMax）',
              value: toneCount.toDouble(),
              min: minOvertoneToneCount.toDouble(),
              max: toneMax.toDouble(),
              divisions: math.max(1, toneMax - minOvertoneToneCount),
              onChanged: toneMax == minOvertoneToneCount
                  ? null
                  : (value) => setState(
                      () => toneCount = sanitizeOvertoneToneCount(
                        value.round(),
                        range,
                      ),
                    ),
            ),
            _ProgramSlider(
              value: program,
              onChanged: (value) => setState(() => program = value),
            ),
            _PreviewSwitch(
              value: preview,
              onChanged: (value) => setState(() => preview = value),
            ),
            Text(
              '倍频两端：${range.lowerBound}x / ${range.upperBound}x',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            RangeSlider(
              values: RangeValues(
                range.lowerBound.toDouble(),
                range.upperBound.toDouble(),
              ),
              min: minOvertoneMultiplier.toDouble(),
              max: maxOvertoneMultiplier.toDouble(),
              divisions: maxOvertoneMultiplier - minOvertoneMultiplier,
              onChanged: (values) => setState(() {
                range = sanitizeOvertoneRange(
                  IntRange.sorted(values.start.round(), values.end.round()),
                );
                toneCount = sanitizeOvertoneToneCount(toneCount, range);
              }),
            ),
            const _HintText('每局会按最高倍频限制随机基音，保证播放的最高频率不超过 C8。'),
            _PresetButtons(
              leftLabel: '默认',
              rightLabel: '全范围',
              onLeft: () => setState(() {
                range = defaultOvertoneRange;
                toneCount = defaultOvertoneToneCount;
                program = defaultMidiProgramNumber;
                preview = false;
              }),
              onRight: () => setState(() {
                range = sanitizeOvertoneRange(
                  const IntRange(minOvertoneMultiplier, maxOvertoneMultiplier),
                );
                toneCount = sanitizeOvertoneToneCount(toneCount, range);
              }),
            ),
          ],
        );
      },
    ),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.title,
    required this.children,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 11),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ChordleColors.dialogMuted,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ChordleColors.dialogText,
          ),
          onPressed: onSave,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: ChordleColors.dialogMuted, fontSize: 13.5),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: max > min ? divisions : null,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ProgramSlider extends StatelessWidget {
  const _ProgramSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledSlider(
      label: '音色（MIDI program number）：$value',
      value: value.toDouble(),
      min: minMidiProgramNumber.toDouble(),
      max: maxMidiProgramNumber.toDouble(),
      divisions: maxMidiProgramNumber - minMidiProgramNumber,
      onChanged: (next) => onChanged(sanitizeMidiProgramNumber(next.round())),
    );
  }
}

class _PreviewSwitch extends StatelessWidget {
  const _PreviewSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '选择按键时预听音高',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PresetButtons extends StatelessWidget {
  const _PresetButtons({
    required this.leftLabel,
    required this.rightLabel,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: ChordleColors.dialogText,
      side: const BorderSide(color: ChordleColors.dialogMuted),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: style,
            onPressed: onLeft,
            child: Text(leftLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: style,
            onPressed: onRight,
            child: Text(rightLabel),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ChordleColors.dialogText,
          side: const BorderSide(color: ChordleColors.dialogMuted),
          padding: EdgeInsets.zero,
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

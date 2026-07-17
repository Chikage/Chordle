import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'edo_scale_marks.dart';

class MicrotonalKeyboard extends StatefulWidget {
  const MicrotonalKeyboard({
    required this.edo,
    required this.lowMidi,
    required this.highMidi,
    required this.selectedStep,
    required this.valueColors,
    required this.onStepPressed,
    this.compact = false,
    super.key,
  });

  final int edo;
  final int lowMidi;
  final int highMidi;
  final int? selectedStep;
  final Map<int, Color> valueColors;
  final ValueChanged<int> onStepPressed;
  final bool compact;

  @override
  State<MicrotonalKeyboard> createState() => _MicrotonalKeyboardState();
}

class _MicrotonalKeyboardState extends State<MicrotonalKeyboard> {
  double _scale = 1;
  double _offsetX = 0;
  double _startScale = 1;
  double _startOffset = 0;
  double _viewportWidth = 0;

  @override
  void didUpdateWidget(MicrotonalKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edo != widget.edo ||
        oldWidget.lowMidi != widget.lowMidi ||
        oldWidget.highMidi != widget.highMidi) {
      _scale = 1;
      _offsetX = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final edo = widget.edo.clamp(1, 72);
    final lowMidi = math.min(widget.lowMidi, widget.highMidi);
    final highMidi = math.max(widget.lowMidi, widget.highMidi);
    final touchFirst = (lowMidi * edo / 12 - 0.000001).ceil();
    final touchLast = (highMidi * edo / 12 + 0.000001).floor();
    final edge = (edo / 12).ceil().clamp(1, 72);
    final rulerFirst = touchFirst - edge;
    final rulerLast = touchLast + edge;

    return SizedBox(
      height: widget.compact ? 138 : 172,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = constraints.maxWidth;
          final baseStepWidth = widget.compact ? 15.0 : 18.0;
          final stepWidth = baseStepWidth * _scale;
          final count = rulerLast - rulerFirst + 1;
          final contentWidth = count * stepWidth;
          final minOffset = math.min(0.0, constraints.maxWidth - contentWidth);
          final paintOffset = _offsetX.clamp(minOffset, 0.0);

          return Semantics(
            label: '$edo EDO 可缩放标尺，双指缩放，横向拖动',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => setState(() {
                  _scale = 1;
                  _offsetX = 0;
                }),
                onTapUp: (details) {
                  final localX = details.localPosition.dx - paintOffset;
                  if (localX < 0 || stepWidth <= 0) return;
                  final step = rulerFirst + (localX / stepWidth).floor();
                  if (step >= touchFirst && step <= touchLast) {
                    widget.onStepPressed(step);
                  }
                },
                onScaleStart: (details) {
                  _startScale = _scale;
                  _startOffset = paintOffset;
                },
                onScaleUpdate: (details) {
                  final nextScale = (_startScale * details.scale).clamp(
                    0.64,
                    3.6,
                  );
                  final nextContentWidth = count * baseStepWidth * nextScale;
                  final nextMinOffset = math.min(
                    0.0,
                    _viewportWidth - nextContentWidth,
                  );
                  setState(() {
                    _scale = nextScale;
                    _offsetX = (_startOffset + details.focalPointDelta.dx)
                        .clamp(nextMinOffset, 0.0);
                    _startOffset = _offsetX;
                  });
                },
                child: CustomPaint(
                  painter: _MicrotonalPainter(
                    edo: edo,
                    rulerFirst: rulerFirst,
                    rulerLast: rulerLast,
                    touchFirst: touchFirst,
                    touchLast: touchLast,
                    stepWidth: stepWidth,
                    offsetX: paintOffset,
                    selectedStep: widget.selectedStep,
                    valueColors: widget.valueColors,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MicrotonalPainter extends CustomPainter {
  const _MicrotonalPainter({
    required this.edo,
    required this.rulerFirst,
    required this.rulerLast,
    required this.touchFirst,
    required this.touchLast,
    required this.stepWidth,
    required this.offsetX,
    required this.selectedStep,
    required this.valueColors,
  });

  final int edo;
  final int rulerFirst;
  final int rulerLast;
  final int touchFirst;
  final int touchLast;
  final double stepWidth;
  final double offsetX;
  final int? selectedStep;
  final Map<int, Color> valueColors;

  static const _markRatios = <String, double>{
    '0': 1,
    '1': 0.8,
    '2': 0.6,
    '3': 0.4,
    '4': 0.2,
    'N': 0,
    'S': 0,
  };
  static const _xenHighlight = Color(0xFFFFDE6F);

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(7),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF090B0F),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x6028323F), Color(0xD0080A0F), Color(0xF006070A)],
        ).createShader(panel.outerRect),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x22FFFFFF), Colors.transparent, Color(0x30000000)],
        ).createShader(panel.outerRect),
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(offsetX, 0);
    if (selectedStep != null &&
        selectedStep! >= touchFirst &&
        selectedStep! <= touchLast) {
      final x = (selectedStep! - rulerFirst) * stepWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, 2, math.max(2, stepWidth - 2), size.height - 4),
          const Radius.circular(5),
        ),
        Paint()..color = ChordleColors.selected.withValues(alpha: 0.38),
      );
    }

    final pitchStep = 12 / edo;
    final minPitchSpacing = 1.1 * pitchStep / stepWidth;
    final marks = edoScaleMarks[edo] ?? '';
    for (var step = rulerFirst; step <= rulerLast; step++) {
      final x = (step - rulerFirst) * stepWidth + stepWidth / 2;
      if (x + offsetX < -2 || x + offsetX > size.width + 2) continue;
      final octaveStep = _positiveModulo(step, edo);
      final marker = octaveStep < marks.length ? marks[octaveStep] : 'N';
      final baseRatio = _markRatios[marker] ?? 0;
      if (baseRatio <= 0) continue;
      final isC = octaveStep == 0;
      final visibility = _denseLineVisibilityRatio(
        step,
        pitchStep,
        minPitchSpacing,
        isC,
      );
      final ratio = (baseRatio * visibility).clamp(0.0, 1.0);
      if (ratio <= 0) continue;
      final tickLength = size.height * 0.84 * ratio;
      final alpha = (184 * ratio).round().clamp(0, 184);
      final stateColor = valueColors[step];
      final stroke = isC ? 1.4 : 1.0;
      if (stateColor != null) {
        final bandWidth = math.max(4.0, math.min(stepWidth * 0.72, 9.0));
        final bandHeight = math.max(tickLength, size.height * 0.3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - bandWidth / 2, 2, bandWidth, bandHeight),
            const Radius.circular(3),
          ),
          Paint()..color = stateColor.withValues(alpha: 0.18),
        );
        canvas.drawLine(
          Offset(x, 2),
          Offset(x, 2 + tickLength),
          Paint()
            ..color = stateColor.withValues(alpha: 0.26)
            ..strokeWidth = math.max(stroke + 3, 4),
        );
      }
      final lineColor =
          stateColor?.withValues(alpha: math.max(alpha / 255, 0.72)) ??
          _xenHighlight.withValues(alpha: alpha / 255);
      canvas.drawLine(
        Offset(x, 2),
        Offset(x, 2 + tickLength),
        Paint()
          ..color = lineColor
          ..strokeWidth = stateColor != null ? math.max(stroke, 2.6) : stroke,
      );

      if (isC) {
        _paintText(
          canvas,
          'C${step ~/ edo - 1}',
          x,
          size.height - 16,
          10,
          0.72,
        );
      } else if (_shouldDrawStepLabel(marker)) {
        _paintText(
          canvas,
          '$octaveStep',
          x,
          math.min(size.height - 32, 2 + tickLength + 4),
          8,
          0.56,
        );
      }
    }
    canvas.restore();
    canvas.drawLine(
      const Offset(2, 2),
      Offset(size.width - 2, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(2, size.height - 2),
      Offset(size.width - 2, size.height - 2),
      Paint()
        ..color = _xenHighlight.withValues(alpha: 0.66)
        ..strokeWidth = 1,
    );
  }

  bool _shouldDrawStepLabel(String marker) {
    if (marker == '1') return true;
    if (marker != '2' || edo < 20) return false;
    final marks = edoScaleMarks[edo] ?? '';
    return '1'.allMatches(marks).length <= 3;
  }

  void _paintText(
    Canvas canvas,
    String text,
    double centerX,
    double top,
    double fontSize,
    double opacity,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _xenHighlight.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
  }

  @override
  bool shouldRepaint(covariant _MicrotonalPainter oldDelegate) {
    return oldDelegate.edo != edo ||
        oldDelegate.rulerFirst != rulerFirst ||
        oldDelegate.rulerLast != rulerLast ||
        oldDelegate.stepWidth != stepWidth ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.selectedStep != selectedStep ||
        oldDelegate.valueColors != valueColors;
  }
}

int _positiveModulo(int value, int mod) => ((value % mod) + mod) % mod;

double _denseLineVisibilityRatio(
  int stepIndex,
  double step,
  double minPitchSpacing,
  bool isAnchor,
) {
  if (isAnchor || step <= 0.0001 || minPitchSpacing <= 0.0001) return 1;
  final desiredStride = minPitchSpacing / step;
  if (!desiredStride.isFinite || desiredStride <= 1) return 1;
  final fine = desiredStride.floor().clamp(1, 1 << 20);
  final coarse = desiredStride.ceil().clamp(1, 1 << 20);
  if (fine == coarse) return _positiveModulo(stepIndex, coarse) == 0 ? 1 : 0;
  final value = (coarse - desiredStride).clamp(0.0, 1.0);
  final fineWeight = value * value * (3 - 2 * value);
  final coarseWeight = 1 - fineWeight;
  var ratio = 0.0;
  if (_positiveModulo(stepIndex, fine) == 0) {
    ratio = math.max(ratio, fineWeight);
  }
  if (_positiveModulo(stepIndex, coarse) == 0) {
    ratio = math.max(ratio, coarseWeight);
  }
  return ratio >= 0.02 ? ratio : 0;
}

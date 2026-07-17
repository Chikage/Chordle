import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    required this.lowNote,
    required this.highNote,
    required this.selectedNote,
    required this.valueColors,
    required this.onNotePressed,
    this.compact = false,
    super.key,
  });

  final int lowNote;
  final int highNote;
  final int? selectedNote;
  final Map<int, Color> valueColors;
  final ValueChanged<int> onNotePressed;
  final bool compact;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  double _scale = 1;
  double _offsetX = 0;
  double _startScale = 1;
  double _startOffset = 0;
  double _viewportWidth = 0;

  @override
  void didUpdateWidget(PianoKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lowNote != widget.lowNote ||
        oldWidget.highNote != widget.highNote) {
      _scale = 1;
      _offsetX = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final low = math.min(widget.lowNote, widget.highNote).clamp(0, 127);
    final high = math.max(widget.lowNote, widget.highNote).clamp(0, 127);
    final whiteNotes = [
      for (var note = low; note <= high; note++)
        if (!_isBlackKey(note)) note,
    ];
    final blackNotes = [
      for (var note = low; note <= high; note++)
        if (_isBlackKey(note)) note,
    ];

    return SizedBox(
      height: widget.compact ? 138 : 172,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = constraints.maxWidth;
          final baseWhiteWidth = widget.compact ? 36.0 : 42.0;
          final whiteWidth = baseWhiteWidth * _scale;
          final contentWidth = whiteNotes.length * whiteWidth;
          final minOffset = math.min(0.0, constraints.maxWidth - contentWidth);
          final paintOffset = _offsetX.clamp(minOffset, 0.0);

          return Semantics(
            label: '可缩放钢琴键盘，双指缩放，横向拖动',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => setState(() {
                  _scale = 1;
                  _offsetX = 0;
                }),
                onTapUp: (details) {
                  final note = _noteAt(
                    details.localPosition,
                    paintOffset,
                    whiteWidth,
                    constraints.maxHeight,
                    whiteNotes,
                    blackNotes,
                  );
                  if (note != null) widget.onNotePressed(note);
                },
                onScaleStart: (details) {
                  _startScale = _scale;
                  _startOffset = paintOffset;
                },
                onScaleUpdate: (details) {
                  final nextScale = (_startScale * details.scale).clamp(
                    0.72,
                    2.35,
                  );
                  final nextWidth =
                      whiteNotes.length * baseWhiteWidth * nextScale;
                  final nextMinOffset = math.min(
                    0.0,
                    _viewportWidth - nextWidth,
                  );
                  setState(() {
                    _scale = nextScale;
                    _offsetX = (_startOffset + details.focalPointDelta.dx)
                        .clamp(nextMinOffset, 0.0);
                    _startOffset = _offsetX;
                  });
                },
                child: CustomPaint(
                  painter: _PianoPainter(
                    whiteNotes: whiteNotes,
                    blackNotes: blackNotes,
                    whiteWidth: whiteWidth,
                    offsetX: paintOffset,
                    selectedNote: widget.selectedNote,
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

  int? _noteAt(
    Offset position,
    double offsetX,
    double whiteWidth,
    double height,
    List<int> whiteNotes,
    List<int> blackNotes,
  ) {
    final localX = position.dx - offsetX;
    if (localX < 0) return null;
    final blackWidth = whiteWidth * 0.62;
    final blackHeight = height * 0.62;
    if (position.dy <= blackHeight) {
      for (final note in blackNotes.reversed) {
        final before = whiteNotes.where((white) => white < note).length;
        final keyX = before * whiteWidth - blackWidth / 2;
        if (localX >= keyX && localX <= keyX + blackWidth) return note;
      }
    }
    final index = (localX / whiteWidth).floor();
    return index >= 0 && index < whiteNotes.length ? whiteNotes[index] : null;
  }
}

class _PianoPainter extends CustomPainter {
  const _PianoPainter({
    required this.whiteNotes,
    required this.blackNotes,
    required this.whiteWidth,
    required this.offsetX,
    required this.selectedNote,
    required this.valueColors,
  });

  final List<int> whiteNotes;
  final List<int> blackNotes;
  final double whiteWidth;
  final double offsetX;
  final int? selectedNote;
  final Map<int, Color> valueColors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F0F10),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(offsetX, 0);
    const gap = 1.4;
    const radius = Radius.circular(5);

    for (var index = 0; index < whiteNotes.length; index++) {
      final note = whiteNotes[index];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * whiteWidth + gap / 2,
          0,
          whiteWidth - gap,
          size.height,
        ),
        radius,
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFFE9EAEC));
      _paintOverlay(canvas, rect, note);
      final label = _noteLabel(note);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF27272A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          index * whiteWidth + (whiteWidth - painter.width) / 2,
          size.height - painter.height - 9,
        ),
      );
    }

    final blackWidth = whiteWidth * 0.62;
    final blackHeight = size.height * 0.62;
    for (final note in blackNotes) {
      final before = whiteNotes.where((white) => white < note).length;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          before * whiteWidth - blackWidth / 2,
          0,
          blackWidth,
          blackHeight,
        ),
        radius,
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFF151518));
      _paintOverlay(canvas, rect, note);
    }
    canvas.restore();
  }

  void _paintOverlay(Canvas canvas, RRect rect, int note) {
    final stateColor = valueColors[note];
    if (stateColor != null) {
      canvas.drawRRect(
        rect,
        Paint()..color = stateColor.withValues(alpha: 0.58),
      );
    }
    if (note == selectedNote) {
      canvas.drawRRect(
        rect,
        Paint()..color = ChordleColors.selected.withValues(alpha: 0.38),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PianoPainter oldDelegate) {
    return oldDelegate.whiteNotes != whiteNotes ||
        oldDelegate.blackNotes != blackNotes ||
        oldDelegate.whiteWidth != whiteWidth ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.selectedNote != selectedNote ||
        oldDelegate.valueColors != valueColors;
  }
}

bool _isBlackKey(int midiNote) => switch (midiNote % 12) {
  1 || 3 || 6 || 8 || 10 => true,
  _ => false,
};

String _noteLabel(int midiNote) {
  const names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final octave = midiNote ~/ 12 - 1;
  return '${names[midiNote % 12]}$octave';
}

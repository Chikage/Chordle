import 'package:flutter/material.dart';

import '../theme.dart';

class OvertoneNumberPad extends StatelessWidget {
  const OvertoneNumberPad({
    required this.low,
    required this.high,
    required this.selected,
    required this.valueColors,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final int low;
  final int high;
  final int? selected;
  final Map<int, Color> valueColors;
  final ValueChanged<int> onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final values = [for (var value = low; value <= high; value++) value];
    final columns = values.length <= 10 ? 5 : 8;
    final rows = <List<int>>[];
    for (var index = 0; index < values.length; index += columns) {
      rows.add(
        values.sublist(index, (index + columns).clamp(0, values.length)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          Row(
            children: [
              for (var index = 0; index < columns; index++) ...[
                Expanded(
                  child: index < rows[rowIndex].length
                      ? _NumberButton(
                          value: rows[rowIndex][index],
                          selected: rows[rowIndex][index] == selected,
                          stateColor: valueColors[rows[rowIndex][index]],
                          compact: compact,
                          onPressed: onPressed,
                        )
                      : SizedBox(height: compact ? 34 : 42),
                ),
                if (index != columns - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (rowIndex != rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.value,
    required this.selected,
    required this.stateColor,
    required this.compact,
    required this.onPressed,
  });

  final int value;
  final bool selected;
  final Color? stateColor;
  final bool compact;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? ChordleColors.selected.withValues(alpha: 0.38)
        : stateColor?.withValues(alpha: 0.58) ?? ChordleColors.surface;
    return SizedBox(
      height: compact ? 34 : 42,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: () => onPressed(value),
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

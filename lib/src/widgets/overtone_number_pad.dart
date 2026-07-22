import 'package:flutter/material.dart';

import '../theme.dart';

class OvertoneNumberPad extends StatelessWidget {
  const OvertoneNumberPad({
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onConfirm,
    required this.canBackspace,
    required this.canConfirm,
    this.compact = false,
    super.key,
  });

  final ValueChanged<int> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onConfirm;
  final bool canBackspace;
  final bool canConfirm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const rows = <List<int>>[
      <int>[1, 2, 3, 4, 5, 6],
      <int>[7, 8, 9, 0, _backspaceKey, _confirmKey],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...<Widget>[
          Row(
            children: [
              for (var index = 0; index < rows[rowIndex].length; index++) ...[
                Expanded(
                  child: switch (rows[rowIndex][index]) {
                    _backspaceKey => _ActionButton(
                      icon: Icons.backspace_outlined,
                      tooltip: '退格',
                      enabled: canBackspace,
                      compact: compact,
                      onPressed: onBackspace,
                    ),
                    _confirmKey => _ActionButton(
                      icon: Icons.check_rounded,
                      tooltip: '确认数字',
                      enabled: canConfirm,
                      compact: compact,
                      onPressed: onConfirm,
                    ),
                    final digit => _NumberButton(
                      value: digit,
                      compact: compact,
                      onPressed: onDigitPressed,
                    ),
                  },
                ),
                if (index != rows[rowIndex].length - 1)
                  const SizedBox(width: 6),
              ],
            ],
          ),
          if (rowIndex != rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

const int _backspaceKey = -1;
const int _confirmKey = -2;

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.value,
    required this.compact,
    required this.onPressed,
  });

  final int value;
  final bool compact;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 38 : 46,
      child: Material(
        color: ChordleColors.elevatedSurface,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          key: ValueKey<String>('overtone-digit-$value'),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 38 : 46,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: enabled
              ? ChordleColors.elevatedSurface
              : ChordleColors.surface,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            key: ValueKey<String>('overtone-$tooltip'),
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(7),
            child: Icon(
              icon,
              size: compact ? 19 : 22,
              color: enabled ? ChordleColors.text : ChordleColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

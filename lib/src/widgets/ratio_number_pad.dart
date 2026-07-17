import 'package:flutter/material.dart';

import '../theme.dart';

class RatioNumberPad extends StatelessWidget {
  const RatioNumberPad({
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onClear,
    this.compact = false,
    super.key,
  });

  final ValueChanged<String> onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['/', '0', 'backspace'],
    ];

    return Container(
      height: compact ? 138 : 172,
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090B0F),
        border: Border.all(color: ChordleColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (final row in rows)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          for (var index = 0; index < row.length; index++) ...[
                            if (index > 0) const SizedBox(width: 4),
                            Expanded(
                              child: _RatioKey(
                                keyText: row[index],
                                onKeyPressed: onKeyPressed,
                                onBackspace: onBackspace,
                                onClear: onClear,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioKey extends StatelessWidget {
  const _RatioKey({
    required this.keyText,
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onClear,
  });

  final String keyText;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final backspace = keyText == 'backspace';
    return Material(
      color: ChordleColors.elevatedSurface,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: backspace ? onBackspace : () => onKeyPressed(keyText),
        onLongPress: backspace ? onClear : null,
        child: Center(
          child: backspace
              ? const Icon(Icons.backspace_outlined, size: 22)
              : Text(
                  keyText,
                  style: const TextStyle(
                    color: ChordleColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

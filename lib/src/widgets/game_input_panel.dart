import 'package:flutter/material.dart';

import '../theme.dart';

class GameInputPanel extends StatelessWidget {
  const GameInputPanel({
    required this.selectedText,
    required this.confirmText,
    required this.canConfirm,
    required this.canDelete,
    required this.canSubmit,
    required this.audioReady,
    required this.onPlayTarget,
    required this.onConfirm,
    required this.onDelete,
    required this.onSubmit,
    required this.input,
    this.answerText,
    this.compact = false,
    this.playText = '播放和弦',
    this.playIcon = Icons.play_arrow_rounded,
    this.deleteText = '删除',
    this.submitText = '提交',
    super.key,
  });

  final String selectedText;
  final String confirmText;
  final bool canConfirm;
  final bool canDelete;
  final bool canSubmit;
  final bool audioReady;
  final VoidCallback onPlayTarget;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final Widget input;
  final String? answerText;
  final bool compact;
  final String playText;
  final IconData playIcon;
  final String deleteText;
  final String submitText;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ChordleColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 11,
                  child: SizedBox(
                    height: 43,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: audioReady ? onPlayTarget : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(playIcon, size: 20),
                          const SizedBox(width: 5),
                          Flexible(child: _FittedSingleLineText(playText)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: Container(
                    height: 43,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: ChordleColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _FittedSingleLineText(
                      selectedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ChordleColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: canConfirm ? onConfirm : null,
                    child: _FittedSingleLineText(confirmText),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 7,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: canDelete ? onDelete : null,
                    child: _FittedSingleLineText(deleteText),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 8,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ChordleColors.gray,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: canSubmit ? onSubmit : null,
                    child: _FittedSingleLineText(submitText),
                  ),
                ),
              ],
            ),
            if (answerText != null) ...[
              const SizedBox(height: 6),
              Text(
                answerText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ChordleColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ],
            SizedBox(height: compact ? 5 : 8),
            input,
          ],
        ),
      ),
    );
  }
}

class _FittedSingleLineText extends StatelessWidget {
  const _FittedSingleLineText(
    this.text, {
    this.textAlign = TextAlign.center,
    this.style,
  });

  final String text;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

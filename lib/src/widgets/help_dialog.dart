import 'package:flutter/material.dart';

import '../models/chordle_mode.dart';
import '../theme.dart';

Future<void> showChordleHelpDialog(BuildContext context, ChordleMode mode) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Chordle'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mode == ChordleMode.overtones) ...[
                const Text('每局会随机选择一个基音，并从设置的整数区间生成倍频数组。'),
                const SizedBox(height: 8),
                const Text('可按任意顺序输入倍频数，提交后按从小到大的答案位置验证。'),
              ] else ...[
                const Text('会按设置随机播放 1–10 个音，1 为单音测试。'),
                const SizedBox(height: 8),
                const Text('可按任意顺序输入音符，提交后按从低到高的答案位置验证。'),
              ],
              const SizedBox(height: 14),
              const _RuleRow(color: ChordleColors.green, text: '绿色：音高和位置都完全正确'),
              if (mode == ChordleMode.extra) ...[
                const _RuleRow(
                  color: ChordleColors.extraCorrect,
                  text: '淡蓝：该位置音高误差在 50 音分内',
                ),
                const _RuleRow(
                  color: ChordleColors.yellow,
                  text: '黄色：音高完全正确，但位置不对',
                ),
                const _RuleRow(
                  color: ChordleColors.extraNear,
                  text: '淡粉：和弦内有 50 音分内的近似音，但位置不对',
                ),
                const _RuleRow(
                  color: ChordleColors.gray,
                  text: '灰色：和弦里没有 50 音分内的音',
                ),
                const SizedBox(height: 8),
                const Text(
                  '只有全部精确绿色才算胜利。',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ] else ...[
                const _RuleRow(
                  color: ChordleColors.yellow,
                  text: '黄色：有这个音，但位置不对',
                ),
                const _RuleRow(color: ChordleColors.gray, text: '灰色：和弦里没有这个音'),
              ],
              const SizedBox(height: 12),
              const Text(
                '提示：长按上一行的绿色格可固定到同列，黄色格可拖到其他列。',
                style: TextStyle(
                  color: ChordleColors.dialogMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ChordleColors.dialogText,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

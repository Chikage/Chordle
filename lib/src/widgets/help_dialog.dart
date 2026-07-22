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
                const Text('每局固定使用 JI，从设置区间抽取整数比例，并按 MCQ 的音区概率选择可听的实际最低音。'),
                const SizedBox(height: 8),
                const Text(
                  '最小数字对应实际最低音，其余音按相对最小数字的精确频率比生成。'
                  '可按任意顺序输入比例数字，提交后按从小到大的答案位置验证。'
                  '整组数字约分后比例相同也算正确，且适用于两个或多个数字。'
                  '例如 8:10:15 会播放为 1、10/8、15/8；约分等价答案仍然正确。',
                ),
              ] else ...[
                const Text('会按设置随机播放 1–10 个音，1 为单音测试。'),
                const SizedBox(height: 8),
                const Text('可按任意顺序输入音符，提交后按从低到高的答案位置验证。'),
              ],
              const SizedBox(height: 14),
              _RuleRow(
                color: ChordleColors.green,
                text: mode == ChordleMode.overtones
                    ? '绿色：数字和位置完全正确，或整组为等价比例'
                    : '绿色：音高和位置都完全正确',
              ),
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
                _RuleRow(
                  color: ChordleColors.yellow,
                  text: mode == ChordleMode.overtones
                      ? '黄色：原比例或约分比例中有这个数字'
                      : '黄色：有这个音，但位置不对',
                ),
                _RuleRow(
                  color: ChordleColors.gray,
                  text: mode == ChordleMode.overtones
                      ? '灰色：原比例和约分比例中都没有这个数字'
                      : '灰色：和弦里没有这个音',
                ),
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

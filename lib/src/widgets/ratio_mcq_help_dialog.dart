import 'package:flutter/material.dart';

import '../theme.dart';

Future<void> showRatioMcqHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('MCQ of Ratio'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('每题会从设置中随机选择一种 EDO 调律或 JI（纯律），并播放 A、B 两个音。'),
              SizedBox(height: 10),
              Text('请选择从 A 到 B 的有理比例。题目右侧的播放键会同时播放整组 A、B。'),
              SizedBox(height: 10),
              Text('在 EDO 中，不同有理比例可能精确映射到同一个 Step。出现多个正确选项时，题目会自动改用复选框。'),
              SizedBox(height: 14),
              Text('计分', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('• 单一正确答案：答对得 1 分，答错得 0 分。'),
              Text('• 多个正确答案：每选中一个正确项 +1 分，每选中一个错误项 −1 分，本题最低 0 分。'),
              Text('• 本题总分等于已显示的正确答案数量；页面显示累计“得分/总分”。'),
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

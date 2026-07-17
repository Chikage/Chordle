import 'package:flutter/material.dart';

import '../theme.dart';

class ChordleHeader extends StatelessWidget {
  const ChordleHeader({
    required this.modeLabel,
    required this.onBack,
    required this.onHelp,
    required this.onSettings,
    super.key,
  });

  final String modeLabel;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ChordleColors.background,
          border: Border(
            bottom: BorderSide(
              color: ChordleColors.border.withValues(alpha: 0.65),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: IconButton(
                onPressed: onBack,
                tooltip: '返回模式选择',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
            ),
            IconButton(
              onPressed: onHelp,
              tooltip: '游戏规则',
              icon: const Icon(Icons.help_outline_rounded, size: 23),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chordle',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: ChordleColors.text,
                      fontFamily: chordleWordmarkFontFamily(
                        Theme.of(context).platform,
                      ),
                      fontSize: 27,
                      height: 0.95,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    modeLabel,
                    style: const TextStyle(
                      color: ChordleColors.muted,
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 102,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onSettings,
                  tooltip: '游戏设置',
                  icon: const Icon(Icons.settings_rounded, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AudioIndicatorState { loading, ready, error }

class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    required this.detailText,
    required this.attempt,
    required this.maxAttempts,
    required this.audioState,
    required this.onNewPuzzle,
    this.audioMessage,
    super.key,
  });

  final String detailText;
  final int attempt;
  final int maxAttempts;
  final AudioIndicatorState audioState;
  final String? audioMessage;
  final VoidCallback onNewPuzzle;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (audioState) {
      AudioIndicatorState.loading => '音色加载中',
      AudioIndicatorState.ready => '音频就绪',
      AudioIndicatorState.error => audioMessage ?? '音频引擎启动失败',
    };
    final statusColor = switch (audioState) {
      AudioIndicatorState.loading => ChordleColors.yellow,
      AudioIndicatorState.ready => ChordleColors.green,
      AudioIndicatorState.error => ChordleColors.error,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      color: ChordleColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              detailText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ChordleColors.muted,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              statusText,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${attempt.clamp(1, maxAttempts)}/$maxAttempts',
            style: const TextStyle(
              color: ChordleColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: onNewPuzzle,
            tooltip: '重新开始',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt_rounded, size: 23),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/chordle_mode.dart';
import '../theme.dart';

extension on ChordleMode {
  String get label => switch (this) {
    ChordleMode.normal => 'Normal',
    ChordleMode.extra => 'Extra',
    ChordleMode.overtones => 'Overtones',
  };

  String get description => switch (this) {
    ChordleMode.normal => '标准十二平均律和弦听辨',
    ChordleMode.extra => '1–72 EDO 微分音听辨',
    ChordleMode.overtones => '基音与整数倍频听辨',
  };
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({required this.onModeSelected, super.key});

  final ValueChanged<ChordleMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final maxWidth = landscape ? 720.0 : 460.0;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: landscape ? 42 : 28,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: landscape
                      ? _LandscapeContent(onModeSelected: onModeSelected)
                      : _PortraitContent(onModeSelected: onModeSelected),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PortraitContent extends StatelessWidget {
  const _PortraitContent({required this.onModeSelected});

  final ValueChanged<ChordleMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Brand(),
        const SizedBox(height: 38),
        ...ChordleMode.values.map(
          (mode) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ModeButton(
              mode: mode,
              onPressed: () => onModeSelected(mode),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandscapeContent extends StatelessWidget {
  const _LandscapeContent({required this.onModeSelected});

  final ValueChanged<ChordleMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _Brand()),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ChordleMode.values
                .map(
                  (mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ModeButton(
                      mode: mode,
                      onPressed: () => onModeSelected(mode),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LogoMark(),
        const SizedBox(height: 18),
        Text(
          'Chordle',
          style: TextStyle(
            color: ChordleColors.text,
            fontFamily: chordleWordmarkFontFamily(Theme.of(context).platform),
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '选择模式',
          style: TextStyle(
            color: ChordleColors.muted,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.onPressed});

  final ChordleMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = mode == ChordleMode.normal;
    final child = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mode.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.82)
                      : ChordleColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_forward_rounded,
          color: primary ? Colors.white : ChordleColors.muted,
        ),
      ],
    );

    if (primary) {
      return SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton(onPressed: onPressed, child: child),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    const colors = [
      ChordleColors.green,
      ChordleColors.green,
      ChordleColors.green,
      ChordleColors.yellow,
      ChordleColors.yellow,
      ChordleColors.yellow,
      ChordleColors.border,
      ChordleColors.border,
      ChordleColors.border,
    ];
    return SizedBox(
      width: 82,
      height: 82,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemCount: colors.length,
        itemBuilder: (context, index) => DecoratedBox(
          decoration: BoxDecoration(
            color: colors[index],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

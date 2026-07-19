import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chordle_mode.dart';
import '../theme.dart';

final _repositoryUri = Uri.parse('https://github.com/Chikage/Chordle');

Future<void> _openRepository(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(
      _repositoryUri,
      mode: LaunchMode.externalApplication,
    );
  } on Exception {
    // Show the fallback message below when the platform cannot open the URL.
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 链接')));
  }
}

enum _HomeMode { normal, extra, ratioMcq, overtones, free }

extension on _HomeMode {
  String get label => switch (this) {
    _HomeMode.normal => 'Normal',
    _HomeMode.extra => 'Extra',
    _HomeMode.ratioMcq => 'MCQ of Ratio',
    _HomeMode.free => 'Free',
    _HomeMode.overtones => 'Overtones',
  };

  String get description => switch (this) {
    _HomeMode.normal => '标准十二平均律和弦听辨',
    _HomeMode.extra => '1–72 EDO 微分音听辨',
    _HomeMode.ratioMcq => '在 EDO 与纯律中辨认有理比例',
    _HomeMode.free => '自由设置并试听 EDO 和弦',
    _HomeMode.overtones => '基音与整数倍频听辨',
  };

  Color? get buttonBackgroundColor => switch (this) {
    _HomeMode.normal => ChordleColors.green,
    _HomeMode.extra => ChordleColors.yellow,
    _HomeMode.ratioMcq => ChordleColors.ratioMcq,
    _HomeMode.free => null,
    _HomeMode.overtones => ChordleColors.iconGray,
  };

  Color get buttonForegroundColor => switch (this) {
    _HomeMode.ratioMcq => const Color(0xFF172033),
    _ => Colors.white,
  };
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({
    required this.onModeSelected,
    required this.onRatioMcqSelected,
    required this.onFreeSelected,
    super.key,
  });

  final ValueChanged<ChordleMode> onModeSelected;
  final VoidCallback onRatioMcqSelected;
  final VoidCallback onFreeSelected;

  void _selectMode(_HomeMode mode) {
    switch (mode) {
      case _HomeMode.normal:
        onModeSelected(ChordleMode.normal);
      case _HomeMode.extra:
        onModeSelected(ChordleMode.extra);
      case _HomeMode.ratioMcq:
        onRatioMcqSelected();
      case _HomeMode.overtones:
        onModeSelected(ChordleMode.overtones);
      case _HomeMode.free:
        onFreeSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: 8),
        child: SizedBox(height: 48, child: Center(child: _GithubLink())),
      ),
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
                      ? _LandscapeContent(onModeSelected: _selectMode)
                      : _PortraitContent(onModeSelected: _selectMode),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GithubLink extends StatelessWidget {
  const _GithubLink();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: '在 GitHub 上查看 Chikage/Chordle',
      child: IconButton(
        key: const Key('github_repository_link'),
        tooltip: 'Chikage/Chordle on GitHub',
        onPressed: () => _openRepository(context),
        icon: const FaIcon(
          FontAwesomeIcons.github,
          color: ChordleColors.muted,
          size: 24,
        ),
      ),
    );
  }
}

class _PortraitContent extends StatelessWidget {
  const _PortraitContent({required this.onModeSelected});

  final ValueChanged<_HomeMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Brand(),
        const SizedBox(height: 38),
        ..._HomeMode.values.map(
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

  final ValueChanged<_HomeMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _Brand()),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _HomeMode.values
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

  final _HomeMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = mode.buttonBackgroundColor;
    final filled = backgroundColor != null;
    final foregroundColor = mode.buttonForegroundColor;
    final child = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode.label,
                style: TextStyle(
                  color: filled ? foregroundColor : null,
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
                  color: filled
                      ? foregroundColor.withValues(alpha: 0.78)
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
          color: filled ? foregroundColor : ChordleColors.muted,
        ),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          ),
          onPressed: onPressed,
          child: child,
        ),
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
      ChordleColors.iconGray,
      ChordleColors.iconGray,
      ChordleColors.iconGray,
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

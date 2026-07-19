import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/chordle_mode.dart';
import 'screens/free_screen.dart';
import 'screens/game_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/ratio_mcq_screen.dart';
import 'theme.dart';

class ChordleApp extends StatelessWidget {
  const ChordleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chordle',
      debugShowCheckedModeBanner: false,
      theme: buildChordleTheme(),
      home: const _AppHome(),
    );
  }
}

class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: ChordleColors.background,
        systemNavigationBarColor: ChordleColors.background,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ModeSelectionScreen(
        onModeSelected: (mode) => _openGame(context, mode),
        onRatioMcqSelected: () => _openRatioMcq(context),
        onFreeSelected: () => _openFree(context),
      ),
    );
  }

  Future<void> _openGame(BuildContext context, ChordleMode mode) {
    return _openScreen(context, GameScreen(mode: mode));
  }

  Future<void> _openFree(BuildContext context) {
    return _openScreen(context, const FreeScreen());
  }

  Future<void> _openRatioMcq(BuildContext context) {
    return _openScreen(context, const RatioMcqScreen());
  }

  Future<void> _openScreen(BuildContext context, Widget screen) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }
}

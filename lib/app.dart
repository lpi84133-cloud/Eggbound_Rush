import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/boot/boot_controller.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';

/// The native game. Start-up already finished before this is built, so it
/// opens straight into onboarding or the shell.
class EggboundRushApp extends StatelessWidget {
  const EggboundRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eggbound Rush',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootFlow(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child!,
      ),
    );
  }
}

enum _Stage { onboarding, ready }

class _RootFlow extends ConsumerStatefulWidget {
  const _RootFlow();

  @override
  ConsumerState<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends ConsumerState<_RootFlow> {
  late _Stage _stage;

  @override
  void initState() {
    super.initState();
    // The game is portrait-only. The lock lives here rather than in start-up
    // because a launch that ends in the WebView must stay free to rotate.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _stage = ref.read(servicesProvider).needsOnboarding
        ? _Stage.onboarding
        : _Stage.ready;
  }

  Future<void> _onOnboardingFinished() async {
    await ref.read(servicesProvider).preferences.setOnboarded();
    if (mounted) setState(() => _stage = _Stage.ready);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      child: switch (_stage) {
        _Stage.onboarding => OnboardingScreen(
          key: const ValueKey('onboarding'),
          onFinished: _onOnboardingFinished,
        ),
        _Stage.ready => const AppShell(key: ValueKey('shell')),
      },
    );
  }
}

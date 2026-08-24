import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/boot/boot_controller.dart';
import 'features/boot/loading_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';

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

enum _Stage { loading, onboarding, ready }

class _RootFlow extends ConsumerStatefulWidget {
  const _RootFlow();

  @override
  ConsumerState<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends ConsumerState<_RootFlow> {
  _Stage _stage = _Stage.loading;

  void _onBootFinished() {
    final services = ref.read(bootControllerProvider).services;
    setState(() {
      _stage = (services?.needsOnboarding ?? true)
          ? _Stage.onboarding
          : _Stage.ready;
    });
  }

  Future<void> _onOnboardingFinished() async {
    await ref.read(bootControllerProvider).services?.preferences.setOnboarded();
    if (mounted) setState(() => _stage = _Stage.ready);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      child: switch (_stage) {
        _Stage.loading =>
          LoadingScreen(key: const ValueKey('loading'), onReady: _onBootFinished),
        _Stage.onboarding => OnboardingScreen(
            key: const ValueKey('onboarding'),
            onFinished: _onOnboardingFinished,
          ),
        _Stage.ready => const AppShell(key: ValueKey('shell')),
      },
    );
  }
}

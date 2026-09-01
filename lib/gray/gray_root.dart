import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/theme/app_theme.dart';
import '../features/boot/loading_screen.dart';
import 'gray_router.dart';
import 'portal_webview.dart';

enum _Launch { loading, webview, game }

/// Root widget. The game loading screen owns the whole launch: it runs the
/// native boot, waits for the server decision and only hands over once its
/// progress bar has actually reached the end. Whatever comes next — the
/// WebView or the native game — is therefore never shown mid-fill.
class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  var _launch = _Launch.loading;

  void _onLaunchFinished() {
    final decision = ref.read(grayRouterProvider);
    setState(() {
      _launch = decision.kind == GrayKind.webview
          ? _Launch.webview
          : _Launch.game;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_launch) {
      case _Launch.loading:
        return MaterialApp(
          title: 'Eggbound Rush',
          debugShowCheckedModeBanner: false,
          // Same theme as the game, so a launch that ends there is a plain
          // screen change with no palette flash.
          theme: buildAppTheme(),
          home: LoadingScreen(onReady: _onLaunchFinished),
        );
      case _Launch.webview:
        final url = ref.read(grayRouterProvider).url!;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF8FD14F),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF8FD14F),
            useMaterial3: true,
          ),
          home: PortalWebView(url: url),
        );
      case _Launch.game:
        return const EggboundRushApp();
    }
  }
}

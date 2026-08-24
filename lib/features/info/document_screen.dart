import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';

/// Shows a legal or support document. The bundled copy is the default source,
/// so the screen is fully readable with no connection; the online version is
/// opt-in and silently falls back if it cannot be reached.
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
    required this.onlineUrl,
  });

  final String title;
  final String assetPath;
  final String onlineUrl;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  late final WebViewController _controller;
  String? _html;
  bool _showingOnline = false;
  bool _loading = true;
  bool _fellBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!error.isForMainFrame!) return;
            _loadOffline(fellBack: true);
          },
          onHttpError: (_) => _loadOffline(fellBack: true),
        ),
      );
    _loadOffline();
  }

  Future<void> _loadOffline({bool fellBack = false}) async {
    _html ??= await rootBundle.loadString(widget.assetPath);
    if (!mounted) return;
    setState(() {
      _showingOnline = false;
      _fellBack = fellBack;
      _loading = true;
    });
    await _controller.loadHtmlString(_html!);
  }

  Future<void> _loadOnline() async {
    setState(() {
      _showingOnline = true;
      _fellBack = false;
      _loading = true;
    });
    await _controller.loadRequest(Uri.parse(widget.onlineUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          RibbonHeader(
            title: widget.title,
            subtitle: _showingOnline
                ? 'Online version'
                : 'Offline copy included in the app',
            onBack: () => Navigator.of(context).pop(),
          ),
          if (_fellBack)
            Container(
              width: double.infinity,
              color: AppColors.shell,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Text(
                'The online version is not reachable right now, so the copy '
                'bundled with the app is shown instead.',
                style: AppText.caption,
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const ColoredBox(
                    color: Colors.white,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Offline copy',
                      icon: Icons.offline_pin_rounded,
                      tone: _showingOnline ? PillTone.quiet : PillTone.primary,
                      expand: true,
                      onPressed: _showingOnline ? _loadOffline : null,
                    ),
                  ),
                  const SizedBox(width: AppGap.sm),
                  Expanded(
                    child: PillButton(
                      label: 'Online version',
                      icon: Icons.public_rounded,
                      tone: _showingOnline ? PillTone.primary : PillTone.quiet,
                      expand: true,
                      onPressed: _showingOnline ? null : _loadOnline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

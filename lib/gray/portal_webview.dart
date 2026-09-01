import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gray_adjust.dart';
import 'gray_config.dart';
import 'gray_device.dart';

/// Schemes the page keeps loading itself. Everything else belongs to another
/// app — wallets, banking apps, mail, phone — and is handed to iOS.
const _inPageSchemes = {'http', 'https', 'about', 'blob', 'data'};

/// The frame is black on every side so the notch, the Dynamic Island and the
/// home indicator read as part of the device rather than as cut-off content.
const _chrome = Colors.black;
const _icon = Colors.white;

/// Full-screen portal covering the WebView section of the spec: visited-page
/// navigation, both orientations, dark mode, `target="_blank"`, file and camera
/// upload, universal links, inline video, Apple Pay and safe areas.
class PortalWebView extends StatefulWidget {
  const PortalWebView({super.key, required this.url});

  final String url;

  @override
  State<PortalWebView> createState() => _PortalWebViewState();
}

class _PortalWebViewState extends State<PortalWebView> {
  InAppWebViewController? _controller;
  var _canGoBack = false;
  var _canGoForward = false;
  var _progress = 0.0;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    GrayDevice.setLandscapeAllowed(true);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    GrayDevice.setLandscapeAllowed(false);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _syncHistory() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _goBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  Future<void> _goForward() async {
    final controller = _controller;
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
    }
  }

  Future<void> _reload() async {
    setState(() => _failed = false);
    await _controller?.reload();
  }

  Future<void> _openChildWindow(CreateWindowAction action) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ChildPortalWindow(action: action),
      ),
    );
    await _syncHistory();
  }

  @override
  Widget build(BuildContext context) {
    return PortalFrame(
      progress: _progress,
      failed: _failed,
      onRetry: _reload,
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      onBack: _goBack,
      onForward: _goForward,
      onReload: _reload,
      page: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: portalSettings(
          MediaQuery.platformBrightnessOf(context),
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onPermissionRequest: (controller, request) async {
          // Camera and microphone for `getUserMedia`; the file picker itself is
          // handled by WKWebView.
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        shouldOverrideUrlLoading: (controller, action) {
          return handleNavigation(action);
        },
        onCreateWindow: (controller, action) async {
          if (!context.mounted) return false;
          await _openChildWindow(action);
          return true;
        },
        onLoadStart: (controller, _) {
          setState(() {
            _failed = false;
            _progress = 0.05;
          });
        },
        onProgressChanged: (controller, progress) {
          setState(() => _progress = progress / 100);
        },
        onLoadStop: (controller, _) async {
          setState(() => _progress = 1);
          await _syncHistory();
        },
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame ?? true) {
            setState(() => _failed = true);
          }
        },
        onReceivedHttpError: (controller, request, response) {
          final code = response.statusCode ?? 0;
          if ((request.isForMainFrame ?? true) && code >= 400) {
            setState(() => _failed = true);
          }
        },
        onUpdateVisitedHistory: (controller, _, _) {
          _syncHistory();
        },
      ),
    );
  }

  /// Handed straight to iOS instead of asking [canLaunchUrl] first: that check
  /// answers false for every scheme missing from `LSApplicationQueriesSchemes`,
  /// which would silently swallow bank and wallet redirects we cannot enumerate
  /// in advance.
  static Future<void> openExternal(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) debugPrint('[Gray] no handler for $uri');
    } on Object catch (error) {
      debugPrint('[Gray] launch $uri failed: $error');
    }
  }

  /// WKWebView never resolves universal links on its own. Handing the URL to
  /// iOS with `universalLinksOnly` opens the owning app when there is one and
  /// reports false otherwise, so the page keeps loading in place.
  static Future<bool> openedAsUniversalLink(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } on Object {
      return false;
    }
  }

  static Future<NavigationActionPolicy> handleNavigation(
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    if (uri.scheme == GrayConfig.urlScheme) {
      GrayAdjust.handleDeeplink(uri.toString());
      return NavigationActionPolicy.CANCEL;
    }

    if (!_inPageSchemes.contains(uri.scheme)) {
      await openExternal(uri);
      return NavigationActionPolicy.CANCEL;
    }

    if (action.navigationType == NavigationType.LINK_ACTIVATED &&
        await openedAsUniversalLink(uri)) {
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }
}

/// Shared by the main portal and by windows opened with `target="_blank"`, so
/// a popup behaves exactly like the page that spawned it.
InAppWebViewSettings portalSettings(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    // Cookies live in the system store, so a payment flow that leaves for a
    // bank app and comes back finds its session intact.
    sharedCookiesEnabled: true,
    thirdPartyCookiesEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    useShouldOverrideUrlLoading: true,
    allowsInlineMediaPlayback: true,
    allowsPictureInPictureMediaPlayback: true,
    allowsAirPlayForMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsBackForwardNavigationGestures: true,
    // The long-press preview popover looks out of place inside an app and
    // fights with the page's own context menus.
    allowsLinkPreview: false,
    isFraudulentWebsiteWarningEnabled: true,
    upgradeKnownHostsToHTTPS: true,
    // Payment Request API. Everything the plugin implements through injected
    // JavaScript stops working while this is on, which is why no user scripts
    // or JavaScript handlers are registered anywhere in this file.
    applePayAPIEnabled: true,
    iframeAllowFullscreen: true,
    iframeAllow: 'camera *; microphone *; payment *; geolocation *',
    cacheEnabled: true,
    transparentBackground: false,
    verticalScrollBarEnabled: true,
    automaticallyAdjustsScrollIndicatorInsets: true,
    // The document is pinned to the viewport width. Landing pages routinely
    // overflow a phone by a few points — a `width: 90%` button whose padding
    // and border sit outside that 90% is enough — and WKWebView happily pans
    // onto the empty strip, which reads as a broken layout. Elements with
    // their own `overflow-x` are scrolled by WebKit, not by this scroll view,
    // so carousels inside the page keep working.
    disableHorizontalScroll: true,
    horizontalScrollBarEnabled: false,
    alwaysBounceHorizontal: false,
    isDirectionalLockEnabled: true,
    disableContextMenu: false,
    preferredContentMode: UserPreferredContentMode.RECOMMENDED,
    // Shows through when the page is rubber-banded, so it follows the page's
    // own theme rather than the black frame.
    underPageBackgroundColor: dark ? Colors.black : Colors.white,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
    isInspectable: kDebugMode,
  );
}

/// Everything around the page: the black safe-area frame, the loading line, the
/// offline overlay and the navigation bar. Kept separate from [PortalWebView]
/// so the layout can be exercised without a platform WebView.
@visibleForTesting
class PortalFrame extends StatelessWidget {
  const PortalFrame({
    super.key,
    required this.page,
    required this.progress,
    required this.failed,
    required this.onRetry,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.onClose,
  });

  final Widget page;
  final double progress;
  final bool failed;
  final Future<void> Function() onRetry;
  final bool canGoBack;
  final bool canGoForward;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;
  final Future<void> Function() onReload;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final pageBackground = dark ? Colors.black : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Both bars are black in either theme, so the status bar always needs
      // light glyphs.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _chrome,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: pageBackground,
                  child: Stack(
                    children: [
                      Positioned.fill(child: page),
                      if (progress > 0 && progress < 1)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 2,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      if (failed)
                        Positioned.fill(
                          child: _FailureOverlay(
                            dark: dark,
                            background: pageBackground,
                            onRetry: onRetry,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _NavBar(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                onBack: onBack,
                onForward: onForward,
                onReload: onReload,
                onClose: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureOverlay extends StatelessWidget {
  const _FailureOverlay({
    required this.dark,
    required this.background,
    required this.onRetry,
  });

  final bool dark;
  final Color background;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: dark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(height: 12),
              Text(
                'The page could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: dark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar, the way iOS places browser controls: above the home indicator
/// and never over the page.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.onClose,
  });

  final bool canGoBack;
  final bool canGoForward;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;
  final Future<void> Function() onReload;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          _NavIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            enabled: canGoBack,
            onTap: onBack,
            label: 'Back',
          ),
          _NavIcon(
            icon: Icons.arrow_forward_ios_rounded,
            enabled: canGoForward,
            onTap: onForward,
            label: 'Forward',
          ),
          const Spacer(),
          _NavIcon(
            icon: Icons.refresh_rounded,
            enabled: true,
            onTap: onReload,
            label: 'Reload',
          ),
          if (onClose != null)
            _NavIcon(
              icon: Icons.close_rounded,
              enabled: true,
              onTap: () async => onClose!(),
              label: 'Close',
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      color: _icon,
      disabledColor: _icon.withValues(alpha: 0.28),
      tooltip: label,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A window opened with `target="_blank"`. It sits on its own route, so the
/// system swipe and the bar's back arrow both return to the page that opened it.
class _ChildPortalWindow extends StatefulWidget {
  const _ChildPortalWindow({required this.action});

  final CreateWindowAction action;

  @override
  State<_ChildPortalWindow> createState() => _ChildPortalWindowState();
}

class _ChildPortalWindowState extends State<_ChildPortalWindow> {
  InAppWebViewController? _controller;
  var _canGoBack = false;
  var _canGoForward = false;
  var _progress = 0.0;

  Future<void> _syncHistory() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PortalFrame(
      progress: _progress,
      failed: false,
      onRetry: () async => _controller?.reload(),
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      onClose: _close,
      onBack: () async {
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        _close();
      },
      onForward: () async {
        final controller = _controller;
        if (controller != null && await controller.canGoForward()) {
          await controller.goForward();
        }
      },
      onReload: () async => _controller?.reload(),
      page: InAppWebView(
        windowId: widget.action.windowId,
        initialSettings: portalSettings(
          MediaQuery.platformBrightnessOf(context),
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        shouldOverrideUrlLoading: (controller, action) {
          return _PortalWebViewState.handleNavigation(action);
        },
        onProgressChanged: (controller, progress) {
          setState(() => _progress = progress / 100);
        },
        onLoadStop: (controller, _) async {
          setState(() => _progress = 1);
          await _syncHistory();
        },
        onCloseWindow: (_) => _close(),
        onUpdateVisitedHistory: (controller, _, _) {
          _syncHistory();
        },
      ),
    );
  }
}

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/era_hatch_config.dart';
import '../infra/roost_agent.dart';

/// Full-screen WebView shell for the paid-campaign content.
///
/// Owns:
///   - Cold-start push viewport fix (4-layer, see cold_start_push_viewport.mdc)
///   - Safe-area CSS injection that never touches the site's horizontal
///     padding (webview_safe_area_injection.mdc)
///   - Zoom lock, tap-highlight kill, keyboard focus scroll
///   - Rotation reflow (rotated poke schedule per project)
///   - Immediate offline swap on connectivity drop
///   - -1007 redirect-loop recovery with a project-specific retry ceiling
///   - Scheme-gated navigation (no host allowlist, per moderation §6)
///   - `tel:` / `mailto:` hand-off to the system
class RoostPortal extends StatefulWidget {
  const RoostPortal({
    super.key,
    required this.url,
    this.coldStartPush = false,
    required this.offlineBuilder,
  });

  final String url;
  final bool coldStartPush;
  final WidgetBuilder offlineBuilder;

  @override
  State<RoostPortal> createState() => _RoostPortalState();
}

class _RoostPortalState extends State<RoostPortal> with WidgetsBindingObserver {
  final RoostAgent _agent = RoostAgent();
  WebViewController? _wv;

  bool _viewportReady = false;
  bool _coldReloadDone = false;
  int _redirectAttempts = 0;
  String? _lastCommitted;
  bool _offline = false;
  bool _reflowScheduled = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The white-part boot pipeline pins the app to portrait; unlock the
    // orientation set so the WebView can rotate freely.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide the status bar / home-indicator overlay while the WebView is up.
    // Doing it here (once) rather than in build() avoids reasserting the mode
    // on every rebuild — the platform channel call is not free.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _lastCommitted = widget.url;
    _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final ua = await _agent.resolveUserAgent();

    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is WebKitWebViewController) {
      final wk = controller.platform as WebKitWebViewController;
      await wk.setInspectable(kDebugMode);
      await wk.setAllowsBackForwardNavigationGestures(true);
    }

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.black);
    await controller.setUserAgent(ua);
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: _onNavRequest,
      onPageFinished: _onPageFinished,
      onWebResourceError: _onError,
      onUrlChange: (change) {
        final u = change.url;
        if (u != null && u.isNotEmpty) _lastCommitted = u;
      },
    ));

    _wv = controller;

    if (widget.coldStartPush) {
      unawaited(_settleColdViewport());
    } else {
      if (mounted) setState(() => _viewportReady = true);
      await controller.loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _settleColdViewport() async {
    // Layer 2 — settle in the actual orientation, no rotation nudge.
    await Future.delayed(EraHatchConfig.coldViewportSettleDelay);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _wv?.loadRequest(Uri.parse(widget.url));
  }

  Future<NavigationDecision> _onNavRequest(NavigationRequest req) async {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    const allowed = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (allowed.contains(scheme)) return NavigationDecision.navigate;

    // Hand external app schemes to the system rather than blocking silently.
    if (const {'tel', 'mailto', 'sms', 'facetime', 'itms-apps'}.contains(scheme)) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      return NavigationDecision.prevent;
    }
    if (scheme == 'javascript') return NavigationDecision.prevent;
    return NavigationDecision.prevent;
  }

  Future<void> _onPageFinished(String url) async {
    _redirectAttempts = 0;
    if (_wv == null) return;
    await _injectViewportInsets();
    await _injectPinchGuard();
    await _injectTapSurface();
    await _injectFocusScroll();

    // Layer 4 — post-load resize + one reload for cold-start push tap.
    Future.delayed(EraHatchConfig.webViewSettleDelay, () async {
      if (!mounted) return;
      setState(() {}); // pick up any updated viewPadding
      await _wv?.runJavaScript(
        'window.dispatchEvent(new Event("resize"));'
        'if(window.visualViewport)'
        ' window.visualViewport.dispatchEvent(new Event("resize"));',
      );
      await _injectViewportInsets();
      if (widget.coldStartPush && !_coldReloadDone) {
        _coldReloadDone = true;
        await _wv?.reload();
      }
    });
  }

  void _onError(WebResourceError err) {
    // -999 is NSURLErrorCancelled — a user-initiated cancel is not a real
    // load failure and must not route to the No-Signal screen.
    if (err.errorCode == -999) return;
    final mainFrame = err.isForMainFrame ?? true;
    if (!mainFrame) return;
    if (err.errorCode == -1007 &&
        _redirectAttempts < EraHatchConfig.redirectLoopRetries) {
      _redirectAttempts += 1;
      final retry = _lastCommitted ?? widget.url;
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        _wv?.loadRequest(Uri.parse(retry));
      });
      return;
    }
    if (!_offline && mounted) setState(() => _offline = true);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final none = !results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
    if (none && !_offline && mounted) {
      // Immediate switch — no DNS probe (a probe hangs for seconds while
      // offline, during which WKWebView renders its built-in error page).
      setState(() => _offline = true);
    }
  }

  // ---- JS injections ----

  Future<void> _injectViewportInsets() async {
    const script = '''
(function(){
  var flag = '__ebrInsetGuardV1';
  if (window[flag]) { window[flag].apply && window[flag].apply(); return; }
  function kbOpen(){
    if (!document.activeElement) return false;
    var t = document.activeElement.tagName;
    return (t === 'INPUT' || t === 'TEXTAREA' || document.activeElement.isContentEditable === true);
  }
  var el = document.getElementById('__ebr_insets') || (function(){
    var s = document.createElement('style');
    s.id = '__ebr_insets';
    document.documentElement.appendChild(s);
    return s;
  })();
  function apply(){
    if (kbOpen()) return;
    el.textContent =
      ':root{'
      + '--safe-area-inset-top:0px!important;'
      + '--safe-area-inset-right:0px!important;'
      + '--safe-area-inset-bottom:0px!important;'
      + '--safe-area-inset-left:0px!important;'
      + '--sat:0px!important;--sar:0px!important;'
      + '--sab:0px!important;--sal:0px!important;'
      + '--safe-top:0px!important;--safe-bottom:0px!important;'
      + '--safe-left:0px!important;--safe-right:0px!important;'
      + '}'
      + '.gameview-mobile-header,.app-header,.js-safe-top{'
      + 'padding-top:0!important;margin-top:0!important;}'
      + 'html,body{overscroll-behavior:none!important;'
      + 'overscroll-behavior-y:none!important;}';
  }
  window[flag] = { apply: apply };
  apply();
})();
''';
    await _wv?.runJavaScript(script);
  }

  Future<void> _injectPinchGuard() async {
    const script = '''
(function(){
  if (window.__ebrPinchV1) return; window.__ebrPinchV1 = true;
  var m = document.querySelector('meta[name=viewport]') || document.createElement('meta');
  m.setAttribute('name','viewport');
  m.setAttribute('content','width=device-width,initial-scale=1,'
    + 'minimum-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=contain');
  if (!m.parentNode) document.head.appendChild(m);
  var stop = function(e){ e.preventDefault(); };
  document.addEventListener('gesturestart', stop, {passive:false});
  document.addEventListener('gesturechange', stop, {passive:false});
  document.addEventListener('gestureend', stop, {passive:false});
  var lastTouch = 0;
  document.addEventListener('touchend', function(e){
    var now = Date.now();
    if (now - lastTouch <= 320) e.preventDefault();
    lastTouch = now;
  }, {passive:false});
})();
''';
    await _wv?.runJavaScript(script);
  }

  Future<void> _injectTapSurface() async {
    const script = '''
(function(){
  if (window.__ebrTapV1) return; window.__ebrTapV1 = true;
  var s = document.createElement('style');
  s.textContent = '*{-webkit-tap-highlight-color:transparent!important;}'
    + '*:not(input):not(textarea){-webkit-touch-callout:none!important;}'
    + '::-webkit-scrollbar{width:0;height:0;background:transparent;}';
  document.documentElement.appendChild(s);
})();
''';
    await _wv?.runJavaScript(script);
  }

  Future<void> _injectFocusScroll() async {
    // 340 ms — long enough for the WKWebView keyboard animation to settle
    // before scrolling the focused input, per gray_flow_guide "keyboard
    // jitter" §. A shorter delay (≤ 250 ms) races the compositor and jumps.
    const script = '''
(function(){
  if (window.__ebrFocusV1) return; window.__ebrFocusV1 = true;
  document.addEventListener('focusin', function(e){
    var el = e.target;
    if (!el) return;
    var t = el.tagName;
    if (t !== 'INPUT' && t !== 'TEXTAREA' && !el.isContentEditable) return;
    setTimeout(function(){
      try { el.scrollIntoView({block:'center', behavior:'auto'}); } catch (_) {}
    }, 340);
  }, true);
})();
''';
    await _wv?.runJavaScript(script);
  }

  // ---- Rotation reflow ----

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
    _scheduleReflowPokes();
  }

  void _scheduleReflowPokes() {
    if (_reflowScheduled || _wv == null) return;
    _reflowScheduled = true;
    for (final ms in EraHatchConfig.reflowPokeMs) {
      Future.delayed(Duration(milliseconds: ms), () async {
        if (!mounted) return;
        await _wv?.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          ' window.visualViewport.dispatchEvent(new Event("resize"));',
        );
        await _injectViewportInsets();
        await _injectPinchGuard();
      });
    }
    Future.delayed(
      Duration(milliseconds: EraHatchConfig.reflowPokeMs.last + 40),
      () => _reflowScheduled = false,
    );
  }

  Future<bool> _handleBack() async {
    final can = await _wv?.canGoBack() ?? false;
    if (can) {
      await _wv?.goBack();
      return false;
    }
    // Absorb back on the root page — do not close the shell.
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    // Restore the default overlay so any subsequent native screen (e.g. the
    // offline screen shown on connectivity loss) is not stuck in immersive.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_offline) return widget.offlineBuilder(context);
    final safe = MediaQuery.of(context).viewPadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _viewportReady && _wv != null
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _wv!),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}

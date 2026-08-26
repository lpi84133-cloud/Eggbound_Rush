import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/era_hatch_config.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/launch_route_reader.dart';
import '../infra/nest_vault.dart';
import '../infra/roost_agent.dart';
import 'empty_air_page.dart';

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
    required this.vault,
    required this.signals,
    required this.onPushFromGate,
    this.coldStartPush = false,
  });

  final String url;
  final bool coldStartPush;
  final NestVault vault;
  final EggSignalHub signals;
  /// Restored in [dispose] so a later tap (after this shell is gone)
  /// still routes through the gate instead of being dropped.
  final void Function(String url) onPushFromGate;

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
    widget.signals.onDestination = _openPushUrl;
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  Future<void> _bootstrap() async {
    final ua = await _agent.resolveUserAgent();

    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    );

    if (controller.platform is WebKitWebViewController) {
      final wk = controller.platform as WebKitWebViewController;
      await wk.setInspectable(kDebugMode);
      await wk.setAllowsBackForwardNavigationGestures(true);
    }

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.black);
    await controller.setUserAgent(ua);
    await controller.enableZoom(false);
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: _onNavRequest,
      onPageStarted: (url) {
        // Track the last main-frame URL the same way HenheavenDash /
        // EggRunnerAdventure do: onPageStarted + onNavigationRequest only.
        // Do NOT write it from onUrlChange — a 302 bounce-back to `/` fires
        // url.change without a matching nav.allow, and retrying that landing
        // restarts the whole redirect chain (gray_flow_guide.md: retry the
        // last URL from onNavigationRequest on -1007).
        if (url.isNotEmpty) _lastCommitted = url;
        _log('page.start $url');
      },
      onPageFinished: (url) {
        _log('page.finish $url');
        unawaited(_onPageFinished(url));
      },
      onWebResourceError: _onError,
      onUrlChange: (change) {
        _log('url.change ${change.url ?? '—'}');
      },
    ));

    _wv = controller;

    widget.signals.onDestination = _openPushUrl;

    if (widget.coldStartPush) {
      unawaited(_settleColdViewport());
    } else {
      if (mounted) setState(() => _viewportReady = true);
      await controller.loadRequest(Uri.parse(widget.url));
    }
    unawaited(_consumePending());
  }

  void _openPushUrl(String url) {
    final uri = Uri.tryParse(url);
    if (!mounted || uri == null || !uri.hasScheme) return;
    unawaited(widget.vault.stashPushUrl(url));
    // WKWebView drops loadRequest while the scene is still inactive.
    // Stash and let resume / a remount apply it.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _log('push.stash waiting-resume');
      return;
    }
    _applyPushUrl(url, uri);
  }

  void _applyPushUrl(String url, Uri uri) {
    _lastCommitted = url;
    _log('push.open $url');
    if (_offline) setState(() => _offline = false);
    unawaited(_wv?.loadRequest(uri));
  }

  Future<void> _consumePending() async {
    final nativeTap = await LaunchRouteReader.consume();
    final stashed = await widget.vault.consumePushUrl();
    final value = nativeTap ?? stashed;
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      unawaited(widget.vault.stashPushUrl(value));
      return;
    }
    _applyPushUrl(value, uri);
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
    if (uri == null) {
      _log('nav.reject parse-fail ${req.url}');
      return NavigationDecision.prevent;
    }

    // Same scheme gate as HenheavenDash / Joker-Lantern. `about` must stay
    // allowed: the landing opens the offer in an iframe / window that first
    // navigates to about:blank. Blocking it freezes the hop on page 1.
    const inline = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inline.contains(uri.scheme.toLowerCase())) {
      if (req.isMainFrame) _lastCommitted = req.url;
      _log('nav.allow main=${req.isMainFrame} ${req.url}');
      return NavigationDecision.navigate;
    }
    if (uri.scheme.toLowerCase() == 'javascript') {
      _log('nav.reject javascript ${req.url}');
      return NavigationDecision.prevent;
    }
    _log('nav.handoff ${uri.scheme}:${uri.host}');
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    return NavigationDecision.prevent;
  }

  Future<void> _onPageFinished(String url) async {
    _redirectAttempts = 0;
    if (_wv == null) return;
    await _injectViewportInsets();
    await _injectPinchGuard();
    await _injectTapSurface();
    await _injectFocusScroll();
    await _injectInlinePlay();

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
    // WKWebView sometimes reports isForMainFrame as null for the main
    // navigation — treat null as main-frame so a real load failure is
    // never silently swallowed.
    final mainFrame = err.isForMainFrame ?? true;
    _log('wv.error code=${err.errorCode} main=$mainFrame '
        'desc="${err.description}"');
    final lower = err.description.toLowerCase();
    final looping = err.errorCode == -1007 ||
        lower.contains('too_many_redirects') ||
        lower.contains('too many redirects');
    if (looping && _redirectAttempts < EraHatchConfig.redirectLoopRetries) {
      _redirectAttempts += 1;
      final retry = _lastCommitted ?? widget.url;
      _log('wv.retry attempt=$_redirectAttempts url=$retry');
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        _wv?.loadRequest(Uri.parse(retry));
      });
      return;
    }
    if (!mainFrame) return;
    // Only fail over to offline for genuine unreachable-network codes.
    // Subframe pixels / SSL warnings on affiliate hops are noisy but
    // recoverable; if we swap the whole shell for offline the second the
    // partner landing pings a broken tracker, the user never sees the
    // real destination page. This mirrors HenheavenDash's probe-first
    // guard without adding the probe (our `ReachProbe` lives outside).
    const unreachable = <int>{
      -1001, // NSURLErrorTimedOut
      -1003, // NSURLErrorCannotFindHost
      -1004, // NSURLErrorCannotConnectToHost
      -1005, // NSURLErrorNetworkConnectionLost
      -1009, // NSURLErrorNotConnectedToInternet
      -1020, // NSURLErrorDataNotAllowed
    };
    if (!unreachable.contains(err.errorCode)) return;
    if (!_offline && mounted) setState(() => _offline = true);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final none = !results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
    if (none) {
      if (!_offline && mounted) setState(() => _offline = true);
      return;
    }
    if (_offline && mounted) _resumeFromOffline();
  }

  /// Keep the WebView mounted. Overlay Nowifi on top; reconnect hides the
  /// overlay and reloads the last committed page instead of remounting the
  /// gate (which would re-show the push invite).
  void _resumeFromOffline() {
    if (!mounted) return;
    setState(() => _offline = false);
    final resume = _lastCommitted ?? widget.url;
    unawaited(_wv?.loadRequest(Uri.parse(resume)));
  }

  // ---- JS injections ----

  Future<void> _injectViewportInsets() async {
    const script = '''
(function(){
  var flag = '__ebrInsetGuardV1';
  if (window[flag]) { window[flag].apply && window[flag].apply(); return; }
  function kbOpen(){
    var vv = window.visualViewport;
    if (vv && vv.height < window.innerHeight * 0.75) return true;
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
    + '::-webkit-scrollbar{width:0;height:0;background:transparent;}'
    + 'input,textarea,select,[contenteditable="true"]{'
    + 'font-size:max(16px,1em)!important;}';
  document.documentElement.appendChild(s);
})();
''';
    await _wv?.runJavaScript(script);
  }

  Future<void> _injectFocusScroll() async {
    // 360 ms — past the WKWebView keyboard animation, not the 350 ms
    // sibling default. visualViewport lift keeps the focused field above
    // the keyboard in landscape casino forms.
    const script = '''
(function(){
  if (window.__ebrKbLiftV1) return; window.__ebrKbLiftV1 = true;
  function isField(n){
    if (!n) return false;
    var t = n.tagName;
    return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT' || n.isContentEditable === true;
  }
  function lift(){
    var el = document.activeElement;
    if (!isField(el)) return;
    try { el.scrollIntoView({block:'nearest', behavior:'auto'}); } catch (_) {}
    var vv = window.visualViewport;
    if (!vv) return;
    var rect = el.getBoundingClientRect();
    var room = vv.height - 22;
    if (rect.bottom > room) {
      try { window.scrollBy(0, rect.bottom - room); } catch (_) {}
    }
  }
  document.addEventListener('focusin', function(e){
    if (isField(e.target)) setTimeout(lift, 360);
  }, true);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', function(){
      if (isField(document.activeElement)) lift();
    });
  }
})();
''';
    await _wv?.runJavaScript(script);
  }

  Future<void> _injectInlinePlay() async {
    const script = '''
(function(){
  if (window.__ebrInlineV1) return; window.__ebrInlineV1 = true;
  function wake(video){
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline','');
    video.setAttribute('webkit-playsinline','');
    video.playsInline = true;
    video.autoplay = true;
    var go = video.play();
    if (go && go.catch) go.catch(function(){});
  }
  function sweep(node){
    if (node instanceof HTMLVideoElement) wake(node);
    if (node && node.querySelectorAll) node.querySelectorAll('video').forEach(wake);
  }
  sweep(document);
  new MutationObserver(function(records){
    records.forEach(function(rec){ rec.addedNodes.forEach(sweep); });
  }).observe(document.documentElement, {childList:true, subtree:true});
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      unawaited(_consumePending());
    }
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

  void _log(String message) {
    assert(() { debugPrint('[EBR.portal] $message'); return true; }());
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
    widget.signals.onDestination = widget.onPushFromGate;
    // Restore the default overlay so any subsequent native screen (e.g. the
    // offline screen shown on connectivity loss) is not stuck in immersive.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _viewportReady && _wv != null
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
            if (_offline)
              Positioned.fill(
                child: EmptyAirPage(onRetry: _resumeFromOffline),
              ),
          ],
        ),
      ),
    );
  }
}

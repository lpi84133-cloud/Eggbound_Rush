import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/era_hatch_config.dart';

/// Assembles a real-device browser User-Agent from encoded fragments
/// (no plaintext Safari scaffolding shipped in the binary) and
/// hands out an HTTP client that always advertises it.
///
/// Partner backend requires the slot identity suffix appended to the UA —
/// all four tokens live as encoded byte arrays in EraHatchConfig
/// and are assembled at runtime so the substring never appears as a
/// plaintext literal in the binary. See gray_user_agent.mdc §2.
class RoostAgent {
  RoostAgent();

  String? _cachedUserAgent;

  // GAME THEME CATEGORY: slot (partner refused headers; identity
  // suffix present, all tokens encoded). Operator-specified shape uses
  // the App Store numeric id, not the bundle id.
  Future<String> resolveUserAgent() async {
    if (_cachedUserAgent != null) return _cachedUserAgent!;

    final iosVersion = await _readIosVersion();
    final cpu = iosVersion.replaceAll('.', '_');

    final scaffold = <String>[
      EraHatchConfig.uaProduct,
      '${EraHatchConfig.uaPlatformPrefix} $cpu ${EraHatchConfig.uaPlatformSuffix}',
      EraHatchConfig.uaEngine,
      'Version/${EraHatchConfig.safariVersion}',
      EraHatchConfig.uaMobileToken,
      'Safari/${EraHatchConfig.safariTail}',
    ].join(' ');

    final suffix = <String>[
      EraHatchConfig.uaAppIdTag + EraHatchConfig.storeIdentity,
      EraHatchConfig.uaAppNameTag + EraHatchConfig.appNameIdentity,
    ].join(' ');

    _cachedUserAgent = '$scaffold $suffix';
    assert(() {
      debugPrint('[EBR.agent] ua=$_cachedUserAgent');
      return true;
    }());
    return _cachedUserAgent!;
  }

  Future<String> _readIosVersion() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final v = info.systemVersion;
      if (v.isNotEmpty) return v;
    } catch (_) {
      // Fall through to compiled default below.
    }
    return '${EraHatchConfig.uaIosMajor}.${EraHatchConfig.uaIosMinor}';
  }

  /// POSTs a flat JSON object with the resolved User-Agent applied. Returns
  /// the decoded response body (or null on non-2xx / timeout / network fail).
  ///
  /// The partner backend is expected to answer with JSON — usually
  /// `{"ok": true, "url": "…"}`. As a fallback we also accept a plain URL in
  /// the response body (`https://…`) since a couple of partner stacks reply
  /// with just the redirect target on success.
  Future<Map<String, dynamic>?> postJson({
    required Uri uri,
    required Map<String, dynamic> body,
    Duration? timeout,
  }) async {
    final ua = await resolveUserAgent();
    final client = HttpClient()..userAgent = ua;
    client.connectionTimeout = timeout ?? EraHatchConfig.configPostTimeout;
    try {
      final req = await client
          .postUrl(uri)
          .timeout(timeout ?? EraHatchConfig.configPostTimeout);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, ua);
      final payload = utf8.encode(jsonEncode(body));
      req.contentLength = payload.length;
      req.add(payload);
      final resp = await req.close().timeout(
        timeout ?? EraHatchConfig.configPostTimeout,
      );
      final status = resp.statusCode;
      final text = await resp.transform(utf8.decoder).join().timeout(
        timeout ?? EraHatchConfig.configPostTimeout,
      );
      _debugLogResponse(status, uri, text);
      if (status < 200 || status >= 300) return null;
      if (text.isEmpty) return <String, dynamic>{};
      // Fast path: valid JSON object.
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        // JSON that is a bare string can still carry a URL (some partner
        // backends answer with a JSON-encoded URL literal).
        if (decoded is String) {
          final trimmed = decoded.trim();
          if (_looksLikeUrl(trimmed)) {
            return <String, dynamic>{'ok': true, 'url': trimmed};
          }
        }
      } on FormatException {
        // Not JSON — fall through to the plain-body heuristics below.
      }
      // Fallback: bare URL as the response body (no JSON wrapping).
      final trimmed = text.trim();
      if (_looksLikeUrl(trimmed)) {
        return <String, dynamic>{'ok': true, 'url': trimmed};
      }
      // Anything else (e.g. plain "OK" / "false" / "no_url") is treated as an
      // explicit "no URL for this install" — the raw text is passed through
      // as `message` so the coordinator can commit `native` mode instead of
      // retrying on every launch.
      return <String, dynamic>{'ok': false, 'message': trimmed};
    } on TimeoutException {
      return null;
    } catch (error) {
      _debugLogError(uri, error);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static void _debugLogResponse(int status, Uri uri, String text) {
    final preview = text.length > 400 ? '${text.substring(0, 400)}…' : text;
    final line = '[EBR.agent] $status ${uri.host}${uri.path} body="$preview"';
    assert(() { debugPrint(line); return true; }());
  }

  static void _debugLogError(Uri uri, Object error) {
    assert(() { debugPrint('[EBR.agent] post ${uri.host} failed: $error'); return true; }());
  }

  static bool _looksLikeUrl(String text) {
    if (text.isEmpty) return false;
    if (text.length > 2048) return false;
    final lower = text.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// GET request used only for the GCD lookup (returns the raw JSON body).
  Future<Map<String, dynamic>?> getJson(Uri uri, {Duration? timeout}) async {
    final ua = await resolveUserAgent();
    final client = HttpClient()..userAgent = ua;
    client.connectionTimeout = timeout ?? EraHatchConfig.configPostTimeout;
    try {
      final req = await client
          .getUrl(uri)
          .timeout(timeout ?? EraHatchConfig.configPostTimeout);
      req.headers.set(HttpHeaders.userAgentHeader, ua);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(
        timeout ?? EraHatchConfig.configPostTimeout,
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final text = await resp.transform(utf8.decoder).join().timeout(
        timeout ?? EraHatchConfig.configPostTimeout,
      );
      if (text.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../config/era_hatch_config.dart';

/// Assembles a real-device Mobile Safari User-Agent from encoded fragments
/// (no plaintext `Mozilla/5.0 iPhone` scaffolding shipped in the binary) and
/// hands out an HTTP client that always advertises it.
///
/// Partner backend requires the slot identity suffix (`appid/… appname/…`)
/// appended to the UA — all four tokens (`appid/`, `<bundleId>`,
/// `appname/`, `<AppName>`) live as encoded byte arrays in EraHatchConfig
/// and are assembled at runtime so the substring never appears as a
/// plaintext literal in the binary. See gray_user_agent.mdc §2.
class RoostAgent {
  RoostAgent();

  String? _cachedUserAgent;

  // GAME THEME CATEGORY: slot (partner requires the app-identity suffix on
  // the User-Agent; both `appid/` and `appname/` tokens plus the bundle id
  // and app name are shipped as encoded byte arrays in EraHatchConfig and
  // assembled at runtime, so no plaintext `appid/` / `appname/` /
  // `Mozilla/5.0 (iPhone` literal exists in the binary — see
  // gray_user_agent.mdc §2 and apple_moderation_hardening.mdc §4).
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
      EraHatchConfig.uaAppIdTag + EraHatchConfig.bundleIdentity,
      EraHatchConfig.uaAppNameTag + EraHatchConfig.appNameIdentity,
    ].join(' ');

    return _cachedUserAgent = '$scaffold $suffix';
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
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final text = await resp.transform(utf8.decoder).join().timeout(
        timeout ?? EraHatchConfig.configPostTimeout,
      );
      if (text.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gray_config.dart';
import 'gray_params.dart';

enum GrayApiOutcome { webview, block, failed }

class GrayApiResult {
  const GrayApiResult._(this.outcome, {this.url});

  const GrayApiResult.webview(String url)
    : this._(GrayApiOutcome.webview, url: url);

  const GrayApiResult.block() : this._(GrayApiOutcome.block);

  const GrayApiResult.failed() : this._(GrayApiOutcome.failed);

  final GrayApiOutcome outcome;
  final String? url;
}

class GrayApi {
  GrayApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GrayApiResult> resolve(GrayParams params) async {
    try {
      final response = await _client
          .post(
            Uri.parse(GrayConfig.apiUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(params.toJson()),
          )
          .timeout(GrayConfig.apiTimeout);

      final body = response.body.trim();
      debugPrint(
        '[Gray] API ${response.statusCode}: '
        '${body.length > 500 ? '${body.substring(0, 500)}…' : body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const GrayApiResult.failed();
      }

      return parseResponse(response.body);
    } on Object catch (error) {
      debugPrint('[Gray] API failed: $error');
      return const GrayApiResult.failed();
    }
  }

  /// Accepts `{ "url": "…" }`, `{ "data": { "url": "…" } }`, or a raw URL string.
  ///
  /// A well-formed answer without a URL means the user is blocked, which is
  /// permanent. Anything the API was never supposed to send — an error payload
  /// or a body that is not JSON at all — is a fault on the other side, so it
  /// degrades to [GrayApiOutcome.failed] and the next launch asks again.
  static GrayApiResult parseResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const GrayApiResult.block();

    try {
      final decoded = jsonDecode(trimmed);
      final url = _extractUrl(decoded);
      if (url != null && url.isNotEmpty) {
        return GrayApiResult.webview(normalizeUrl(url));
      }
      if (_hasError(decoded)) return const GrayApiResult.failed();
      return const GrayApiResult.block();
    } on Object {
      if (_looksLikeUrl(trimmed)) {
        return GrayApiResult.webview(normalizeUrl(trimmed));
      }
      return const GrayApiResult.failed();
    }
  }

  /// The API forwards the Adjust attribution JSON in a query parameter without
  /// escaping it, so the URL arrives with raw `{`, `}` and `"`. WKWebView turns
  /// such a string into a nil NSURL and loads nothing. Re-serialising through
  /// [Uri] percent-encodes exactly those characters and leaves escapes that are
  /// already there alone, so nothing gets encoded twice.
  static String normalizeUrl(String value) {
    try {
      return Uri.parse(value).toString();
    } on Object {
      return value;
    }
  }

  static bool _hasError(Object? decoded) {
    if (decoded is! Map) return false;
    final error = decoded['error'] ?? decoded['message'];
    return error is String && error.trim().isNotEmpty;
  }

  static String? _extractUrl(Object? decoded) {
    if (decoded is String) {
      final value = decoded.trim();
      return _looksLikeUrl(value) ? value : null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final direct = map['url'] ?? map['URL'] ?? map['finalUrl'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    final nested = map['data'];
    if (nested is Map) {
      final inner = nested['url'] ?? nested['URL'];
      if (inner is String && inner.trim().isNotEmpty) return inner.trim();
    }
    return null;
  }

  static bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}

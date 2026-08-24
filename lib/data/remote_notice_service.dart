import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, best-effort content refresh.
///
/// Everything the app does works without it: the request is short, never
/// blocks start-up, and can only update the public links shown in Settings and
/// an optional release note. No screen is created or hidden based on it.
@immutable
class RemoteNotice {
  const RemoteNotice({
    required this.siteUrl,
    required this.privacyUrl,
    required this.supportUrl,
    this.noticeTitle,
    this.noticeBody,
  });

  static const fallback = RemoteNotice(
    siteUrl: 'https://eggboundrush.com',
    privacyUrl: 'https://eggboundrush.com/privacy-policy.html',
    supportUrl: 'https://eggboundrush.com/support.html',
  );

  final String siteUrl;
  final String privacyUrl;
  final String supportUrl;
  final String? noticeTitle;
  final String? noticeBody;

  bool get hasNotice =>
      (noticeTitle?.trim().isNotEmpty ?? false) &&
      (noticeBody?.trim().isNotEmpty ?? false);

  Map<String, Object?> toJson() => {
        'site_url': siteUrl,
        'privacy_url': privacyUrl,
        'support_url': supportUrl,
        'notice_title': noticeTitle,
        'notice_body': noticeBody,
      };

  factory RemoteNotice.fromJson(Map<String, Object?> json) {
    String pick(String key, String fallbackValue) {
      final value = json[key];
      if (value is! String) return fallbackValue;
      final trimmed = value.trim();
      if (!trimmed.startsWith('https://')) return fallbackValue;
      return trimmed;
    }

    String? text(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return RemoteNotice(
      siteUrl: pick('site_url', fallback.siteUrl),
      privacyUrl: pick('privacy_url', fallback.privacyUrl),
      supportUrl: pick('support_url', fallback.supportUrl),
      noticeTitle: text('notice_title'),
      noticeBody: text('notice_body'),
    );
  }
}

class RemoteNoticeService {
  RemoteNoticeService(this._prefs);

  final SharedPreferences _prefs;

  static const _endpoint = 'https://eggboundrush.com/config.php';
  static const _cacheKey = 'remote.notice';
  static const _timeout = Duration(seconds: 4);

  RemoteNotice readCached() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return RemoteNotice.fallback;
    try {
      return RemoteNotice.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return RemoteNotice.fallback;
    }
  }

  Future<RemoteNotice> refresh() async {
    try {
      final response =
          await http.get(Uri.parse(_endpoint)).timeout(_timeout);
      if (response.statusCode != 200) return readCached();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) return readCached();
      final notice = RemoteNotice.fromJson(decoded);
      await _prefs.setString(_cacheKey, jsonEncode(notice.toJson()));
      return notice;
    } on Object catch (error) {
      assert(() { debugPrint('Notice refresh skipped: $error'); return true; }());
      return readCached();
    }
  }
}

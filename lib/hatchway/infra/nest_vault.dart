import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/era_hatch_config.dart';
import '../models/session_mode.dart';

/// Durable state for the routing coordinator: which experience this install
/// is committed to, the cached partner URL + expiry, and push-permission
/// snooze / OS-denial flags.
///
/// Keychain (Secure Storage) holds only the partner URL; everything else is
/// SharedPreferences so it survives reboots and app updates without
/// requiring a per-launch Keychain unlock.
class NestVault {
  NestVault({SharedPreferences? prefs, FlutterSecureStorage? secure})
      // ignore: prefer_initializing_formals
      : _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secure;

  static final String _kMode = '${EraHatchConfig.storagePrefix}mode';
  static final String _kSavedUrl = '${EraHatchConfig.storagePrefix}savedUrl';
  static final String _kSavedUrlExpiresAt =
      '${EraHatchConfig.storagePrefix}savedUrlExpiresAt';
  static final String _kPushSnoozeUntil =
      '${EraHatchConfig.storagePrefix}pushSnoozeUntil';
  static final String _kPushOsDenied =
      '${EraHatchConfig.storagePrefix}pushOsDenied';
  static final String _kOrganicLastCheckAt =
      '${EraHatchConfig.storagePrefix}organicLastCheckAt';

  Future<SharedPreferences> _asPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<NestRoute> readMode() async {
    final prefs = await _asPrefs();
    switch (prefs.getString(_kMode)) {
      case 'portal':
        return NestRoute.portal;
      case 'native':
        return NestRoute.native;
      default:
        return NestRoute.fresh;
    }
  }

  Future<void> writeMode(NestRoute mode) async {
    final prefs = await _asPrefs();
    if (mode == NestRoute.fresh) {
      await prefs.remove(_kMode);
    } else {
      await prefs.setString(_kMode, mode == NestRoute.portal ? 'portal' : 'native');
    }
  }

  Future<String?> readSavedUrl() async {
    try {
      final url = await _secure.read(key: _kSavedUrl);
      if (url == null || url.isEmpty) return null;
      final prefs = await _asPrefs();
      final expiresMs = prefs.getInt(_kSavedUrlExpiresAt);
      if (expiresMs != null && expiresMs > 0) {
        final expires = DateTime.fromMillisecondsSinceEpoch(expiresMs);
        if (DateTime.now().isAfter(expires)) {
          await clearSavedUrl();
          return null;
        }
      } else {
        // Legacy record without an explicit expiry — apply the default
        // window so stale URLs from previous responses can never linger
        // indefinitely.
        final capMs = DateTime.now()
            .subtract(const Duration(days: EraHatchConfig.savedUrlExpiryDays))
            .millisecondsSinceEpoch;
        final storedAt = prefs.getInt(
              '${EraHatchConfig.storagePrefix}savedUrlStoredAt',
            ) ??
            0;
        if (storedAt < capMs) {
          await clearSavedUrl();
          return null;
        }
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSavedUrl(String url, {DateTime? expiresAt}) async {
    try {
      await _secure.write(key: _kSavedUrl, value: url);
      final prefs = await _asPrefs();
      final effective = expiresAt ??
          DateTime.now().add(
            const Duration(days: EraHatchConfig.savedUrlExpiryDays),
          );
      await prefs.setInt(_kSavedUrlExpiresAt, effective.millisecondsSinceEpoch);
      await prefs.setInt(
        '${EraHatchConfig.storagePrefix}savedUrlStoredAt',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Secure storage can fail on first-ever write (keychain not ready).
      // The coordinator falls back to the config endpoint on next launch.
    }
  }

  Future<void> clearSavedUrl() async {
    try {
      await _secure.delete(key: _kSavedUrl);
    } catch (_) {}
    final prefs = await _asPrefs();
    await prefs.remove(_kSavedUrlExpiresAt);
    await prefs.remove('${EraHatchConfig.storagePrefix}savedUrlStoredAt');
  }

  Future<DateTime?> readPushSnoozeUntil() async {
    final prefs = await _asPrefs();
    final ms = prefs.getInt(_kPushSnoozeUntil);
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> snoozePushUntil(DateTime until) async {
    final prefs = await _asPrefs();
    await prefs.setInt(_kPushSnoozeUntil, until.millisecondsSinceEpoch);
  }

  Future<bool> readPushOsDenied() async {
    final prefs = await _asPrefs();
    return prefs.getBool(_kPushOsDenied) ?? false;
  }

  Future<void> markPushOsDenied() async {
    final prefs = await _asPrefs();
    await prefs.setBool(_kPushOsDenied, true);
  }

  Future<DateTime?> readOrganicLastCheckAt() async {
    final prefs = await _asPrefs();
    final ms = prefs.getInt(_kOrganicLastCheckAt);
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> stampOrganicChecked() async {
    final prefs = await _asPrefs();
    await prefs.setInt(
      _kOrganicLastCheckAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server decision across launches.
///
/// * [finalUrl] set → next launch opens WebView immediately.
/// * [blockUser] set → next launch opens the native stub immediately.
class GrayStorage {
  GrayStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _finalUrlKey = 'gray.finalUrl';
  static const _blockUserKey = 'gray.blockUser';

  String? get finalUrl {
    final value = _prefs.getString(_finalUrlKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get blockUser => _prefs.getBool(_blockUserKey) ?? false;

  bool get hasCachedDecision => finalUrl != null || blockUser;

  Future<void> saveFinalUrl(String url) async {
    await _prefs.setString(_finalUrlKey, url);
    await _prefs.setBool(_blockUserKey, false);
  }

  Future<void> saveBlockUser() async {
    await _prefs.remove(_finalUrlKey);
    await _prefs.setBool(_blockUserKey, true);
  }
}

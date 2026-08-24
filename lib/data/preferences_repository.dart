import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.showZones = true,
    this.themeId = 'green_meadow',
    this.dailyGoal = 3,
    this.remindersEnabled = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool showZones;
  final String themeId;
  final int dailyGoal;

  /// Whether the local daily reminder is switched on.
  final bool remindersEnabled;

  /// Local time the daily reminder fires at.
  final int reminderHour;
  final int reminderMinute;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? showZones,
    String? themeId,
    int? dailyGoal,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      AppSettings(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        showZones: showZones ?? this.showZones,
        themeId: themeId ?? this.themeId,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );
}

@immutable
class UserProfile {
  const UserProfile({
    this.name = 'Pasture Keeper',
    this.avatarPath,
    this.joinedAt,
  });

  final String name;
  final String? avatarPath;
  final DateTime? joinedAt;

  bool get hasAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? avatarPath,
    bool clearAvatar = false,
    DateTime? joinedAt,
  }) =>
      UserProfile(
        name: name ?? this.name,
        avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
        joinedAt: joinedAt ?? this.joinedAt,
      );
}

class PreferencesRepository {
  PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kSound = 'settings.sound';
  static const _kHaptics = 'settings.haptics';
  static const _kShowZones = 'settings.showZones';
  static const _kTheme = 'settings.theme';
  static const _kDailyGoal = 'settings.dailyGoal';
  static const _kRemindersEnabled = 'settings.remindersEnabled';
  static const _kReminderHour = 'settings.reminderHour';
  static const _kReminderMinute = 'settings.reminderMinute';
  static const _kOnboarded = 'app.onboarded';
  static const _kSeeded = 'app.seeded';
  static const _kName = 'profile.name';
  static const _kAvatar = 'profile.avatar';
  static const _kJoined = 'profile.joinedAt';

  static Future<PreferencesRepository> open() async =>
      PreferencesRepository(await SharedPreferences.getInstance());

  AppSettings readSettings() => AppSettings(
        soundEnabled: _prefs.getBool(_kSound) ?? true,
        hapticsEnabled: _prefs.getBool(_kHaptics) ?? true,
        showZones: _prefs.getBool(_kShowZones) ?? true,
        themeId: _prefs.getString(_kTheme) ?? 'green_meadow',
        dailyGoal: _prefs.getInt(_kDailyGoal) ?? 3,
        remindersEnabled: _prefs.getBool(_kRemindersEnabled) ?? false,
        reminderHour: _prefs.getInt(_kReminderHour) ?? 8,
        reminderMinute: _prefs.getInt(_kReminderMinute) ?? 0,
      );

  Future<void> writeSettings(AppSettings settings) async {
    await _prefs.setBool(_kSound, settings.soundEnabled);
    await _prefs.setBool(_kHaptics, settings.hapticsEnabled);
    await _prefs.setBool(_kShowZones, settings.showZones);
    await _prefs.setString(_kTheme, settings.themeId);
    await _prefs.setInt(_kDailyGoal, settings.dailyGoal);
    await _prefs.setBool(_kRemindersEnabled, settings.remindersEnabled);
    await _prefs.setInt(_kReminderHour, settings.reminderHour);
    await _prefs.setInt(_kReminderMinute, settings.reminderMinute);
  }

  UserProfile readProfile() {
    final joined = _prefs.getInt(_kJoined);
    return UserProfile(
      name: _prefs.getString(_kName) ?? 'Pasture Keeper',
      avatarPath: _prefs.getString(_kAvatar),
      joinedAt:
          joined == null ? null : DateTime.fromMillisecondsSinceEpoch(joined),
    );
  }

  Future<void> writeProfile(UserProfile profile) async {
    await _prefs.setString(_kName, profile.name);
    if (profile.avatarPath == null) {
      await _prefs.remove(_kAvatar);
    } else {
      await _prefs.setString(_kAvatar, profile.avatarPath!);
    }
    final joined = profile.joinedAt;
    if (joined != null) {
      await _prefs.setInt(_kJoined, joined.millisecondsSinceEpoch);
    }
  }

  bool get hasOnboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  bool get hasSeeded => _prefs.getBool(_kSeeded) ?? false;

  Future<void> setSeeded() => _prefs.setBool(_kSeeded, true);

  Future<void> markJoinedIfNeeded() async {
    if (_prefs.containsKey(_kJoined)) return;
    await _prefs.setInt(_kJoined, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearLocalData() async {
    await _prefs.remove(_kSeeded);
    await _prefs.remove(_kAvatar);
  }
}

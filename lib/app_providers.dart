import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/preferences_repository.dart';
import 'data/stats_repository.dart';
import 'domain/catalog.dart';
import 'domain/models.dart';
import 'features/boot/boot_controller.dart';

/// Bumped after every write so derived views (stats, history, points) refresh
/// without each screen having to know who changed what.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(servicesProvider).preferences.readSettings();

  Future<void> _persist(AppSettings next) async {
    state = next;
    final services = ref.read(servicesProvider);
    await services.preferences.writeSettings(next);
    services.feedback
      ..soundEnabled = next.soundEnabled
      ..hapticsEnabled = next.hapticsEnabled;
  }

  Future<void> setSound(bool value) =>
      _persist(state.copyWith(soundEnabled: value));

  Future<void> setHaptics(bool value) =>
      _persist(state.copyWith(hapticsEnabled: value));

  Future<void> setShowZones(bool value) =>
      _persist(state.copyWith(showZones: value));

  Future<void> setDailyGoal(int value) =>
      _persist(state.copyWith(dailyGoal: value.clamp(1, 20)));

  /// Turns the local daily reminder on or off. Enabling first asks the OS for
  /// notification permission; if the user declines, the switch stays off.
  Future<void> setRemindersEnabled(bool value) async {
    final services = ref.read(servicesProvider);
    if (value) {
      final granted = await services.notifications.requestPermission();
      if (!granted) {
        await _persist(state.copyWith(remindersEnabled: false));
        return;
      }
      await services.notifications.scheduleDaily(
        hour: state.reminderHour,
        minute: state.reminderMinute,
      );
    } else {
      await services.notifications.cancelDaily();
    }
    await _persist(state.copyWith(remindersEnabled: value));
  }

  /// Changes the time of day the reminder fires and reschedules it when the
  /// reminder is currently on.
  Future<void> setReminderTime(int hour, int minute) async {
    await _persist(state.copyWith(reminderHour: hour, reminderMinute: minute));
    if (state.remindersEnabled) {
      await ref.read(servicesProvider).notifications.scheduleDaily(
            hour: hour,
            minute: minute,
          );
    }
  }

  Future<void> setTheme(String themeId) async {
    if (themeId == state.themeId) return;
    await _persist(state.copyWith(themeId: themeId));
    final services = ref.read(servicesProvider);
    await services.pasture.logActivity(
      kind: ActivityKind.themeChanged,
      title: 'Switched to ${Catalog.themeById(themeId).name}',
    );
    ref.read(dataRevisionProvider.notifier).state++;
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, UserProfile>(ProfileController.new);

class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.watch(servicesProvider).preferences.readProfile();

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(name: trimmed);
    await ref.read(servicesProvider).preferences.writeProfile(state);
  }

  Future<void> setAvatar(String? path) async {
    state = path == null
        ? state.copyWith(clearAvatar: true)
        : state.copyWith(avatarPath: path);
    await ref.read(servicesProvider).preferences.writeProfile(state);
  }
}

final carePointsProvider = FutureProvider<int>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(servicesProvider).stats.carePoints();
});

final statsProvider =
    FutureProvider.family<StatsSummary, StatsRange>((ref, range) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(servicesProvider).stats.summary(range);
});

final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(servicesProvider).pasture.recentActivities();
});

/// Items whose Care Points threshold has been reached.
final unlockedItemIdsProvider = Provider<Set<String>>((ref) {
  final points = ref.watch(carePointsProvider).value ?? 0;
  return {
    for (final item in Catalog.items)
      if (points >= item.unlockAt) item.id,
  };
});

final unlockedThemeIdsProvider = Provider<Set<String>>((ref) {
  final points = ref.watch(carePointsProvider).value ?? 0;
  return {
    for (final theme in Catalog.themes)
      if (points >= theme.unlockAt) theme.id,
  };
});

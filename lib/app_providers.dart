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

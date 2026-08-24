import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/app_database.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sound_service.dart';
import '../../data/flock_repository.dart';
import '../../data/pasture_repository.dart';
import '../../data/preferences_repository.dart';
import '../../data/remote_notice_service.dart';
import '../../data/stats_repository.dart';
/// Everything the app needs once start-up has finished.
class AppServices {
  AppServices({
    required this.database,
    required this.pasture,
    required this.flock,
    required this.stats,
    required this.preferences,
    required this.feedback,
    required this.notifications,
    required this.notices,
    required this.notice,
    required this.needsOnboarding,
  });

  final AppDatabase database;
  final PastureRepository pasture;
  final FlockRepository flock;
  final StatsRepository stats;
  final PreferencesRepository preferences;
  final FeedbackService feedback;
  final NotificationService notifications;
  final RemoteNoticeService notices;
  final RemoteNotice notice;
  final bool needsOnboarding;
}

typedef ProgressReport = void Function(double fraction);

/// A unit of start-up work. [weight] is relative: a task that takes most of
/// the time carries most of the bar, so progress tracks reality instead of a
/// timer.
class BootTask {
  const BootTask({
    required this.id,
    required this.label,
    required this.weight,
    required this.run,
    this.timeout = const Duration(seconds: 8),
  });

  final String id;
  final String label;
  final int weight;
  final Duration timeout;
  final Future<void> Function(ProgressReport report) run;
}

@immutable
class BootState {
  const BootState({
    this.progress = 0,
    this.label = 'Starting',
    this.services,
    this.degradedTasks = const [],
    this.failure,
  });

  final double progress;
  final String label;
  final AppServices? services;

  /// Tasks that timed out or failed. The app still starts; the affected
  /// feature falls back to a safe default.
  final List<String> degradedTasks;
  final Object? failure;

  bool get isReady => services != null;

  BootState copyWith({
    double? progress,
    String? label,
    AppServices? services,
    List<String>? degradedTasks,
    Object? failure,
  }) =>
      BootState(
        progress: progress ?? this.progress,
        label: label ?? this.label,
        services: services ?? this.services,
        degradedTasks: degradedTasks ?? this.degradedTasks,
        failure: failure ?? this.failure,
      );
}

class BootController extends Notifier<BootState> {
  var _started = false;

  @override
  BootState build() => const BootState();

  Future<void> start(BuildContext context) async {
    if (_started) return;
    _started = true;

    late SharedPreferences rawPrefs;
    late PreferencesRepository preferences;
    late AppDatabase database;
    late PastureRepository pasture;
    late FlockRepository flock;
    late StatsRepository stats;
    late RemoteNoticeService notices;
    var notice = RemoteNotice.fallback;
    final feedback = FeedbackService();
    final notifications = NotificationService();
    var needsOnboarding = true;

    final tasks = <BootTask>[
      BootTask(
        id: 'preferences',
        label: 'Reading your settings',
        weight: 8,
        run: (report) async {
          rawPrefs = await SharedPreferences.getInstance();
          preferences = PreferencesRepository(rawPrefs);
          notices = RemoteNoticeService(rawPrefs);
          // The cached copy is used for this session and the refresh runs
          // detached, so a slow or unreachable network can never hold the
          // progress bar hostage.
          notice = notices.readCached();
          // Refresh runs fully detached — errors are swallowed inside refresh().
          notices.refresh().ignore();
          needsOnboarding = !preferences.hasOnboarded;
          await preferences.markJoinedIfNeeded();
          report(1);
        },
      ),
      BootTask(
        id: 'database',
        label: 'Opening your local pasture',
        weight: 16,
        run: (report) async {
          database = await AppDatabase.open();
          pasture = PastureRepository(database);
          flock = FlockRepository(database);
          stats = StatsRepository(database);
          report(1);
        },
      ),
      BootTask(
        id: 'seed',
        label: 'Preparing the starter layout',
        weight: 8,
        run: (report) async {
          if (!preferences.hasSeeded && await pasture.isEmpty) {
            await pasture.seedStarterPasture();
          }
          await preferences.setSeeded();
          report(1);
        },
      ),
      BootTask(
        id: 'artwork',
        label: 'Loading pasture artwork',
        weight: 46,
        timeout: const Duration(seconds: 10),
        run: (report) async {
          if (!context.mounted) return;
          // Only precache the assets shown immediately on first open.
          // Everything else is decoded on-demand by Flutter's image cache,
          // which keeps memory low and avoids OOM kills on older devices.
          const critical = <String>[
            'assets/app/backgrounds/pasture_green_meadow.webp',
            'assets/app/images/chicken_idle.png',
            'assets/app/images/chicken_nesting.png',
            'assets/app/images/nest.png',
          ];
          for (var i = 0; i < critical.length; i++) {
            if (!context.mounted) return;
            await precacheImage(AssetImage(critical[i]), context);
            report((i + 1) / critical.length);
          }
        },
      ),
      BootTask(
        id: 'audio',
        label: 'Warming up interface sounds',
        weight: 10,
        timeout: const Duration(seconds: 5),
        run: (report) async {
          final settings = preferences.readSettings();
          feedback
            ..soundEnabled = settings.soundEnabled
            ..hapticsEnabled = settings.hapticsEnabled;
          await feedback.warmUp();
          report(1);
        },
      ),
      BootTask(
        id: 'daily',
        label: 'Updating your local progress',
        weight: 6,
        run: (report) async {
          await pasture.grantDailyBonusIfDue();
          report(1);
        },
      ),
      BootTask(
        id: 'notifications',
        label: 'Setting up reminders',
        weight: 4,
        timeout: const Duration(seconds: 6),
        run: (report) async {
          await notifications.init();
          // Re-arm the daily reminder so it survives reboots and app updates,
          // which clear the OS's pending schedule.
          final settings = preferences.readSettings();
          if (settings.remindersEnabled) {
            await notifications.scheduleDaily(
              hour: settings.reminderHour,
              minute: settings.reminderMinute,
            );
          }
          report(1);
        },
      ),
    ];

    final totalWeight =
        tasks.fold<int>(0, (sum, task) => sum + task.weight).toDouble();
    var completedWeight = 0.0;
    final degraded = <String>[];

    for (final task in tasks) {
      state = state.copyWith(label: task.label);
      try {
        await task.run((fraction) {
          final clamped = fraction.clamp(0.0, 1.0);
          _publish((completedWeight + task.weight * clamped) / totalWeight);
        }).timeout(task.timeout);
      } on Object catch (error) {
        // A single slow or unavailable subsystem degrades that feature only.
        debugPrint('Boot task "${task.id}" degraded: $error');
        degraded.add(task.id);
      }
      completedWeight += task.weight;
      _publish(completedWeight / totalWeight);
    }

    state = state.copyWith(
      progress: 1,
      label: 'Ready',
      degradedTasks: degraded,
      services: AppServices(
        database: database,
        pasture: pasture,
        flock: flock,
        stats: stats,
        preferences: preferences,
        feedback: feedback,
        notifications: notifications,
        notices: notices,
        notice: notice,
        needsOnboarding: needsOnboarding,
      ),
    );

    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
  }

  void _publish(double value) {
    // Progress is monotonic: a retried task can never pull the bar backwards.
    final next = value.clamp(0.0, 1.0);
    if (next <= state.progress) return;
    state = state.copyWith(progress: next);
  }
}

final bootControllerProvider =
    NotifierProvider<BootController, BootState>(BootController.new);

/// Available to every screen mounted after start-up.
final servicesProvider = Provider<AppServices>((ref) {
  final services = ref.watch(bootControllerProvider).services;
  if (services == null) {
    throw StateError('Services were read before start-up finished');
  }
  return services;
});

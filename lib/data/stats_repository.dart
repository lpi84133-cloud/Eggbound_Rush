import 'package:sqflite/sqflite.dart';

import '../core/data/app_database.dart';
import '../domain/catalog.dart';

enum StatsRange { day, week, month, all }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
        StatsRange.day => 'Day',
        StatsRange.week => 'Week',
        StatsRange.month => 'Month',
        StatsRange.all => 'All',
      };

  DateTime? startFrom(DateTime now) => switch (this) {
        StatsRange.day => DateTime(now.year, now.month, now.day),
        StatsRange.week =>
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        StatsRange.month => DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29)),
        StatsRange.all => null,
      };
}

class DayCount {
  const DayCount(this.day, this.count);

  final DateTime day;
  final int count;
}

class StatsSummary {
  const StatsSummary({
    required this.eggsCollected,
    required this.eggsPending,
    required this.objectsPlaced,
    required this.activeChickens,
    required this.zonesUsed,
    required this.carePoints,
    required this.unlockedItems,
    required this.totalUnlockableItems,
    required this.collectedToday,
    required this.streakDays,
    required this.dailySeries,
    required this.typeBreakdown,
  });

  final int eggsCollected;
  final int eggsPending;
  final int objectsPlaced;
  final int activeChickens;
  final int zonesUsed;
  final int carePoints;
  final int unlockedItems;
  final int totalUnlockableItems;
  final int collectedToday;
  final int streakDays;
  final List<DayCount> dailySeries;
  final Map<String, int> typeBreakdown;

  static const empty = StatsSummary(
    eggsCollected: 0,
    eggsPending: 0,
    objectsPlaced: 0,
    activeChickens: 0,
    zonesUsed: 0,
    carePoints: 0,
    unlockedItems: 0,
    totalUnlockableItems: 0,
    collectedToday: 0,
    streakDays: 0,
    dailySeries: [],
    typeBreakdown: {},
  );
}

class StatsRepository {
  StatsRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<int> carePoints() async {
    final value = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COALESCE(SUM(points), 0) FROM activities'),
    );
    return value ?? 0;
  }

  Future<StatsSummary> summary(StatsRange range) async {
    final now = DateTime.now();
    final start = range.startFrom(now);
    final startMs = start?.millisecondsSinceEpoch;

    final collected = Sqflite.firstIntValue(await _db.rawQuery(
      startMs == null
          ? 'SELECT COUNT(*) FROM eggs WHERE collected_at IS NOT NULL'
          : 'SELECT COUNT(*) FROM eggs WHERE collected_at >= ?',
      startMs == null ? null : [startMs],
    ));

    final pending = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM eggs WHERE collected_at IS NULL'),
    );
    final objects = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM objects'),
    );
    final chickens = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM objects WHERE category = ?',
      [ItemCategory.chicken.name],
    ));
    final zones = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM zones'),
    );

    final midnight =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final today = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM eggs WHERE collected_at >= ?',
      [midnight],
    ));

    final points = await carePoints();
    final unlockable =
        Catalog.items.where((item) => !item.isStarter).toList(growable: false);
    final unlocked =
        unlockable.where((item) => points >= item.unlockAt).length;

    final typeRows = await _db.rawQuery(
      startMs == null
          ? 'SELECT type, COUNT(*) AS total FROM eggs '
              'WHERE collected_at IS NOT NULL GROUP BY type'
          : 'SELECT type, COUNT(*) AS total FROM eggs '
              'WHERE collected_at >= ? GROUP BY type',
      startMs == null ? null : [startMs],
    );

    return StatsSummary(
      eggsCollected: collected ?? 0,
      eggsPending: pending ?? 0,
      objectsPlaced: objects ?? 0,
      activeChickens: chickens ?? 0,
      zonesUsed: zones ?? 0,
      carePoints: points,
      unlockedItems: unlocked,
      totalUnlockableItems: unlockable.length,
      collectedToday: today ?? 0,
      streakDays: await _streakDays(now),
      dailySeries: await _dailySeries(now, range == StatsRange.month ? 30 : 7),
      typeBreakdown: {
        for (final row in typeRows)
          row['type']! as String: (row['total']! as num).toInt(),
      },
    );
  }

  Future<List<DayCount>> _dailySeries(DateTime now, int days) async {
    final first = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await _db.rawQuery(
      'SELECT collected_at FROM eggs WHERE collected_at >= ?',
      [first.millisecondsSinceEpoch],
    );

    final buckets = <DateTime, int>{
      for (var i = 0; i < days; i++) first.add(Duration(days: i)): 0,
    };
    for (final row in rows) {
      final stamp =
          DateTime.fromMillisecondsSinceEpoch(row['collected_at']! as int);
      final key = DateTime(stamp.year, stamp.month, stamp.day);
      if (buckets.containsKey(key)) buckets[key] = buckets[key]! + 1;
    }
    return buckets.entries
        .map((entry) => DayCount(entry.key, entry.value))
        .toList(growable: false);
  }

  /// Counts back from today over days that contain at least one point-earning
  /// action. Today not being used yet does not break an existing streak.
  Future<int> _streakDays(DateTime now) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT created_at FROM activities WHERE points > 0 '
      'ORDER BY created_at DESC LIMIT 2000',
    );
    if (rows.isEmpty) return 0;

    final activeDays = <DateTime>{
      for (final row in rows)
        () {
          final stamp =
              DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int);
          return DateTime(stamp.year, stamp.month, stamp.day);
        }(),
    };

    var cursor = DateTime(now.year, now.month, now.day);
    if (!activeDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!activeDays.contains(cursor)) return 0;
    }

    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<Map<String, Object?>> exportPayload() async {
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'Eggbound Rush',
      'objects': await _db.query('objects'),
      'zones': await _db.query('zones'),
      'eggs': await _db.query('eggs'),
      'activities': await _db.query('activities'),
    };
  }
}

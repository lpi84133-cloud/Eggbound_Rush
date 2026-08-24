import 'package:sqflite/sqflite.dart';

import '../core/data/app_database.dart';
import '../domain/flock.dart';

/// Per-hen production figures over a window, used to answer the question a
/// keeper actually asks: which bird is still earning her feed?
class HenProduction {
  const HenProduction({
    required this.hen,
    required this.eggsInWindow,
    required this.eggsAllTime,
    required this.lastLaidOn,
  });

  final Hen hen;
  final int eggsInWindow;
  final int eggsAllTime;
  final DateTime? lastLaidOn;

  /// Days since this hen last produced an egg, or null if she never has.
  int? get daysSinceLastEgg {
    final last = lastLaidOn;
    if (last == null) return null;
    return startOfDay(DateTime.now()).difference(startOfDay(last)).inDays;
  }

  /// Eggs per week over the window, the unit keepers compare birds in.
  double ratePerWeek(int windowDays) =>
      windowDays <= 0 ? 0 : eggsInWindow / windowDays * 7;

  /// A hen counted as laying that has produced nothing for over a week is the
  /// single most actionable signal the app can surface.
  bool get needsAttention {
    if (!hen.status.expectsEggs) return false;
    final days = daysSinceLastEgg;
    return days == null || days >= 7;
  }
}

class FlockSummary {
  const FlockSummary({
    required this.activeHens,
    required this.layingHens,
    required this.eggsToday,
    required this.eggsThisWeek,
    required this.eggsLastWeek,
    required this.eggsAllTime,
    required this.hensNeedingAttention,
    required this.careDue,
  });

  final int activeHens;
  final int layingHens;
  final int eggsToday;
  final int eggsThisWeek;
  final int eggsLastWeek;
  final int eggsAllTime;
  final int hensNeedingAttention;
  final int careDue;

  /// Week-on-week change as a percentage. Null when there is no prior week to
  /// compare against, so the UI can stay quiet instead of showing a fake 0%.
  double? get weekChangePercent {
    if (eggsLastWeek == 0) return null;
    return (eggsThisWeek - eggsLastWeek) / eggsLastWeek * 100;
  }

  /// Share of the theoretical maximum (one egg per laying hen per day).
  double get weeklyLayRate {
    if (layingHens == 0) return 0;
    return (eggsThisWeek / (layingHens * 7)).clamp(0.0, 1.0);
  }
}

class FeedCostSummary {
  const FeedCostSummary({
    required this.totalSpent,
    required this.totalKg,
    required this.eggsSinceFirstPurchase,
    required this.since,
  });

  final double totalSpent;
  final double totalKg;
  final int eggsSinceFirstPurchase;
  final DateTime? since;

  /// The number every keeper eventually wants: what one egg actually costs.
  double? get costPerEgg {
    if (eggsSinceFirstPurchase <= 0 || totalSpent <= 0) return null;
    return totalSpent / eggsSinceFirstPurchase;
  }

  double? get averageCostPerKg =>
      totalKg <= 0 ? null : totalSpent / totalKg;

  /// Rough estimate of how many days the current feed stock will last.
  /// Assumes ~120 g per hen per day — a typical layer on complete pellet feed.
  /// Returns null when there are no purchases recorded or no active hens.
  int? estimatedDaysRemaining(int activeHens) {
    if (activeHens <= 0 || totalKg <= 0 || since == null) return null;
    const kgPerHenPerDay = 0.12;
    final daysSince = DateTime.now().difference(since!).inDays;
    final consumed = daysSince * activeHens * kgPerHenPerDay;
    final remaining = (totalKg - consumed).clamp(0.0, double.infinity);
    return (remaining / (activeHens * kgPerHenPerDay)).round();
  }
}

class FlockRepository {
  FlockRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  int _ms(DateTime value) => value.millisecondsSinceEpoch;

  // ---------------------------------------------------------------- hens

  Future<List<Hen>> hens({bool includeArchived = false}) async {
    final rows = await _db.query(
      'hens',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'archived_at IS NOT NULL, name COLLATE NOCASE',
    );
    return rows.map(Hen.fromRow).toList(growable: false);
  }

  Future<Hen?> henById(int id) async {
    final rows = await _db.query('hens', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Hen.fromRow(rows.first);
  }

  Future<int> addHen({
    required String name,
    required EggColor eggColor,
    required DateTime acquiredOn,
    String? breed,
    DateTime? hatchedOn,
    HenStatus status = HenStatus.laying,
    String? photoPath,
    String? notes,
  }) async {
    final now = DateTime.now();
    return _db.insert('hens', {
      'name': name.trim(),
      'breed': breed?.trim(),
      'egg_color': eggColor.name,
      'hatched_on': hatchedOn == null ? null : _ms(startOfDay(hatchedOn)),
      'acquired_on': _ms(startOfDay(acquiredOn)),
      'status': status.name,
      'photo_path': photoPath,
      'notes': notes?.trim(),
      'created_at': _ms(now),
    });
  }

  Future<void> updateHen(Hen hen) async {
    await _db.update(
      'hens',
      {
        'name': hen.name.trim(),
        'breed': hen.breed?.trim(),
        'egg_color': hen.eggColor.name,
        'hatched_on':
            hen.hatchedOn == null ? null : _ms(startOfDay(hen.hatchedOn!)),
        'acquired_on': _ms(startOfDay(hen.acquiredOn)),
        'status': hen.status.name,
        'photo_path': hen.photoPath,
        'notes': hen.notes?.trim(),
        'archived_at': hen.archivedAt == null ? null : _ms(hen.archivedAt!),
      },
      where: 'id = ?',
      whereArgs: [hen.id],
    );
  }

  /// Archiving keeps the bird's production history intact, which matters when
  /// comparing this year's flock against last year's.
  Future<void> archiveHen(int id) => _db.update(
        'hens',
        {'archived_at': _ms(DateTime.now()), 'status': HenStatus.retired.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> restoreHen(int id) => _db.update(
        'hens',
        {'archived_at': null, 'status': HenStatus.laying.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> deleteHen(int id) =>
      _db.delete('hens', where: 'id = ?', whereArgs: [id]);

  // ----------------------------------------------------------- egg records

  Future<int> logEggs({
    int? henId,
    required int count,
    DateTime? on,
    String? note,
  }) async {
    final day = startOfDay(on ?? DateTime.now());
    return _db.insert('egg_records', {
      'hen_id': henId,
      'collected_on': _ms(day),
      'count': count,
      'note': note?.trim(),
      'created_at': _ms(DateTime.now()),
    });
  }

  Future<void> deleteEggRecord(int id) =>
      _db.delete('egg_records', where: 'id = ?', whereArgs: [id]);

  Future<List<EggRecord>> eggRecordsForHen(int henId, {int limit = 60}) async {
    final rows = await _db.query(
      'egg_records',
      where: 'hen_id = ?',
      whereArgs: [henId],
      orderBy: 'collected_on DESC, id DESC',
      limit: limit,
    );
    return rows.map(EggRecord.fromRow).toList(growable: false);
  }

  Future<List<EggRecord>> recentEggRecords({int limit = 100}) async {
    final rows = await _db.query(
      'egg_records',
      orderBy: 'collected_on DESC, id DESC',
      limit: limit,
    );
    return rows.map(EggRecord.fromRow).toList(growable: false);
  }

  Future<int> eggsBetween(DateTime from, DateTime to) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) AS total FROM egg_records '
      'WHERE collected_on >= ? AND collected_on <= ?',
      [_ms(startOfDay(from)), _ms(startOfDay(to))],
    );
    return (result.first['total'] as num).toInt();
  }

  /// Daily totals across a window, gap-filled so a chart shows the zero days
  /// instead of silently skipping them — those gaps are the interesting part.
  Future<List<({DateTime day, int count})>> dailySeries(int days) async {
    final today = startOfDay(DateTime.now());
    final from = today.subtract(Duration(days: days - 1));
    final rows = await _db.rawQuery(
      'SELECT collected_on AS day, COALESCE(SUM(count), 0) AS total '
      'FROM egg_records WHERE collected_on >= ? '
      'GROUP BY collected_on',
      [_ms(from)],
    );

    final byDay = <int, int>{
      for (final row in rows)
        (row['day']! as int): (row['total'] as num).toInt(),
    };

    return [
      for (var i = 0; i < days; i++)
        () {
          final day = from.add(Duration(days: i));
          return (day: day, count: byDay[_ms(day)] ?? 0);
        }(),
    ];
  }

  // ------------------------------------------------------------ production

  Future<List<HenProduction>> production({int windowDays = 30}) async {
    final hensList = await hens();
    if (hensList.isEmpty) return const [];

    final from = startOfDay(
      DateTime.now().subtract(Duration(days: windowDays - 1)),
    );

    final windowRows = await _db.rawQuery(
      'SELECT hen_id, COALESCE(SUM(count), 0) AS total FROM egg_records '
      'WHERE hen_id IS NOT NULL AND collected_on >= ? GROUP BY hen_id',
      [_ms(from)],
    );
    final allTimeRows = await _db.rawQuery(
      'SELECT hen_id, COALESCE(SUM(count), 0) AS total, '
      'MAX(collected_on) AS last_day FROM egg_records '
      'WHERE hen_id IS NOT NULL GROUP BY hen_id',
    );

    final inWindow = <int, int>{
      for (final row in windowRows)
        (row['hen_id']! as int): (row['total'] as num).toInt(),
    };
    final allTime = <int, int>{
      for (final row in allTimeRows)
        (row['hen_id']! as int): (row['total'] as num).toInt(),
    };
    final lastDay = <int, DateTime>{
      for (final row in allTimeRows)
        if (row['last_day'] != null)
          (row['hen_id']! as int):
              DateTime.fromMillisecondsSinceEpoch(row['last_day']! as int),
    };

    return [
      for (final hen in hensList)
        HenProduction(
          hen: hen,
          eggsInWindow: inWindow[hen.id] ?? 0,
          eggsAllTime: allTime[hen.id] ?? 0,
          lastLaidOn: lastDay[hen.id],
        ),
    ];
  }

  Future<FlockSummary> summary() async {
    final today = startOfDay(DateTime.now());
    final weekStart = today.subtract(const Duration(days: 6));
    final lastWeekStart = today.subtract(const Duration(days: 13));
    final lastWeekEnd = today.subtract(const Duration(days: 7));

    final counts = await _db.rawQuery(
      'SELECT '
      "COUNT(*) AS active, "
      "SUM(CASE WHEN status = 'laying' THEN 1 ELSE 0 END) AS laying "
      'FROM hens WHERE archived_at IS NULL',
    );
    final activeHens = (counts.first['active'] as num?)?.toInt() ?? 0;
    final layingHens = (counts.first['laying'] as num?)?.toInt() ?? 0;

    final allTimeRow = await _db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) AS total FROM egg_records',
    );

    final attention = (await production(windowDays: 30))
        .where((entry) => entry.needsAttention)
        .length;

    final dueRow = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM health_events '
      'WHERE next_due_on IS NOT NULL AND next_due_on <= ?',
      [_ms(today.add(const Duration(days: 7)))],
    );

    return FlockSummary(
      activeHens: activeHens,
      layingHens: layingHens,
      eggsToday: await eggsBetween(today, today),
      eggsThisWeek: await eggsBetween(weekStart, today),
      eggsLastWeek: await eggsBetween(lastWeekStart, lastWeekEnd),
      eggsAllTime: (allTimeRow.first['total'] as num).toInt(),
      hensNeedingAttention: attention,
      careDue: (dueRow.first['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ------------------------------------------------------------------ feed

  Future<List<FeedEntry>> feedEntries({int limit = 50}) async {
    final rows = await _db.query(
      'feed_entries',
      orderBy: 'purchased_on DESC, id DESC',
      limit: limit,
    );
    return rows.map(FeedEntry.fromRow).toList(growable: false);
  }

  Future<int> addFeedEntry({
    required String name,
    required double weightKg,
    required double cost,
    required DateTime purchasedOn,
    String? note,
  }) =>
      _db.insert('feed_entries', {
        'name': name.trim(),
        'weight_kg': weightKg,
        'cost': cost,
        'purchased_on': _ms(startOfDay(purchasedOn)),
        'note': note?.trim(),
        'created_at': _ms(DateTime.now()),
      });

  Future<void> deleteFeedEntry(int id) =>
      _db.delete('feed_entries', where: 'id = ?', whereArgs: [id]);

  Future<FeedCostSummary> feedCosts() async {
    final totals = await _db.rawQuery(
      'SELECT COALESCE(SUM(cost), 0) AS spent, '
      'COALESCE(SUM(weight_kg), 0) AS kg, '
      'MIN(purchased_on) AS since FROM feed_entries',
    );
    final row = totals.first;
    final sinceMs = row['since'] as int?;
    final since = sinceMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(sinceMs);

    // Only eggs laid after feed tracking began can be attributed to that
    // spend, otherwise the cost per egg is flattered by earlier production.
    var eggs = 0;
    if (since != null) {
      eggs = await eggsBetween(since, DateTime.now());
    }

    return FeedCostSummary(
      totalSpent: (row['spent'] as num).toDouble(),
      totalKg: (row['kg'] as num).toDouble(),
      eggsSinceFirstPurchase: eggs,
      since: since,
    );
  }

  // ---------------------------------------------------------------- health

  Future<List<HealthEvent>> healthEvents({int? henId, int limit = 100}) async {
    final rows = await _db.query(
      'health_events',
      where: henId == null ? null : 'hen_id = ? OR hen_id IS NULL',
      whereArgs: henId == null ? null : [henId],
      orderBy: 'performed_on DESC, id DESC',
      limit: limit,
    );
    return rows.map(HealthEvent.fromRow).toList(growable: false);
  }

  /// Treatments that are overdue or fall due within [withinDays].
  Future<List<HealthEvent>> upcomingCare({int withinDays = 14}) async {
    final cutoff = startOfDay(DateTime.now()).add(Duration(days: withinDays));
    final rows = await _db.rawQuery(
      'SELECT * FROM health_events WHERE next_due_on IS NOT NULL '
      'AND next_due_on <= ? ORDER BY next_due_on ASC',
      [_ms(cutoff)],
    );
    return rows.map(HealthEvent.fromRow).toList(growable: false);
  }

  Future<int> logHealthEvent({
    int? henId,
    required HealthEventKind kind,
    required DateTime performedOn,
    DateTime? nextDueOn,
    String? note,
  }) =>
      _db.insert('health_events', {
        'hen_id': henId,
        'kind': kind.name,
        'performed_on': _ms(startOfDay(performedOn)),
        'next_due_on': nextDueOn == null ? null : _ms(startOfDay(nextDueOn)),
        'note': note?.trim(),
        'created_at': _ms(DateTime.now()),
      });

  Future<void> deleteHealthEvent(int id) =>
      _db.delete('health_events', where: 'id = ?', whereArgs: [id]);

  // ----------------------------------------------------------------- admin

  Future<bool> get isEmpty async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS total FROM hens');
    return ((rows.first['total'] as num?)?.toInt() ?? 0) == 0;
  }

  Future<void> resetEverything() async {
    final batch = _db.batch();
    batch.delete('egg_records');
    batch.delete('health_events');
    batch.delete('feed_entries');
    batch.delete('hens');
    await batch.commit(noResult: true);
  }

  /// Full local export so the keeper's records are never trapped in the app.
  Future<Map<String, Object?>> exportPayload() async {
    final hensList = await hens(includeArchived: true);
    final eggs = await _db.query('egg_records', orderBy: 'collected_on');
    final feed = await _db.query('feed_entries', orderBy: 'purchased_on');
    final health = await _db.query('health_events', orderBy: 'performed_on');

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'hens': [
        for (final hen in hensList)
          {
            'id': hen.id,
            'name': hen.name,
            'breed': hen.breed,
            'egg_color': hen.eggColor.name,
            'hatched_on': hen.hatchedOn?.toIso8601String(),
            'acquired_on': hen.acquiredOn.toIso8601String(),
            'status': hen.status.name,
            'notes': hen.notes,
            'archived': hen.isArchived,
          },
      ],
      'egg_records': eggs,
      'feed_entries': feed,
      'health_events': health,
    };
  }
}

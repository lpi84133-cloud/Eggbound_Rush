import 'package:sqflite/sqflite.dart';

import '../core/data/app_database.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';

/// Points awarded for meaningful actions. Repositioning something you already
/// placed is deliberately worth nothing, so the counter reflects real use
/// rather than repeated dragging.
abstract final class CarePoints {
  static const objectPlaced = 2;
  static const eggMarked = 2;
  static const eggCollected = 5;
  static const zoneCreated = 4;
  static const dailyFirstAction = 8;
}

class PastureSnapshot {
  const PastureSnapshot({
    required this.objects,
    required this.eggs,
    required this.zones,
  });

  final List<PastureObject> objects;
  final List<EggMark> eggs;
  final List<PastureZone> zones;

  static const empty = PastureSnapshot(objects: [], eggs: [], zones: []);

  int get chickenCount => objects
      .where((o) => o.item.category == ItemCategory.chicken)
      .length;

  int get nestCount =>
      objects.where((o) => o.item.category == ItemCategory.nest).length;

  List<EggMark> get pendingEggs =>
      eggs.where((egg) => !egg.isCollected).toList(growable: false);
}

class PastureRepository {
  PastureRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<PastureSnapshot> loadSnapshot() async {
    final objectRows = await _db.query('objects', orderBy: 'y ASC, id ASC');
    final eggRows = await _db.query(
      'eggs',
      where: 'collected_at IS NULL',
      orderBy: 'y ASC, id ASC',
    );
    final zoneRows = await _db.query('zones', orderBy: 'created_at ASC');

    return PastureSnapshot(
      objects: objectRows.map(PastureObject.fromRow).toList(growable: false),
      eggs: eggRows.map(EggMark.fromRow).toList(growable: false),
      zones: zoneRows.map(PastureZone.fromRow).toList(growable: false),
    );
  }

  Future<bool> get isEmpty async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM objects'),
    );
    return (count ?? 0) == 0;
  }

  Future<int> addObject(CatalogItem item, double x, double y) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insert('objects', {
      'catalog_id': item.id,
      'category': item.category.name,
      'x': x,
      'y': y,
      'created_at': now,
      'updated_at': now,
    });
    await logActivity(
      kind: ActivityKind.objectPlaced,
      title: 'Placed ${item.name}',
      points: CarePoints.objectPlaced,
    );
    return id;
  }

  Future<void> moveObject(PastureObject object, double x, double y) async {
    await _db.update(
      'objects',
      {'x': x, 'y': y, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [object.id],
    );
    await logActivity(
      kind: ActivityKind.objectMoved,
      title: 'Moved ${object.item.name}',
    );
  }

  Future<void> removeObject(PastureObject object) async {
    await _db.delete('objects', where: 'id = ?', whereArgs: [object.id]);
    await logActivity(
      kind: ActivityKind.objectRemoved,
      title: 'Removed ${object.item.name}',
    );
  }

  Future<int> markEgg(EggType type, double x, double y) async {
    final id = await _db.insert('eggs', {
      'type': type.name,
      'x': x,
      'y': y,
      'marked_at': DateTime.now().millisecondsSinceEpoch,
    });
    await logActivity(
      kind: ActivityKind.eggMarked,
      title: 'Marked ${type.label.toLowerCase()}',
      points: CarePoints.eggMarked,
    );
    return id;
  }

  Future<void> moveEgg(EggMark egg, double x, double y) async {
    await _db.update(
      'eggs',
      {'x': x, 'y': y},
      where: 'id = ?',
      whereArgs: [egg.id],
    );
  }

  Future<void> collectEgg(EggMark egg) async {
    await _db.update(
      'eggs',
      {'collected_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [egg.id],
    );
    await logActivity(
      kind: ActivityKind.eggCollected,
      title: 'Collected ${egg.type.label.toLowerCase()}',
      points: CarePoints.eggCollected,
    );
  }

  /// Puts a collected egg back on the board and rolls back the points it
  /// awarded, so an accidental tap never inflates the statistics.
  Future<void> undoCollect(int eggId) async {
    await _db.update(
      'eggs',
      {'collected_at': null},
      where: 'id = ?',
      whereArgs: [eggId],
    );
    await _db.delete(
      'activities',
      where: 'id = (SELECT id FROM activities WHERE kind = ? '
          'ORDER BY created_at DESC, id DESC LIMIT 1)',
      whereArgs: [ActivityKind.eggCollected.name],
    );
  }

  Future<void> removeEgg(EggMark egg) async {
    await _db.delete('eggs', where: 'id = ?', whereArgs: [egg.id]);
    await logActivity(
      kind: ActivityKind.eggRemoved,
      title: 'Removed ${egg.type.label.toLowerCase()}',
    );
  }

  Future<int> addZone(PastureZone zone) async {
    final id = await _db.insert('zones', {
      'name': zone.name,
      'kind': zone.kind.name,
      'cx': zone.cx,
      'cy': zone.cy,
      'w': zone.w,
      'h': zone.h,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await logActivity(
      kind: ActivityKind.zoneCreated,
      title: 'Created zone ${zone.name}',
      points: CarePoints.zoneCreated,
    );
    return id;
  }

  Future<void> updateZone(PastureZone zone) async {
    await _db.update(
      'zones',
      {
        'name': zone.name,
        'kind': zone.kind.name,
        'cx': zone.cx,
        'cy': zone.cy,
        'w': zone.w,
        'h': zone.h,
      },
      where: 'id = ?',
      whereArgs: [zone.id],
    );
    await logActivity(
      kind: ActivityKind.zoneUpdated,
      title: 'Updated zone ${zone.name}',
    );
  }

  Future<void> removeZone(PastureZone zone) async {
    await _db.delete('zones', where: 'id = ?', whereArgs: [zone.id]);
    await logActivity(
      kind: ActivityKind.zoneRemoved,
      title: 'Removed zone ${zone.name}',
    );
  }

  Future<void> logActivity({
    required ActivityKind kind,
    required String title,
    String? detail,
    int points = 0,
  }) async {
    await _db.insert('activities', {
      'kind': kind.name,
      'title': title,
      'detail': detail,
      'points': points,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Grants a once-per-day bonus the first time the user does something
  /// meaningful. Returns true when the bonus was actually granted.
  Future<bool> grantDailyBonusIfDue() async {
    final startOfDay = DateTime.now();
    final midnight = DateTime(startOfDay.year, startOfDay.month, startOfDay.day)
        .millisecondsSinceEpoch;
    final existing = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM activities WHERE kind = ? AND created_at >= ?',
      [ActivityKind.itemUnlocked.name, midnight],
    ));
    if ((existing ?? 0) > 0) return false;

    final actionsToday = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM activities WHERE created_at >= ? AND points > 0',
      [midnight],
    ));
    if ((actionsToday ?? 0) == 0) return false;

    await logActivity(
      kind: ActivityKind.itemUnlocked,
      title: 'Daily activity bonus',
      detail: 'Awarded for keeping the pasture up to date today.',
      points: CarePoints.dailyFirstAction,
    );
    return true;
  }

  Future<List<Activity>> recentActivities({int limit = 200}) async {
    final rows = await _db.query(
      'activities',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(Activity.fromRow).toList(growable: false);
  }

  Future<void> clearActivities() => _db.delete('activities');

  Future<void> resetEverything() async {
    final batch = _db.batch();
    batch.delete('objects');
    batch.delete('eggs');
    batch.delete('zones');
    batch.delete('activities');
    batch.delete('unlocks');
    await batch.commit(noResult: true);
  }

  Future<void> seedStarterPasture() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();

    void placeObject(String catalogId, double x, double y) {
      final item = Catalog.byId(catalogId);
      batch.insert('objects', {
        'catalog_id': item.id,
        'category': item.category.name,
        'x': x,
        'y': y,
        'created_at': now,
        'updated_at': now,
      });
    }

    void placeZone(String name, ZoneKind kind, double cx, double cy, double w,
        double h) {
      batch.insert('zones', {
        'name': name,
        'kind': kind.name,
        'cx': cx,
        'cy': cy,
        'w': w,
        'h': h,
        'created_at': now,
      });
    }

    // Three bands down the board, each with its own row of contents. A hen
    // sprite is roughly 0.22 of the board width, so nothing is placed closer
    // than 0.26 to its neighbour and every piece sits below its zone label
    // rather than behind it.
    // The first band starts below 0.21 so its label clears the floating
    // header, and the three bands do not touch each other.
    placeZone('Nesting Corner', ZoneKind.nesting, 0.31, 0.34, 0.52, 0.26);
    placeZone('Feeding Spot', ZoneKind.feeding, 0.70, 0.60, 0.52, 0.22);
    placeZone('Open Pasture', ZoneKind.free, 0.40, 0.83, 0.60, 0.20);

    // Nesting band: nest on the left, the sitting hen a clear step to its
    // right, both dropped below the label line at the top of the zone.
    placeObject('nest', 0.16, 0.35);
    placeObject('chicken_nesting', 0.45, 0.33);

    // Feeding band: the two troughs are the widest pieces on the board, so
    // they take the full width of their zone and the hen stands clear of it.
    placeObject('feed_trough', 0.58, 0.62);
    placeObject('water_trough', 0.85, 0.62);
    placeObject('chicken_idle', 0.19, 0.60);

    // Open pasture: the roaming hen sits right of the "Mark egg" button so
    // the chrome never covers her, with decor well away on the other side.
    placeObject('chicken_walk', 0.45, 0.85);
    placeObject('grass_tuft', 0.76, 0.87);

    batch.insert('activities', {
      'kind': ActivityKind.objectPlaced.name,
      'title': 'Starter pasture created',
      'detail': 'A few hens, a nest and basic equipment to start from.',
      'points': 0,
      'created_at': now,
    });

    await batch.commit(noResult: true);
  }
}

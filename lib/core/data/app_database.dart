import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage. The app never talks to a server for user data, so
/// this file is the single source of truth for everything the user creates.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _fileName = 'eggbound_rush.db';
  static const _version = 3;

  static Future<AppDatabase> open() async {
    final directory = await getDatabasesPath();
    final database = await openDatabase(
      p.join(directory, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createSchema(db, version);
        await _createFlockSchema(db);
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) await _createFlockSchema(db);
        if (from < 3) await _clearStarterLayout(db);
      },
    );
    return AppDatabase._(database);
  }

  /// Flock bookkeeping: the individual birds and every record attached to
  /// them. This is what the app exists for — the visual coop map is a way to
  /// read these records spatially, not a separate feature.
  static Future<void> _createFlockSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE hens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        breed TEXT,
        egg_color TEXT NOT NULL DEFAULT 'brown',
        hatched_on INTEGER,
        acquired_on INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'laying',
        photo_path TEXT,
        notes TEXT,
        archived_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // A row per collection event. hen_id is nullable so a keeper who cannot
    // tell which bird laid what can still log the day's total for the coop.
    batch.execute('''
      CREATE TABLE egg_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hen_id INTEGER REFERENCES hens (id) ON DELETE SET NULL,
        collected_on INTEGER NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE feed_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        cost REAL NOT NULL,
        purchased_on INTEGER NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // hen_id null means the treatment covered the whole flock.
    batch.execute('''
      CREATE TABLE health_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hen_id INTEGER REFERENCES hens (id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        performed_on INTEGER NOT NULL,
        next_due_on INTEGER,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_egg_records_day ON egg_records (collected_on DESC)',
    );
    batch.execute(
      'CREATE INDEX idx_egg_records_hen ON egg_records (hen_id)',
    );
    batch.execute(
      'CREATE INDEX idx_health_due ON health_events (next_due_on)',
    );
    batch.execute(
      'CREATE INDEX idx_hens_archived ON hens (archived_at)',
    );

    await batch.commit(noResult: true);
  }

  /// The first starter layout placed pieces closer together than a hen sprite
  /// is wide, so on a phone the birds overlapped each other and their zone
  /// labels. This moves the untouched starter pieces onto the corrected grid.
  /// Anything the keeper has dragged since is left exactly where they put it,
  /// which is why every statement is keyed to the original coordinates.
  static Future<void> _clearStarterLayout(Database db) async {
    const zones = <(String, double, double, double, double)>[
      ('Nesting Corner', 0.31, 0.34, 0.52, 0.26),
      ('Feeding Spot', 0.70, 0.60, 0.52, 0.22),
      ('Open Pasture', 0.40, 0.83, 0.60, 0.20),
    ];

    // catalogId, oldX, oldY, newX, newY
    const objects = <(String, double, double, double, double)>[
      ('nest', 0.18, 0.24, 0.16, 0.35),
      ('chicken_nesting', 0.36, 0.30, 0.45, 0.33),
      ('chicken_idle', 0.47, 0.21, 0.19, 0.60),
      ('feed_trough', 0.60, 0.52, 0.58, 0.62),
      ('water_trough', 0.84, 0.52, 0.85, 0.62),
      ('chicken_walk', 0.56, 0.80, 0.45, 0.85),
      ('grass_tuft', 0.26, 0.82, 0.76, 0.87),
    ];

    final batch = db.batch();

    for (final (name, cx, cy, w, h) in zones) {
      batch.update(
        'zones',
        {'cx': cx, 'cy': cy, 'w': w, 'h': h},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    for (final (catalogId, oldX, oldY, newX, newY) in objects) {
      batch.update(
        'objects',
        {'x': newX, 'y': newY},
        where: 'catalog_id = ? AND abs(x - ?) < 0.001 AND abs(y - ?) < 0.001',
        whereArgs: [catalogId, oldX, oldY],
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        cx REAL NOT NULL,
        cy REAL NOT NULL,
        w REAL NOT NULL,
        h REAL NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE objects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        catalog_id TEXT NOT NULL,
        category TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE eggs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        marked_at INTEGER NOT NULL,
        collected_at INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        detail TEXT,
        points INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE unlocks (
        item_key TEXT PRIMARY KEY,
        unlocked_at INTEGER NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_eggs_collected_at ON eggs (collected_at)',
    );
    batch.execute(
      'CREATE INDEX idx_activities_created_at ON activities (created_at DESC)',
    );

    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}

import 'package:flutter/foundation.dart';

import '../core/theme/app_colors.dart';
import 'catalog.dart';

enum EggType { white, golden, patterned }

extension EggTypeInfo on EggType {
  String get id => name;

  String get label => switch (this) {
        EggType.white => 'White egg',
        EggType.golden => 'Golden egg',
        EggType.patterned => 'Patterned egg',
      };

  String get asset => switch (this) {
        EggType.white => 'assets/app/images/egg_white.png',
        EggType.golden => 'assets/app/images/egg_golden.png',
        EggType.patterned => 'assets/app/images/egg_patterned.png',
      };

  static EggType parse(String value) =>
      EggType.values.firstWhere((type) => type.name == value,
          orElse: () => EggType.white);
}

enum ZoneKind { nesting, feeding, water, free, collection }

extension ZoneKindInfo on ZoneKind {
  String get label => switch (this) {
        ZoneKind.nesting => 'Nesting',
        ZoneKind.feeding => 'Feeding',
        ZoneKind.water => 'Water',
        ZoneKind.free => 'Free range',
        ZoneKind.collection => 'Collection',
      };

  String get hint => switch (this) {
        ZoneKind.nesting => 'Where nests and expected eggs live.',
        ZoneKind.feeding => 'Where feed troughs are placed.',
        ZoneKind.water => 'Where water troughs are placed.',
        ZoneKind.free => 'Open pasture with no special purpose.',
        ZoneKind.collection => 'Where collected eggs are gathered.',
      };

  int get color => switch (this) {
        ZoneKind.nesting => AppColors.zoneNesting.toARGB32(),
        ZoneKind.feeding => AppColors.zoneFeeding.toARGB32(),
        ZoneKind.water => AppColors.zoneWater.toARGB32(),
        ZoneKind.free => AppColors.zoneFree.toARGB32(),
        ZoneKind.collection => AppColors.zoneCollection.toARGB32(),
      };

  static ZoneKind parse(String value) =>
      ZoneKind.values.firstWhere((kind) => kind.name == value,
          orElse: () => ZoneKind.free);
}

@immutable
class PastureObject {
  const PastureObject({
    required this.id,
    required this.catalogId,
    required this.x,
    required this.y,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String catalogId;

  /// Normalised position inside the pasture board, 0..1 on both axes.
  final double x;
  final double y;
  final DateTime createdAt;
  final String? note;

  CatalogItem get item => Catalog.byId(catalogId);

  PastureObject copyWith({double? x, double? y, String? note}) => PastureObject(
        id: id,
        catalogId: catalogId,
        x: x ?? this.x,
        y: y ?? this.y,
        createdAt: createdAt,
        note: note ?? this.note,
      );

  factory PastureObject.fromRow(Map<String, Object?> row) => PastureObject(
        id: row['id']! as int,
        catalogId: row['catalog_id']! as String,
        x: (row['x']! as num).toDouble(),
        y: (row['y']! as num).toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        note: row['note'] as String?,
      );
}

@immutable
class EggMark {
  const EggMark({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.markedAt,
    this.collectedAt,
  });

  final int id;
  final EggType type;
  final double x;
  final double y;
  final DateTime markedAt;
  final DateTime? collectedAt;

  bool get isCollected => collectedAt != null;

  factory EggMark.fromRow(Map<String, Object?> row) => EggMark(
        id: row['id']! as int,
        type: EggTypeInfo.parse(row['type']! as String),
        x: (row['x']! as num).toDouble(),
        y: (row['y']! as num).toDouble(),
        markedAt: DateTime.fromMillisecondsSinceEpoch(row['marked_at']! as int),
        collectedAt: row['collected_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['collected_at']! as int),
      );
}

@immutable
class PastureZone {
  const PastureZone({
    required this.id,
    required this.name,
    required this.kind,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.createdAt,
  });

  final int id;
  final String name;
  final ZoneKind kind;
  final double cx;
  final double cy;
  final double w;
  final double h;
  final DateTime createdAt;

  double get left => cx - w / 2;
  double get top => cy - h / 2;
  double get right => cx + w / 2;
  double get bottom => cy + h / 2;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  PastureZone copyWith({
    String? name,
    ZoneKind? kind,
    double? cx,
    double? cy,
    double? w,
    double? h,
  }) =>
      PastureZone(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        w: w ?? this.w,
        h: h ?? this.h,
        createdAt: createdAt,
      );

  factory PastureZone.fromRow(Map<String, Object?> row) => PastureZone(
        id: row['id']! as int,
        name: row['name']! as String,
        kind: ZoneKindInfo.parse(row['kind']! as String),
        cx: (row['cx']! as num).toDouble(),
        cy: (row['cy']! as num).toDouble(),
        w: (row['w']! as num).toDouble(),
        h: (row['h']! as num).toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      );
}

enum ActivityKind {
  objectPlaced,
  objectMoved,
  objectRemoved,
  eggMarked,
  eggCollected,
  eggRemoved,
  zoneCreated,
  zoneUpdated,
  zoneRemoved,
  itemUnlocked,
  themeChanged,
}

extension ActivityKindInfo on ActivityKind {
  static ActivityKind parse(String value) =>
      ActivityKind.values.firstWhere((kind) => kind.name == value,
          orElse: () => ActivityKind.objectPlaced);
}

@immutable
class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.title,
    required this.points,
    required this.createdAt,
    this.detail,
  });

  final int id;
  final ActivityKind kind;
  final String title;
  final String? detail;
  final int points;
  final DateTime createdAt;

  factory Activity.fromRow(Map<String, Object?> row) => Activity(
        id: row['id']! as int,
        kind: ActivityKindInfo.parse(row['kind']! as String),
        title: row['title']! as String,
        detail: row['detail'] as String?,
        points: row['points']! as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      );
}

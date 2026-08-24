import 'package:flutter/foundation.dart';

/// Where a bird is in her laying cycle. This is the single most useful thing
/// a keeper tracks: a hen that stops laying is either moulting, broody, ill,
/// or simply too old, and each of those calls for a different response.
enum HenStatus { laying, molting, broody, notLaying, retired }

extension HenStatusInfo on HenStatus {
  String get label => switch (this) {
        HenStatus.laying => 'Laying',
        HenStatus.molting => 'Moulting',
        HenStatus.broody => 'Broody',
        HenStatus.notLaying => 'Not laying',
        HenStatus.retired => 'Retired',
      };

  String get hint => switch (this) {
        HenStatus.laying => 'Producing normally.',
        HenStatus.molting => 'Regrowing feathers — laying pauses for 6-12 weeks.',
        HenStatus.broody => 'Sitting on eggs and refusing to lay.',
        HenStatus.notLaying => 'Stopped laying for an unclear reason. Worth a check.',
        HenStatus.retired => 'No longer expected to lay. Kept as a pet.',
      };

  /// Whether the app should expect eggs from this bird when it reports gaps.
  bool get expectsEggs => this == HenStatus.laying;

  static HenStatus parse(String value) => HenStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => HenStatus.laying,
      );
}

enum EggColor { white, cream, brown, darkBrown, blue, green, speckled }

extension EggColorInfo on EggColor {
  String get label => switch (this) {
        EggColor.white => 'White',
        EggColor.cream => 'Cream',
        EggColor.brown => 'Brown',
        EggColor.darkBrown => 'Dark brown',
        EggColor.blue => 'Blue',
        EggColor.green => 'Green',
        EggColor.speckled => 'Speckled',
      };

  /// Egg shell colour is the practical way keepers attribute an egg to a bird
  /// when several hens share one nesting box.
  int get swatch => switch (this) {
        EggColor.white => 0xFFF6F1E7,
        EggColor.cream => 0xFFF0E2C8,
        EggColor.brown => 0xFFC98A5B,
        EggColor.darkBrown => 0xFF8E5533,
        EggColor.blue => 0xFFB9D3D6,
        EggColor.green => 0xFFC2CFA8,
        EggColor.speckled => 0xFFD9BD97,
      };

  static EggColor parse(String value) => EggColor.values.firstWhere(
        (color) => color.name == value,
        orElse: () => EggColor.brown,
      );
}

@immutable
class Hen {
  const Hen({
    required this.id,
    required this.name,
    required this.eggColor,
    required this.acquiredOn,
    required this.status,
    required this.createdAt,
    this.breed,
    this.hatchedOn,
    this.photoPath,
    this.notes,
    this.archivedAt,
  });

  final int id;
  final String name;
  final String? breed;
  final EggColor eggColor;

  /// Hatch date drives the age-based expectations: pullets start around 18-22
  /// weeks and production tapers after the second or third year.
  final DateTime? hatchedOn;
  final DateTime acquiredOn;
  final HenStatus status;
  final String? photoPath;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime createdAt;

  bool get isArchived => archivedAt != null;

  /// Age in whole months, or null when the hatch date is unknown.
  int? get ageInMonths {
    final hatched = hatchedOn;
    if (hatched == null) return null;
    final now = DateTime.now();
    return (now.year - hatched.year) * 12 + now.month - hatched.month;
  }

  String get ageLabel {
    final months = ageInMonths;
    if (months == null) return 'Age unknown';
    if (months < 12) return '$months mo';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '$years yr' : '$years yr $rest mo';
  }

  /// Rough guidance used to explain a drop in output rather than to hide it.
  String? get ageNote {
    final months = ageInMonths;
    if (months == null) return null;
    if (months < 18) return 'Too young to lay yet.';
    if (months < 22) return 'Should be starting to lay about now.';
    if (months <= 24) return 'In her most productive year.';
    if (months <= 48) return 'Output naturally tapers from year two.';
    return 'Past peak laying age — a slow-down is expected.';
  }

  Hen copyWith({
    String? name,
    String? breed,
    EggColor? eggColor,
    DateTime? hatchedOn,
    DateTime? acquiredOn,
    HenStatus? status,
    String? photoPath,
    String? notes,
    DateTime? archivedAt,
    bool clearArchived = false,
    bool clearPhoto = false,
    bool clearHatched = false,
  }) =>
      Hen(
        id: id,
        name: name ?? this.name,
        breed: breed ?? this.breed,
        eggColor: eggColor ?? this.eggColor,
        hatchedOn: clearHatched ? null : (hatchedOn ?? this.hatchedOn),
        acquiredOn: acquiredOn ?? this.acquiredOn,
        status: status ?? this.status,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        notes: notes ?? this.notes,
        archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
        createdAt: createdAt,
      );

  factory Hen.fromRow(Map<String, Object?> row) => Hen(
        id: row['id']! as int,
        name: row['name']! as String,
        breed: row['breed'] as String?,
        eggColor: EggColorInfo.parse(row['egg_color']! as String),
        hatchedOn: _date(row['hatched_on']),
        acquiredOn: _date(row['acquired_on'])!,
        status: HenStatusInfo.parse(row['status']! as String),
        photoPath: row['photo_path'] as String?,
        notes: row['notes'] as String?,
        archivedAt: _date(row['archived_at']),
        createdAt: _date(row['created_at'])!,
      );
}

@immutable
class EggRecord {
  const EggRecord({
    required this.id,
    required this.collectedOn,
    required this.count,
    required this.createdAt,
    this.henId,
    this.note,
  });

  final int id;

  /// Null when the keeper logged a coop total instead of attributing the eggs
  /// to a specific bird.
  final int? henId;
  final DateTime collectedOn;
  final int count;
  final String? note;
  final DateTime createdAt;

  factory EggRecord.fromRow(Map<String, Object?> row) => EggRecord(
        id: row['id']! as int,
        henId: row['hen_id'] as int?,
        collectedOn: _date(row['collected_on'])!,
        count: row['count']! as int,
        note: row['note'] as String?,
        createdAt: _date(row['created_at'])!,
      );
}

@immutable
class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.name,
    required this.weightKg,
    required this.cost,
    required this.purchasedOn,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String name;
  final double weightKg;
  final double cost;
  final DateTime purchasedOn;
  final String? note;
  final DateTime createdAt;

  double get costPerKg => weightKg <= 0 ? 0 : cost / weightKg;

  factory FeedEntry.fromRow(Map<String, Object?> row) => FeedEntry(
        id: row['id']! as int,
        name: row['name']! as String,
        weightKg: (row['weight_kg']! as num).toDouble(),
        cost: (row['cost']! as num).toDouble(),
        purchasedOn: _date(row['purchased_on'])!,
        note: row['note'] as String?,
        createdAt: _date(row['created_at'])!,
      );
}

/// Routine flock care. Missing a mite or worm treatment is one of the most
/// common ways a backyard keeper loses birds, so these carry a due date.
enum HealthEventKind {
  deworming,
  miteTreatment,
  vaccination,
  vetVisit,
  injury,
  illness,
  weighed,
  other,
}

extension HealthEventKindInfo on HealthEventKind {
  String get label => switch (this) {
        HealthEventKind.deworming => 'Worming',
        HealthEventKind.miteTreatment => 'Mite treatment',
        HealthEventKind.vaccination => 'Vaccination',
        HealthEventKind.vetVisit => 'Vet visit',
        HealthEventKind.injury => 'Injury',
        HealthEventKind.illness => 'Illness',
        HealthEventKind.weighed => 'Weight check',
        HealthEventKind.other => 'Other',
      };

  /// Typical interval keepers use, offered as a default when logging.
  Duration? get defaultInterval => switch (this) {
        HealthEventKind.deworming => const Duration(days: 90),
        HealthEventKind.miteTreatment => const Duration(days: 30),
        HealthEventKind.vaccination => const Duration(days: 365),
        HealthEventKind.weighed => const Duration(days: 30),
        _ => null,
      };

  static HealthEventKind parse(String value) =>
      HealthEventKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => HealthEventKind.other,
      );
}

@immutable
class HealthEvent {
  const HealthEvent({
    required this.id,
    required this.kind,
    required this.performedOn,
    required this.createdAt,
    this.henId,
    this.nextDueOn,
    this.note,
  });

  final int id;

  /// Null means the treatment applied to the whole flock at once.
  final int? henId;
  final HealthEventKind kind;
  final DateTime performedOn;
  final DateTime? nextDueOn;
  final String? note;
  final DateTime createdAt;

  bool get isOverdue {
    final due = nextDueOn;
    return due != null && due.isBefore(DateTime.now());
  }

  int? get daysUntilDue {
    final due = nextDueOn;
    if (due == null) return null;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  factory HealthEvent.fromRow(Map<String, Object?> row) => HealthEvent(
        id: row['id']! as int,
        henId: row['hen_id'] as int?,
        kind: HealthEventKindInfo.parse(row['kind']! as String),
        performedOn: _date(row['performed_on'])!,
        nextDueOn: _date(row['next_due_on']),
        note: row['note'] as String?,
        createdAt: _date(row['created_at'])!,
      );
}

DateTime? _date(Object? value) => value == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(value as int);

/// Normalises a timestamp to local midnight. Egg counts are per calendar day,
/// so every comparison in the app has to agree on where a day starts.
DateTime startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/flock_repository.dart';
import '../../domain/flock.dart';
import '../boot/boot_controller.dart';

FlockRepository _repo(Ref ref) => ref.watch(servicesProvider).flock;

/// How far back the production comparison looks. Kept in one place so the
/// flock list and the hen detail always agree on the window.
final productionWindowProvider = StateProvider<int>((ref) => 30);

final hensProvider = FutureProvider<List<Hen>>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).hens();
});

final archivedHensProvider = FutureProvider<List<Hen>>((ref) async {
  ref.watch(dataRevisionProvider);
  final all = await _repo(ref).hens(includeArchived: true);
  return all.where((hen) => hen.isArchived).toList(growable: false);
});

final flockSummaryProvider = FutureProvider<FlockSummary>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).summary();
});

final henProductionProvider =
    FutureProvider<List<HenProduction>>((ref) async {
  ref.watch(dataRevisionProvider);
  final window = ref.watch(productionWindowProvider);
  return _repo(ref).production(windowDays: window);
});

final henByIdProvider = FutureProvider.family<Hen?, int>((ref, id) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).henById(id);
});

final henEggRecordsProvider =
    FutureProvider.family<List<EggRecord>, int>((ref, henId) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).eggRecordsForHen(henId);
});

final henHealthProvider =
    FutureProvider.family<List<HealthEvent>, int>((ref, henId) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).healthEvents(henId: henId);
});

final dailySeriesProvider =
    FutureProvider.family<List<({DateTime day, int count})>, int>(
        (ref, days) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).dailySeries(days);
});

final upcomingCareProvider = FutureProvider<List<HealthEvent>>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).upcomingCare();
});

final allHealthEventsProvider = FutureProvider<List<HealthEvent>>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).healthEvents();
});

final feedEntriesProvider = FutureProvider<List<FeedEntry>>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).feedEntries();
});

final feedCostsProvider = FutureProvider<FeedCostSummary>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).feedCosts();
});

final recentEggRecordsProvider = FutureProvider<List<EggRecord>>((ref) async {
  ref.watch(dataRevisionProvider);
  return _repo(ref).recentEggRecords();
});

/// Single entry point for every write, so no screen has to remember to bump
/// the revision counter that all the derived views listen to.
class FlockActions {
  FlockActions(this._ref);

  final Ref _ref;

  FlockRepository get _repository => _ref.read(servicesProvider).flock;

  void _touch() => _ref.read(dataRevisionProvider.notifier).state++;

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
    final id = await _repository.addHen(
      name: name,
      eggColor: eggColor,
      acquiredOn: acquiredOn,
      breed: breed,
      hatchedOn: hatchedOn,
      status: status,
      photoPath: photoPath,
      notes: notes,
    );
    _touch();
    return id;
  }

  Future<void> updateHen(Hen hen) async {
    await _repository.updateHen(hen);
    _touch();
  }

  Future<void> archiveHen(int id) async {
    await _repository.archiveHen(id);
    _touch();
  }

  Future<void> restoreHen(int id) async {
    await _repository.restoreHen(id);
    _touch();
  }

  Future<void> deleteHen(int id) async {
    await _repository.deleteHen(id);
    _touch();
  }

  Future<void> logEggs({
    int? henId,
    required int count,
    DateTime? on,
    String? note,
  }) async {
    await _repository.logEggs(henId: henId, count: count, on: on, note: note);
    _touch();
  }

  Future<void> deleteEggRecord(int id) async {
    await _repository.deleteEggRecord(id);
    _touch();
  }

  Future<void> addFeedEntry({
    required String name,
    required double weightKg,
    required double cost,
    required DateTime purchasedOn,
    String? note,
  }) async {
    await _repository.addFeedEntry(
      name: name,
      weightKg: weightKg,
      cost: cost,
      purchasedOn: purchasedOn,
      note: note,
    );
    _touch();
  }

  Future<void> deleteFeedEntry(int id) async {
    await _repository.deleteFeedEntry(id);
    _touch();
  }

  Future<void> logHealthEvent({
    int? henId,
    required HealthEventKind kind,
    required DateTime performedOn,
    DateTime? nextDueOn,
    String? note,
  }) async {
    await _repository.logHealthEvent(
      henId: henId,
      kind: kind,
      performedOn: performedOn,
      nextDueOn: nextDueOn,
      note: note,
    );
    _touch();
  }

  Future<void> deleteHealthEvent(int id) async {
    await _repository.deleteHealthEvent(id);
    _touch();
  }
}

final flockActionsProvider = Provider<FlockActions>(FlockActions.new);

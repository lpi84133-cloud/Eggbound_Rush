import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/services/sound_service.dart';
import '../../data/pasture_repository.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../boot/boot_controller.dart';

final pastureControllerProvider =
    AsyncNotifierProvider<PastureController, PastureSnapshot>(
  PastureController.new,
);

class PastureController extends AsyncNotifier<PastureSnapshot> {
  PastureRepository get _repository => ref.read(servicesProvider).pasture;

  FeedbackService get _feedback => ref.read(servicesProvider).feedback;

  @override
  Future<PastureSnapshot> build() => _repository.loadSnapshot();

  Future<void> _commit() async {
    final snapshot = await _repository.loadSnapshot();
    state = AsyncData(snapshot);
    ref.read(dataRevisionProvider.notifier).state++;
  }

  Future<void> placeItem(CatalogItem item, double x, double y) async {
    await _repository.addObject(item, x, y);
    _feedback.play(AppSound.objectPlaced);
    _feedback.lightImpact();
    await _repository.grantDailyBonusIfDue();
    await _commit();
  }

  Future<void> moveObject(PastureObject object, double x, double y) async {
    await _repository.moveObject(object, x, y);
    await _commit();
  }

  Future<void> removeObject(PastureObject object) async {
    await _repository.removeObject(object);
    await _commit();
  }

  Future<void> markEgg(EggType type, double x, double y) async {
    await _repository.markEgg(type, x, y);
    _feedback.play(AppSound.objectPlaced);
    _feedback.lightImpact();
    await _repository.grantDailyBonusIfDue();
    await _commit();
  }

  Future<void> moveEgg(EggMark egg, double x, double y) async {
    await _repository.moveEgg(egg, x, y);
    await _commit();
  }

  Future<void> collectEgg(EggMark egg) async {
    await _repository.collectEgg(egg);
    _feedback.play(AppSound.eggCollected);
    _feedback.mediumImpact();
    await _repository.grantDailyBonusIfDue();
    await _commit();
  }

  Future<void> undoCollect(int eggId) async {
    await _repository.undoCollect(eggId);
    await _commit();
  }

  Future<void> removeEgg(EggMark egg) async {
    await _repository.removeEgg(egg);
    await _commit();
  }

  Future<void> addZone(PastureZone zone) async {
    await _repository.addZone(zone);
    _feedback.success();
    await _commit();
  }

  Future<void> updateZone(PastureZone zone) async {
    await _repository.updateZone(zone);
    await _commit();
  }

  Future<void> removeZone(PastureZone zone) async {
    await _repository.removeZone(zone);
    await _commit();
  }

  Future<void> clearHistory() async {
    await _repository.clearActivities();
    await _commit();
  }

  Future<void> resetEverything({bool reseed = true}) async {
    await _repository.resetEverything();
    if (reseed) await _repository.seedStarterPasture();
    await _commit();
  }
}

/// Objects and pending eggs grouped by the zone they physically sit in, which
/// is what makes the zones a real organisational tool rather than decoration.
class ZoneContents {
  const ZoneContents({
    required this.zone,
    required this.objects,
    required this.eggs,
  });

  final PastureZone zone;
  final List<PastureObject> objects;
  final List<EggMark> eggs;

  int get chickens =>
      objects.where((o) => o.item.category == ItemCategory.chicken).length;

  int get nests =>
      objects.where((o) => o.item.category == ItemCategory.nest).length;
}

final zoneContentsProvider = Provider<List<ZoneContents>>((ref) {
  final snapshot = ref.watch(pastureControllerProvider).value;
  if (snapshot == null) return const [];
  return [
    for (final zone in snapshot.zones)
      ZoneContents(
        zone: zone,
        objects: snapshot.objects
            .where((object) => zone.contains(object.x, object.y))
            .toList(growable: false),
        eggs: snapshot.pendingEggs
            .where((egg) => zone.contains(egg.x, egg.y))
            .toList(growable: false),
      ),
  ];
});

/// Objects that sit outside every zone, surfaced so the user can tidy them up.
final unzonedObjectCountProvider = Provider<int>((ref) {
  final snapshot = ref.watch(pastureControllerProvider).value;
  if (snapshot == null || snapshot.zones.isEmpty) return 0;
  return snapshot.objects
      .where((object) =>
          !snapshot.zones.any((zone) => zone.contains(object.x, object.y)))
      .length;
});

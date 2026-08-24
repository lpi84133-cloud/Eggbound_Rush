import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/catalog.dart';
import '../../domain/models.dart';

/// Set when the user picked something in the catalog and now has to choose a
/// spot for it on the board.
sealed class PendingPlacement {
  const PendingPlacement();

  String get prompt;
}

class PlaceCatalogItem extends PendingPlacement {
  const PlaceCatalogItem(this.item);

  final CatalogItem item;

  @override
  String get prompt => 'Tap the pasture to place ${item.name}';
}

class PlaceEggMark extends PendingPlacement {
  const PlaceEggMark(this.type);

  final EggType type;

  @override
  String get prompt => 'Tap where you found the ${type.label.toLowerCase()}';
}

final pendingPlacementProvider =
    StateProvider<PendingPlacement?>((ref) => null);

import 'package:flutter/foundation.dart';

enum ItemCategory { chicken, nest, equipment, decor }

extension ItemCategoryLabel on ItemCategory {
  String get label => switch (this) {
        ItemCategory.chicken => 'Hens',
        ItemCategory.nest => 'Nests',
        ItemCategory.equipment => 'Equipment',
        ItemCategory.decor => 'Decor',
      };
}

@immutable
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.asset,
    required this.width,
    this.unlockAt = 0,
    this.description = '',
  });

  final String id;
  final String name;
  final ItemCategory category;
  final String asset;

  /// Logical width used when the item is drawn on the pasture.
  final double width;

  /// Care Points needed before the item becomes available. Zero means the item
  /// is part of the starter set.
  final int unlockAt;
  final String description;

  bool get isStarter => unlockAt == 0;
}

@immutable
class PastureTheme {
  const PastureTheme({
    required this.id,
    required this.name,
    required this.asset,
    required this.unlockAt,
  });

  final String id;
  final String name;
  final String asset;
  final int unlockAt;
}

abstract final class Catalog {
  static const items = <CatalogItem>[
    CatalogItem(
      id: 'chicken_idle',
      name: 'Standing Hen',
      category: ItemCategory.chicken,
      asset: 'assets/app/images/chicken_idle.png',
      width: 78,
      description: 'Marks a hen resting in place.',
    ),
    CatalogItem(
      id: 'chicken_walk',
      name: 'Roaming Hen',
      category: ItemCategory.chicken,
      asset: 'assets/app/images/chicken_walk.png',
      width: 82,
      description: 'Marks a hen that moves around the pasture.',
    ),
    CatalogItem(
      id: 'chicken_peck',
      name: 'Foraging Hen',
      category: ItemCategory.chicken,
      asset: 'assets/app/images/chicken_peck.png',
      width: 86,
      description: 'Marks a hen feeding on the ground.',
    ),
    CatalogItem(
      id: 'chicken_nesting',
      name: 'Nesting Hen',
      category: ItemCategory.chicken,
      asset: 'assets/app/images/chicken_nesting.png',
      width: 92,
      description: 'Marks a hen currently sitting on a nest.',
    ),
    CatalogItem(
      id: 'nest',
      name: 'Nest',
      category: ItemCategory.nest,
      asset: 'assets/app/images/nest.png',
      width: 74,
      description: 'A spot where eggs are expected.',
    ),
    CatalogItem(
      id: 'feed_trough',
      name: 'Feed Trough',
      category: ItemCategory.equipment,
      asset: 'assets/app/images/feed_trough.png',
      width: 88,
      description: 'Anchors a feeding zone.',
    ),
    CatalogItem(
      id: 'water_trough',
      name: 'Water Trough',
      category: ItemCategory.equipment,
      asset: 'assets/app/images/water_trough.png',
      width: 88,
      description: 'Anchors a water zone.',
    ),
    CatalogItem(
      id: 'fence',
      name: 'Fence Panel',
      category: ItemCategory.equipment,
      asset: 'assets/app/images/fence.png',
      width: 96,
      description: 'Separates one part of the pasture from another.',
    ),
    CatalogItem(
      id: 'basket',
      name: 'Collection Basket',
      category: ItemCategory.equipment,
      asset: 'assets/app/images/basket.png',
      width: 70,
      unlockAt: 20,
      description: 'Marks where collected eggs are gathered.',
    ),
    CatalogItem(
      id: 'signpost',
      name: 'Signpost',
      category: ItemCategory.equipment,
      asset: 'assets/app/images/signpost.png',
      width: 62,
      unlockAt: 35,
      description: 'A landmark that helps you read the layout faster.',
    ),
    CatalogItem(
      id: 'grass_tuft',
      name: 'Grass Tuft',
      category: ItemCategory.decor,
      asset: 'assets/app/images/grass_tuft.png',
      width: 56,
    ),
    CatalogItem(
      id: 'flower',
      name: 'Flower',
      category: ItemCategory.decor,
      asset: 'assets/app/images/flower.png',
      width: 40,
      unlockAt: 25,
    ),
    CatalogItem(
      id: 'bush',
      name: 'Bush',
      category: ItemCategory.decor,
      asset: 'assets/app/images/bush.png',
      width: 76,
      unlockAt: 40,
    ),
    CatalogItem(
      id: 'rock',
      name: 'Field Rock',
      category: ItemCategory.decor,
      asset: 'assets/app/images/rock.png',
      width: 62,
      unlockAt: 55,
    ),
    CatalogItem(
      id: 'hay_bale',
      name: 'Hay Bale',
      category: ItemCategory.decor,
      asset: 'assets/app/images/hay_bale.png',
      width: 84,
      unlockAt: 70,
    ),
    CatalogItem(
      id: 'wildflowers',
      name: 'Wildflowers',
      category: ItemCategory.decor,
      asset: 'assets/app/images/wildflowers.png',
      width: 76,
      unlockAt: 95,
    ),
    CatalogItem(
      id: 'cloud',
      name: 'Soft Cloud',
      category: ItemCategory.decor,
      asset: 'assets/app/images/cloud.png',
      width: 104,
      unlockAt: 130,
    ),
    CatalogItem(
      id: 'sun',
      name: 'Sun Marker',
      category: ItemCategory.decor,
      asset: 'assets/app/images/sun.png',
      width: 86,
      unlockAt: 170,
    ),
  ];

  static const themes = <PastureTheme>[
    PastureTheme(
      id: 'green_meadow',
      name: 'Green Meadow',
      asset: 'assets/app/backgrounds/pasture_green_meadow.webp',
      unlockAt: 0,
    ),
    PastureTheme(
      id: 'sunny_field',
      name: 'Sunny Field',
      asset: 'assets/app/backgrounds/pasture_sunny_field.webp',
      unlockAt: 120,
    ),
    PastureTheme(
      id: 'flower_meadow',
      name: 'Flower Meadow',
      asset: 'assets/app/backgrounds/pasture_flower_meadow.webp',
      unlockAt: 260,
    ),
  ];

  static CatalogItem byId(String id) =>
      items.firstWhere((item) => item.id == id, orElse: () => items.first);

  static PastureTheme themeById(String id) =>
      themes.firstWhere((theme) => theme.id == id, orElse: () => themes.first);

  static List<CatalogItem> byCategory(ItemCategory category) =>
      items.where((item) => item.category == category).toList(growable: false);

  static List<String> get allImageAssets => <String>[
        ...items.map((item) => item.asset),
        ...themes.map((theme) => theme.asset),
      ];
}

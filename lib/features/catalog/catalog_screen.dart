import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/catalog.dart';
import '../pasture/pasture_board.dart';
import '../pasture/pasture_controller.dart';
import '../pasture/placement.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  ItemCategory _category = ItemCategory.chicken;

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(unlockedItemIdsProvider);
    final points = ref.watch(carePointsProvider).value ?? 0;
    final snapshot = ref.watch(pastureControllerProvider).value;
    final items = Catalog.byCategory(_category);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Objects',
            subtitle: 'Pick an item, then tap its spot on the pasture',
            onBack: () => Navigator.of(context).pop(),
            trailing: _PointsBadge(points: points),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 0),
            child: SegmentedPills<ItemCategory>(
              values: ItemCategory.values,
              labelOf: (value) => value.label,
              selected: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppGap.md,
                mainAxisSpacing: AppGap.md,
                childAspectRatio: 0.86,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isUnlocked = unlocked.contains(item.id);
                final placed = snapshot?.objects
                        .where((object) => object.catalogId == item.id)
                        .length ??
                    0;
                return _CatalogTile(
                  item: item,
                  unlocked: isUnlocked,
                  placedCount: placed,
                  pointsToGo: item.unlockAt - points,
                  onTap: isUnlocked
                      ? () {
                          ref.read(pendingPlacementProvider.notifier).state =
                              PlaceCatalogItem(item);
                          Navigator.of(context).pop();
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.item,
    required this.unlocked,
    required this.placedCount,
    required this.pointsToGo,
    required this.onTap,
  });

  final CatalogItem item;
  final bool unlocked;
  final int placedCount;
  final int pointsToGo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      border: Border.all(
        color: unlocked ? AppColors.line : AppColors.line.withValues(alpha: 0.6),
      ),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: unlocked ? 1 : 0.34,
              child: Center(
                child: Image.asset(
                  item.asset,
                  fit: BoxFit.contain,
                  cacheWidth:
                      (140 * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppGap.sm),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 4),
          if (!unlocked)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$pointsToGo more Care Points',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ),
              ],
            )
          else
            Text(
              placedCount == 0
                  ? 'Not placed yet'
                  : '$placedCount on the pasture',
              style: AppText.caption.copyWith(
                color: placedCount == 0 ? AppColors.inkFaint : AppColors.meadow,
                fontWeight: placedCount == 0 ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ItemThumb(
            asset: 'assets/app/images/point_badge.png',
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '$points',
            style: AppText.bodyStrong.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

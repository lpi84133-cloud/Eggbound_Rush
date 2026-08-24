import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/catalog.dart';

class CustomizationScreen extends ConsumerWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final points = ref.watch(carePointsProvider).value ?? 0;
    final unlockedThemes = ref.watch(unlockedThemeIdsProvider);
    final unlockedItems = ref.watch(unlockedItemIdsProvider);

    final locked = [
      ...Catalog.items.where((item) => !unlockedItems.contains(item.id)).map(
            (item) => (item.name, item.unlockAt),
          ),
      ...Catalog.themes.where((theme) => !unlockedThemes.contains(theme.id)).map(
            (theme) => (theme.name, theme.unlockAt),
          ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Customization',
            subtitle: 'Change how your pasture looks',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
              children: [
                if (locked.isNotEmpty)
                  _NextUnlockCard(
                    name: locked.first.$1,
                    threshold: locked.first.$2,
                    points: points,
                  )
                else
                  const SoftCard(
                    child: Row(
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.meadow),
                        SizedBox(width: AppGap.md),
                        Expanded(
                          child: Text(
                            'Everything is unlocked. Keep using the pasture — '
                            'your statistics keep tracking regardless.',
                            style: AppText.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SectionTitle('Pasture theme'),
                for (final theme in Catalog.themes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppGap.md),
                    child: _ThemeCard(
                      theme: theme,
                      selected: theme.id == settings.themeId,
                      unlocked: unlockedThemes.contains(theme.id),
                      points: points,
                      onSelect: () => ref
                          .read(settingsControllerProvider.notifier)
                          .setTheme(theme.id),
                    ),
                  ),
                const SectionTitle('Decorative objects'),
                Text(
                  'Unlocked decor becomes available in the Objects list and can '
                  'be placed anywhere on the board.',
                  style: AppText.body,
                ),
                const SizedBox(height: AppGap.md),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisSpacing: AppGap.sm,
                  mainAxisSpacing: AppGap.sm,
                  childAspectRatio: 0.82,
                  children: [
                    for (final item
                        in Catalog.byCategory(ItemCategory.decor))
                      _DecorTile(
                        item: item,
                        unlocked: unlockedItems.contains(item.id),
                      ),
                  ],
                ),
                const SizedBox(height: AppGap.md),
                const InfoNote(
                  'Nothing here can be purchased. Items become available as '
                  'your Care Points grow from using the app.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextUnlockCard extends StatelessWidget {
  const _NextUnlockCard({
    required this.name,
    required this.threshold,
    required this.points,
  });

  final String name;
  final int threshold;
  final int points;

  @override
  Widget build(BuildContext context) {
    final ratio = threshold == 0 ? 1.0 : (points / threshold).clamp(0.0, 1.0);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: AppColors.amber),
              const SizedBox(width: AppGap.sm),
              Expanded(child: Text('Next unlock: $name', style: AppText.section)),
            ],
          ),
          const SizedBox(height: AppGap.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: AppGap.sm),
          Text('$points of $threshold Care Points', style: AppText.caption),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.points,
    required this.onSelect,
  });

  final PastureTheme theme;
  final bool selected;
  final bool unlocked;
  final int points;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: unlocked ? onSelect : null,
      border: Border.all(
        color: selected ? AppColors.meadow : AppColors.line,
        width: selected ? 2.5 : 1,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brMedium,
        child: Stack(
          children: [
            SizedBox(
              height: 132,
              width: double.infinity,
              child: Opacity(
                opacity: unlocked ? 1 : 0.4,
                child: Image.asset(
                  theme.asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.barkDeep.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.name,
                        style: AppText.section.copyWith(color: Colors.white),
                      ),
                    ),
                    if (!unlocked)
                      Text(
                        '${theme.unlockAt - points} points to go',
                        style: AppText.caption.copyWith(color: Colors.white),
                      )
                    else if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 22)
                    else
                      Text(
                        'Tap to use',
                        style: AppText.caption.copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorTile extends StatelessWidget {
  const _DecorTile({required this.item, required this.unlocked});

  final CatalogItem item;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: unlocked ? 1 : 0.3,
              child: Image.asset(
                item.asset,
                fit: BoxFit.contain,
                cacheWidth:
                    (120 * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            unlocked ? 'Available' : 'at ${item.unlockAt}',
            style: AppText.caption.copyWith(
              color: unlocked ? AppColors.meadow : AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

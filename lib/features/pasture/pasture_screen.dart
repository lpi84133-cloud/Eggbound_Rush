import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../boot/boot_controller.dart';
import 'pasture_board.dart';
import 'pasture_controller.dart';
import 'placement.dart';

class PastureScreen extends ConsumerWidget {
  const PastureScreen({super.key, required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(pastureControllerProvider);
    // select() means a sound/haptics toggle in Settings does NOT rebuild the
    // board — only a theme or zone-visibility change does.
    final themeId = ref.watch(
      settingsControllerProvider.select((s) => s.themeId),
    );
    final showZones = ref.watch(
      settingsControllerProvider.select((s) => s.showZones),
    );
    final pending = ref.watch(pendingPlacementProvider);
    final backgroundAsset = Catalog.themeById(themeId).asset;

    return Scaffold(
      backgroundColor: AppColors.grass,
      body: snapshotAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, _) => _BoardError(error: error, ref: ref),
        data: (snapshot) => Stack(
          fit: StackFit.expand,
          children: [
            PastureBoard(
              snapshot: snapshot,
              backgroundAsset: backgroundAsset,
              showZones: showZones,
              onTapEmpty: (x, y) => _handleBoardTap(context, ref, x, y),
              onTapObject: (object) => _showObjectSheet(context, ref, object),
              onTapEgg: (egg) => _showEggSheet(context, ref, egg),
              onMoveObject: (object, x, y) => ref
                  .read(pastureControllerProvider.notifier)
                  .moveObject(object, x, y),
              onMoveEgg: (egg, x, y) =>
                  ref.read(pastureControllerProvider.notifier).moveEgg(egg, x, y),
            ),
            // Chrome over the board is isolated so its rebuilds never dirty
            // the board's raster layer.
            RepaintBoundary(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      const _BoardBar(),
                      if (pending != null) ...[
                        const SizedBox(height: AppGap.sm),
                        _PlacementBanner(pending: pending),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 22 + MediaQuery.paddingOf(context).bottom,
              child: RepaintBoundary(
                child: _QuickMarkButton(onOpenCatalog: onOpenCatalog),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBoardTap(
    BuildContext context,
    WidgetRef ref,
    double x,
    double y,
  ) {
    final pending = ref.read(pendingPlacementProvider);
    final controller = ref.read(pastureControllerProvider.notifier);

    switch (pending) {
      case PlaceCatalogItem(:final item):
        ref.read(pendingPlacementProvider.notifier).state = null;
        controller.placeItem(item, x, y);
        _toast(context, '${item.name} placed');
      case PlaceEggMark(:final type):
        ref.read(pendingPlacementProvider.notifier).state = null;
        controller.markEgg(type, x, y);
        _toast(context, '${type.label} marked');
      case null:
        _showQuickAddSheet(context, ref, x, y);
    }
  }

  void _showQuickAddSheet(
    BuildContext context,
    WidgetRef ref,
    double x,
    double y,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetShell(
        title: 'Add something here',
        subtitle: 'This spot is empty. Mark an egg you found, or browse the '
            'full object list.',
        children: [
          Row(
            children: [
              for (final type in EggType.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SoftCard(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ref
                            .read(pastureControllerProvider.notifier)
                            .markEgg(type, x, y);
                        _toast(context, '${type.label} marked');
                      },
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          ItemThumb(asset: type.asset, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            type.label.replaceAll(' egg', ''),
                            style: AppText.label,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppGap.md),
          PillButton(
            label: 'Open object list',
            icon: Icons.grid_view_rounded,
            tone: PillTone.quiet,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onOpenCatalog();
            },
          ),
        ],
      ),
    );
  }

  void _showObjectSheet(
    BuildContext context,
    WidgetRef ref,
    PastureObject object,
  ) {
    final item = object.item;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetShell(
        title: item.name,
        subtitle: item.description.isEmpty
            ? '${item.category.label} placed on your pasture.'
            : item.description,
        leading: ItemThumb(asset: item.asset, size: 58),
        children: [
          _ZoneOfObject(object: object),
          const SizedBox(height: AppGap.md),
          const InfoNote(
            'Drag the object directly on the pasture to move it to another '
            'spot or zone.',
            icon: Icons.pan_tool_alt_outlined,
          ),
          const SizedBox(height: AppGap.md),
          PillButton(
            label: 'Remove from pasture',
            icon: Icons.delete_outline_rounded,
            tone: PillTone.danger,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              ref
                  .read(pastureControllerProvider.notifier)
                  .removeObject(object);
              _toast(context, '${item.name} removed');
            },
          ),
        ],
      ),
    );
  }

  void _showEggSheet(BuildContext context, WidgetRef ref, EggMark egg) {
    final marked = DateFormat('MMM d, HH:mm').format(egg.markedAt);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetShell(
        title: egg.type.label,
        subtitle: 'Marked $marked',
        leading: ItemThumb(asset: egg.type.asset, size: 52),
        children: [
          PillButton(
            label: 'Log as collected',
            icon: Icons.check_circle_outline_rounded,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              ref.read(pastureControllerProvider.notifier).collectEgg(egg);
              _showUndoBar(context, ref, egg);
            },
          ),
          const SizedBox(height: AppGap.sm),
          PillButton(
            label: 'Remove mark',
            icon: Icons.close_rounded,
            tone: PillTone.quiet,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              ref.read(pastureControllerProvider.notifier).removeEgg(egg);
            },
          ),
          const SizedBox(height: AppGap.md),
          const InfoNote(
            'Collected eggs leave the board and are counted in Statistics and '
            'History.',
          ),
        ],
      ),
    );
  }

  void _showUndoBar(BuildContext context, WidgetRef ref, EggMark egg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${egg.type.label} logged as collected'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.goldSoft,
          onPressed: () =>
              ref.read(pastureControllerProvider.notifier).undoCollect(egg.id),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

/// Floating header for the board. It states what the screen is and how many
/// eggs are currently marked but not yet logged — the only number that
/// changes anything here.
class _BoardBar extends ConsumerWidget {
  const _BoardBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingEggs =
        ref.watch(pastureControllerProvider).value?.pendingEggs.length ?? 0;
    final showZones = ref.watch(
      settingsControllerProvider.select((s) => s.showZones),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: AppRadius.brMedium,
        boxShadow: AppShadow.floating,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            _BarIcon(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: AppGap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Coop layout', style: AppText.section),
                Text(
                  pendingEggs == 0
                      ? 'Map your run and mark where eggs turn up'
                      : '$pendingEggs marked, not yet logged',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          _BarIcon(
            icon: showZones
                ? Icons.layers_rounded
                : Icons.layers_clear_outlined,
            tone: showZones ? AppColors.accentDeep : AppColors.inkFaint,
            onTap: () => ref
                .read(settingsControllerProvider.notifier)
                .setShowZones(!showZones),
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.onTap,
    this.tone = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: tone),
        ),
      ),
    );
  }
}

class _PlacementBanner extends ConsumerWidget {
  const _PlacementBanner({required this.pending});

  final PendingPlacement pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: AppColors.barkDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending.prompt,
              style: AppText.bodyStrong.copyWith(color: AppColors.barkDeep),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(pendingPlacementProvider.notifier).state = null,
            child: Text(
              'Cancel',
              style: AppText.label.copyWith(
                color: AppColors.barkDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMarkButton extends ConsumerWidget {
  const _QuickMarkButton({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(26),
      elevation: 8,
      shadowColor: const Color(0x553E5B2C),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          ref.read(servicesProvider).feedback.tapFeedback();
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (sheetContext) => _SheetShell(
              title: 'Mark an egg',
              subtitle:
                  'Choose a type, then tap the exact spot on the pasture where '
                  'you found it.',
              children: [
                for (final type in EggType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppGap.sm),
                    child: SoftCard(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ref.read(pendingPlacementProvider.notifier).state =
                            PlaceEggMark(type);
                      },
                      child: Row(
                        children: [
                          ItemThumb(asset: type.asset, size: 38),
                          const SizedBox(width: AppGap.md),
                          Expanded(
                            child: Text(type.label, style: AppText.bodyStrong),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.inkFaint),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppGap.xs),
                PillButton(
                  label: 'Place an object instead',
                  icon: Icons.grid_view_rounded,
                  tone: PillTone.quiet,
                  expand: true,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onOpenCatalog();
                  },
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemThumb(asset: 'assets/app/images/egg_white.png', size: 22),
              SizedBox(width: 9),
              Text('Mark egg', style: AppText.button),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneOfObject extends ConsumerWidget {
  const _ZoneOfObject({required this.object});

  final PastureObject object;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pastureControllerProvider).value;
    final zone = snapshot?.zones
        .cast<PastureZone?>()
        .firstWhere(
          (candidate) => candidate!.contains(object.x, object.y),
          orElse: () => null,
        );

    return Row(
      children: [
        Icon(
          zone == null ? Icons.crop_free_rounded : Icons.place_rounded,
          size: 18,
          color: zone == null ? AppColors.inkFaint : Color(zone.kind.color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            zone == null
                ? 'Outside every zone'
                : 'In zone "${zone.name}" · ${zone.kind.label}',
            style: AppText.label,
          ),
        ),
      ],
    );
  }
}

/// Thin wrapper over the shared sheet so the board's sheets are identical to
/// the ones in the flock and feed sections, with room for a thumbnail of the
/// object being discussed.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: title,
      subtitle: subtitle,
      children: [
        if (leading != null) ...[
          Center(child: leading!),
          const SizedBox(height: AppGap.lg),
        ],
        ...children,
        const SizedBox(height: AppGap.md),
      ],
    );
  }
}

class _BoardError extends StatelessWidget {
  const _BoardError({required this.error, required this.ref});

  final Object error;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyHint(
          icon: Icons.refresh_rounded,
          title: 'The pasture could not be read',
          message: 'Your data is still on the device. Try loading it again.',
          action: PillButton(
            label: 'Retry',
            onPressed: () => ref.invalidate(pastureControllerProvider),
          ),
        ),
      ),
    );
  }
}

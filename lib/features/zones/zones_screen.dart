import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../pasture/pasture_controller.dart';
import 'zone_editor.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(zoneContentsProvider);
    final unzoned = ref.watch(unzonedObjectCountProvider);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Pasture Zones',
            subtitle: 'Group the board into areas with a clear purpose',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
              children: [
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Show zones on the pasture',
                                style: AppText.bodyStrong),
                            const SizedBox(height: 2),
                            Text(
                              'Turn off for a clean view of the objects only.',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.showZones,
                        onChanged: (value) => ref
                            .read(settingsControllerProvider.notifier)
                            .setShowZones(value),
                      ),
                    ],
                  ),
                ),
                if (unzoned > 0) ...[
                  const SizedBox(height: AppGap.md),
                  InfoNote(
                    '$unzoned object${unzoned == 1 ? '' : 's'} sit outside '
                    'every zone. Drag them onto a zone, or resize a zone to '
                    'cover them.',
                    icon: Icons.report_gmailerrorred_rounded,
                  ),
                ],
                if (contents.isEmpty) ...[
                  const SizedBox(height: AppGap.lg),
                  EmptyHint(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'No zones yet',
                    message:
                        'Zones let you read the pasture at a glance: nesting '
                        'here, feeding there. Create your first one.',
                    action: PillButton(
                      label: 'Create a zone',
                      icon: Icons.add_rounded,
                      onPressed: () => _createZone(context, ref),
                    ),
                  ),
                ] else ...[
                  const SectionTitle('Your zones'),
                  for (final entry in contents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppGap.md),
                      child: _ZoneCard(
                        contents: entry,
                        onEdit: () => _editZone(context, ref, entry.zone),
                      ),
                    ),
                  const SizedBox(height: AppGap.sm),
                  PillButton(
                    label: 'Add another zone',
                    icon: Icons.add_rounded,
                    tone: PillTone.quiet,
                    expand: true,
                    onPressed: () => _createZone(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createZone(BuildContext context, WidgetRef ref) async {
    final draft = await showZoneEditor(
      context,
      initial: const ZoneDraft(
        name: 'New Zone',
        kind: ZoneKind.nesting,
        cx: 0.5,
        cy: 0.45,
        w: 0.4,
        h: 0.24,
      ),
      themeAsset: Catalog.themeById(
        ref.read(settingsControllerProvider).themeId,
      ).asset,
    );
    if (draft == null) return;
    await ref.read(pastureControllerProvider.notifier).addZone(
          PastureZone(
            id: 0,
            name: draft.name,
            kind: draft.kind,
            cx: draft.cx,
            cy: draft.cy,
            w: draft.w,
            h: draft.h,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _editZone(
    BuildContext context,
    WidgetRef ref,
    PastureZone zone,
  ) async {
    final result = await showZoneEditor(
      context,
      initial: ZoneDraft(
        name: zone.name,
        kind: zone.kind,
        cx: zone.cx,
        cy: zone.cy,
        w: zone.w,
        h: zone.h,
      ),
      themeAsset: Catalog.themeById(
        ref.read(settingsControllerProvider).themeId,
      ).asset,
      allowDelete: true,
    );
    if (result == null) return;

    final controller = ref.read(pastureControllerProvider.notifier);
    if (result.deleted) {
      await controller.removeZone(zone);
      return;
    }
    await controller.updateZone(
      zone.copyWith(
        name: result.name,
        kind: result.kind,
        cx: result.cx,
        cy: result.cy,
        w: result.w,
        h: result.h,
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.contents, required this.onEdit});

  final ZoneContents contents;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final zone = contents.zone;
    final color = Color(zone.kind.color);

    return SoftCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: AppRadius.brSmall,
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(_iconFor(zone.kind), color: color, size: 21),
              ),
              const SizedBox(width: AppGap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.name, style: AppText.section),
                    Text(zone.kind.hint, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.tune_rounded, color: AppColors.inkFaint),
            ],
          ),
          const SizedBox(height: AppGap.md),
          Wrap(
            spacing: AppGap.sm,
            runSpacing: AppGap.sm,
            children: [
              _Chip(
                label: '${contents.chickens} hen'
                    '${contents.chickens == 1 ? '' : 's'}',
              ),
              _Chip(
                label: '${contents.nests} nest'
                    '${contents.nests == 1 ? '' : 's'}',
              ),
              _Chip(
                label: '${contents.eggs.length} egg'
                    '${contents.eggs.length == 1 ? '' : 's'} waiting',
                highlighted: contents.eggs.isNotEmpty,
              ),
              _Chip(label: '${contents.objects.length} objects total'),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(ZoneKind kind) => switch (kind) {
        ZoneKind.nesting => Icons.egg_outlined,
        ZoneKind.feeding => Icons.grass_rounded,
        ZoneKind.water => Icons.water_drop_outlined,
        ZoneKind.free => Icons.landscape_rounded,
        ZoneKind.collection => Icons.shopping_basket_outlined,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.goldSoft : AppColors.shell,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: AppColors.barkDeep,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

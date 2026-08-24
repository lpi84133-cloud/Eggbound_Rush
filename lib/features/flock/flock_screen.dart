import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/art.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/flock_repository.dart';
import '../../domain/flock.dart';
import 'flock_providers.dart';
import 'hen_detail_screen.dart';
import 'hen_editor_screen.dart';

/// The register of birds. Every card answers "is this hen still producing?"
/// because that is the question that makes a keeper open the app.
class FlockScreen extends ConsumerWidget {
  const FlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productionAsync = ref.watch(henProductionProvider);
    final window = ref.watch(productionWindowProvider);

    return Scaffold(
      body: Column(
        children: [
          RibbonHeader(
            title: 'My flock',
            subtitle: 'A record for every bird you keep',
            mascot: Art.henPecking,
            onBack: Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
            trailing: HeaderIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Add a hen',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HenEditorScreen(),
                ),
              ),
            ),
          ),
          Expanded(
            child: productionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not read your flock.\n$error',
                      style: AppText.body, textAlign: TextAlign.center),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? const _EmptyFlock()
                  : _FlockList(entries: entries, windowDays: window),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlockList extends ConsumerWidget {
  const _FlockList({required this.entries, required this.windowDays});

  final List<HenProduction> entries;
  final int windowDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attention = entries.where((e) => e.needsAttention).length;
    final laying =
        entries.where((e) => e.hen.status == HenStatus.laying).length;
    final total = entries.fold<int>(0, (sum, e) => sum + e.eggsInWindow);
    final peak = entries.fold<int>(1, (m, e) => e.eggsInWindow > m ? e.eggsInWindow : m);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final cards = [
          for (final entry in entries)
            _HenCard(entry: entry, windowDays: windowDays, peak: peak),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppGap.page, AppGap.md + 2, AppGap.page, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: ArtTile(
                    art: Art.hen,
                    value: '${entries.length}',
                    label: 'birds in the flock',
                    tone: AppColors.forest,
                  ),
                ),
                const SizedBox(width: AppGap.sm + 2),
                Expanded(
                  child: ArtTile(
                    art: Art.egg,
                    value: '$total',
                    label: 'eggs in $windowDays days',
                    tone: AppColors.goldDeep,
                  ),
                ),
                const SizedBox(width: AppGap.sm + 2),
                Expanded(
                  child: ArtTile(
                    art: Art.nest,
                    value: '$laying',
                    label: 'currently laying',
                    tone: AppColors.rampLow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppGap.md),
            SegmentedPills<int>(
              values: const [7, 30, 90],
              labelOf: (days) => '$days days',
              selected: windowDays,
              onChanged: (value) =>
                  ref.read(productionWindowProvider.notifier).state = value,
            ),
            if (attention > 0) ...[
              const SizedBox(height: AppGap.md),
              InfoNote(
                '$attention ${attention == 1 ? 'hen has' : 'hens have'} not '
                'laid for a week or more. Check for moulting, broodiness or '
                'illness.',
                icon: Icons.error_outline_rounded,
                tone: InfoTone.warning,
              ),
            ],
            const SizedBox(height: AppGap.md + 2),
            if (columns == 1)
              for (final card in cards) ...[
                card,
                const SizedBox(height: AppGap.sm + 2),
              ]
            else
              for (var i = 0; i < cards.length; i += 2) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[i]),
                    const SizedBox(width: AppGap.md),
                    Expanded(
                      child: i + 1 < cards.length
                          ? cards[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: AppGap.md),
              ],
            const MeadowFooter(),
          ],
        );
      },
    );
  }
}

/// A hen's summary card: who she is, how she is doing, and a bar putting her
/// output in the context of the best bird in the flock.
class _HenCard extends StatelessWidget {
  const _HenCard({
    required this.entry,
    required this.windowDays,
    required this.peak,
  });

  final HenProduction entry;
  final int windowDays;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final hen = entry.hen;
    final days = entry.daysSinceLastEgg;
    final attention = entry.needsAttention;
    final ratio = peak == 0 ? 0.0 : entry.eggsInWindow / peak;

    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HenDetailScreen(henId: hen.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HenAvatar(hen: hen, size: 52),
                const SizedBox(width: AppGap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hen.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.section,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (hen.breed != null && hen.breed!.isNotEmpty)
                            hen.breed!,
                          hen.ageLabel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      const SizedBox(height: AppGap.sm),
                      StatusChip(status: hen.status),
                    ],
                  ),
                ),
                const SizedBox(width: AppGap.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Sprite(Art.egg, size: 22),
                        const SizedBox(width: 4),
                        Text('${entry.eggsInWindow}', style: AppText.metric),
                      ],
                    ),
                    Text('in $windowDays days', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          // A tinted strip carries the performance read-out, so the card has
          // a clear top half about the bird and a bottom half about output.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
            decoration: BoxDecoration(
              color: attention ? AppColors.warnSoft : AppColors.accentSoft,
              borderRadius: const BorderRadius.vertical(
                bottom: AppRadius.medium,
              ),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        ColoredBox(
                          color: Colors.white.withValues(alpha: 0.7),
                          child: const SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: attention
                                  ? AppColors.rampHigh
                                  : AppColors.rampLow,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppGap.sm),
                Row(
                  children: [
                    Icon(
                      attention
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: attention ? AppColors.warn : AppColors.accentInk,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        days == null
                            ? 'No eggs recorded yet'
                            : days == 0
                                ? 'Laid today'
                                : days == 1
                                    ? 'Last egg yesterday'
                                    : 'Last egg $days days ago',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color:
                              attention ? AppColors.warn : AppColors.accentInk,
                          fontWeight:
                              attention ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.ratePerWeek(windowDays).toStringAsFixed(1)}'
                      ' / week',
                      style: AppText.caption.copyWith(
                        color: attention ? AppColors.warn : AppColors.accentInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round portrait for a bird: her photo when one exists, otherwise a swatch
/// of the egg colour she lays, which is how keepers tell birds apart.
class HenAvatar extends StatelessWidget {
  const HenAvatar({super.key, required this.hen, this.size = 44});

  final Hen hen;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = hen.photoPath;
    final initial = hen.name.trim().isEmpty
        ? '?'
        : hen.name.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(hen.eggColor.swatch),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lineStrong, width: 1.5),
      ),
      child: path != null && File(path).existsSync()
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
            )
          : Center(
              child: Text(
                initial,
                style: AppText.section.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.5),
                  fontSize: size * 0.4,
                ),
              ),
            ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final HenStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      HenStatus.laying => AppColors.rampLow,
      HenStatus.molting => AppColors.rampHigh,
      HenStatus.broody => AppColors.info,
      HenStatus.notLaying => AppColors.rampPeak,
      HenStatus.retired => AppColors.inkFaint,
    };
    return ToneBadge(label: status.label, tone: tone, dot: true);
  }
}

class _EmptyFlock extends StatelessWidget {
  const _EmptyFlock();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppGap.page, AppGap.xl, AppGap.page, AppGap.xl),
      children: [
        EmptyHint(
          icon: Icons.pets_outlined,
          art: Art.henNesting,
          title: 'Add your first hen',
          message: 'Eggbound Rush keeps a record for each bird you own: how '
              'many eggs she lays, when she last laid, her age, breed and '
              'health treatments.',
          action: PillButton(
            label: 'Add a hen',
            icon: Icons.add_rounded,
            tone: PillTone.accent,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HenEditorScreen(),
              ),
            ),
          ),
        ),
        const MeadowFooter(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/art.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/flock_repository.dart';
import '../../domain/flock.dart';
import '../flock/flock_providers.dart';
import '../flock/flock_screen.dart';
import '../flock/hen_detail_screen.dart';
import '../flock/hen_editor_screen.dart';
import '../flock/log_eggs_sheet.dart';
import '../flock/log_health_sheet.dart';

/// The daily working view: what came in today, how the week is shaping up,
/// what needs doing, and one tap to record any of it.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(flockSummaryProvider);

    return Scaffold(
      body: Column(
        children: [
          RibbonHeader(
            title: 'Eggbound Rush',
            subtitle: _todayLabel(),
            mascot: Art.henNesting,
          ),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$error', style: AppText.body),
                ),
              ),
              data: (summary) => summary.activeHens == 0
                  ? const _FirstRun()
                  : _Dashboard(summary: summary),
            ),
          ),
        ],
      ),
    );
  }
}

String _todayLabel() {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  final now = DateTime.now();
  return '${days[now.weekday - 1]}, ${formatDate(now)}';
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.summary});

  final FlockSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final careAsync = ref.watch(upcomingCareProvider);
    final productionAsync = ref.watch(henProductionProvider);
    final seriesAsync = ref.watch(dailySeriesProvider(14));
    final costsAsync = ref.watch(feedCostsProvider);

    final production = productionAsync.valueOrNull ?? const <HenProduction>[];
    final attention = production.where((e) => e.needsAttention).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppGap.page, AppGap.md + 2, AppGap.page, 120),
          children: [
            _TodayCard(summary: summary, wide: wide),

            const SizedBox(height: AppGap.md),
            _ActionRow(wide: wide),

            const SectionTitle(
              'Flock condition',
              subtitle: 'How the birds are performing right now',
            ),
            _ConditionCard(summary: summary, production: production),

            const SectionTitle('Last 14 days'),
            seriesAsync.when(
              loading: () => const _CardLoading(),
              error: (error, _) => Text('$error', style: AppText.caption),
              data: (series) => _TrendCard(series: series, summary: summary),
            ),

            const SectionTitle(
              'Top layers',
              subtitle: 'Ranked by eggs collected over the last 30 days',
            ),
            productionAsync.when(
              loading: () => const _CardLoading(),
              error: (error, _) => Text('$error', style: AppText.caption),
              data: (entries) => _TopLayers(entries: entries),
            ),

            if (attention.isNotEmpty) ...[
              SectionTitle(
                'Worth checking',
                subtitle: '${attention.length} '
                    '${attention.length == 1 ? 'bird has' : 'birds have'} gone '
                    'quiet for a week or more',
              ),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final entry in attention.take(5))
                      _AttentionRow(entry: entry),
                  ],
                ),
              ),
            ],

            const SectionTitle('Care schedule'),
            careAsync.when(
              loading: () => const _CardLoading(),
              error: (error, _) => Text('$error', style: AppText.caption),
              data: (events) => events.isEmpty
                  ? const InfoNote(
                      'Nothing due in the next two weeks. Log a worming or '
                      'mite treatment and the next date lands here.',
                      icon: Icons.check_circle_outline_rounded,
                      tone: InfoTone.positive,
                    )
                  : SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final event in events) _CareRow(event: event),
                        ],
                      ),
                    ),
            ),

            costsAsync.maybeWhen(
              data: (costs) => costs.costPerEgg == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const SectionTitle('Running costs'),
                        _CostStrip(costs: costs),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),

            const MeadowFooter(
              message: 'Everything above is worked out from your own records, '
                  'stored on this device.',
            ),
          ],
        );
      },
    );
  }
}

/// Today's collection, shown as the actual eggs. The number matters, but a
/// row of eggs is what makes the screen feel like it is about a real coop.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.summary, required this.wide});

  final FlockSummary summary;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: AppRadius.brMedium,
        boxShadow: AppShadow.accent,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'COLLECTED TODAY',
                        style: AppText.overline.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${summary.eggsToday}',
                            style: AppText.hero.copyWith(color: Colors.white),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            summary.eggsToday == 1 ? 'egg' : 'eggs',
                            style: AppText.section.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${summary.layingHens} of ${summary.activeHens} hens '
                        'are laying',
                        style: AppText.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Sprite(Art.basket, size: 86),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.vertical(
                bottom: AppRadius.medium,
              ),
            ),
            child: EggGrid(count: summary.eggsToday, eggSize: 26),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PillButton(
            label: 'Log eggs',
            icon: Icons.add_rounded,
            tone: PillTone.accent,
            expand: true,
            onPressed: () => showLogEggsSheet(context),
          ),
        ),
        const SizedBox(width: AppGap.sm + 2),
        Expanded(
          child: PillButton(
            label: 'Log care',
            icon: Icons.medical_services_outlined,
            tone: PillTone.quiet,
            expand: true,
            onPressed: () => showLogHealthSheet(context),
          ),
        ),
      ],
    );
  }
}

/// Lay rate as a gauge on the ramp, with the flock's make-up beside it. The
/// gauge answers "is this good?", which a bare percentage never does.
class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.summary, required this.production});

  final FlockSummary summary;
  final List<HenProduction> production;

  @override
  Widget build(BuildContext context) {
    final rate = summary.weeklyLayRate;
    final (verdict, tone) = switch (rate) {
      >= 0.75 => ('Strong', AppColors.rampLow),
      >= 0.5 => ('Steady', AppColors.rampMid),
      >= 0.25 => ('Slow', AppColors.rampHigh),
      _ => ('Very low', AppColors.rampPeak),
    };

    final byStatus = <HenStatus, int>{};
    for (final entry in production) {
      byStatus.update(entry.hen.status, (v) => v + 1, ifAbsent: () => 1);
    }

    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              ArcGauge(
                value: rate,
                label: '${(rate * 100).round()}%',
                caption: 'LAY RATE',
                size: 132,
              ),
              const SizedBox(width: AppGap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToneBadge(label: verdict, tone: tone),
                    const SizedBox(height: AppGap.sm),
                    Text(
                      rate >= 0.75
                          ? 'Your flock is laying close to its natural '
                              'maximum for this time of year.'
                          : rate >= 0.5
                              ? 'A normal rate. Shorter days and moulting '
                                  'pull this down without anything being '
                                  'wrong.'
                              : 'Well below what these birds can do. Check '
                                  'for moulting, mites, broodiness or a '
                                  'change in feed.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppGap.lg + 8),
          for (final status in HenStatus.values)
            if ((byStatus[status] ?? 0) > 0)
              BreakdownRow(
                label: status.label,
                value: '${byStatus[status]}',
                share:
                    '${((byStatus[status]! / production.length) * 100).round()}%',
                fraction: byStatus[status]! / production.length,
                tone: switch (status) {
                  HenStatus.laying => AppColors.rampLow,
                  HenStatus.molting => AppColors.rampHigh,
                  HenStatus.broody => AppColors.info,
                  HenStatus.notLaying => AppColors.rampPeak,
                  HenStatus.retired => AppColors.inkFaint,
                },
              ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series, required this.summary});

  final List<({DateTime day, int count})> series;
  final FlockSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = series.fold<int>(0, (sum, point) => sum + point.count);
    final best = series.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final blanks = series.where((point) => point.count == 0).length;
    final change = summary.weekChangePercent;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  const Sprite(Art.nest, size: 54),
                  const SizedBox(width: AppGap.md),
                  Expanded(
                    child: Text(
                      'No eggs logged in the last fortnight. Tap "Log eggs" '
                      'after your next collection and the trend starts here.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            RidgeChart(
              values: [for (final point in series) point.count],
              labels: [
                formatShortDate(series.first.day),
                formatShortDate(series[series.length ~/ 2].day),
                formatShortDate(series.last.day),
              ],
            ),
            const SizedBox(height: AppGap.md),
            Row(
              children: [
                _Chip(
                  art: Art.egg,
                  value: '$total',
                  label: 'collected',
                ),
                _Chip(
                  art: Art.eggGolden,
                  value: '$best',
                  label: 'best day',
                ),
                _Chip(
                  art: Art.nest,
                  value: '$blanks',
                  label: 'blank days',
                ),
              ],
            ),
            if (change != null) ...[
              const SizedBox(height: AppGap.md),
              InfoNote(
                change >= 0
                    ? 'Up ${change.round()}% on the previous seven days.'
                    : 'Down ${change.abs().round()}% on the previous seven '
                        'days.',
                icon: change >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                tone: change >= 0 ? InfoTone.positive : InfoTone.warning,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.art, required this.value, required this.label});

  final String art;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Sprite(art, size: 26),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: AppText.section),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopLayers extends StatelessWidget {
  const _TopLayers({required this.entries});

  final List<HenProduction> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const InfoNote('Add hens to see who produces most.');
    }

    final ranked = [...entries]
      ..sort((a, b) => b.eggsInWindow.compareTo(a.eggsInWindow));
    final peak = ranked.first.eggsInWindow;

    return SoftCard(
      child: Column(
        children: [
          for (final entry in ranked.take(5))
            BreakdownRow(
              leading: HenAvatar(hen: entry.hen, size: 30),
              label: entry.hen.name,
              value: '${entry.eggsInWindow}',
              share: '${entry.ratePerWeek(30).toStringAsFixed(1)}/wk',
              fraction: peak == 0 ? 0 : entry.eggsInWindow / peak,
              tone: entry.needsAttention
                  ? AppColors.rampHigh
                  : AppColors.rampLow,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HenDetailScreen(henId: entry.hen.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CostStrip extends StatelessWidget {
  const _CostStrip({required this.costs});

  final FeedCostSummary costs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ArtTile(
            art: Art.coin,
            value: costs.costPerEgg!.toStringAsFixed(2),
            label: 'cost per egg',
            tone: AppColors.goldDeep,
          ),
        ),
        const SizedBox(width: AppGap.sm + 2),
        Expanded(
          child: ArtTile(
            art: Art.coins,
            value: costs.totalSpent.toStringAsFixed(0),
            label: 'spent on feed',
            tone: AppColors.ink,
          ),
        ),
        const SizedBox(width: AppGap.sm + 2),
        Expanded(
          child: ArtTile(
            art: Art.hay,
            value: '${costs.totalKg.toStringAsFixed(0)} kg',
            label: 'feed bought',
            tone: AppColors.bark,
          ),
        ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.entry});

  final HenProduction entry;

  @override
  Widget build(BuildContext context) {
    final days = entry.daysSinceLastEgg;
    return AppRow(
      leading: HenAvatar(hen: entry.hen, size: 38),
      title: entry.hen.name,
      detail: days == null
          ? 'Marked as laying but has no eggs recorded'
          : 'No eggs for $days days',
      trailing: ToneBadge(
        label: days == null ? 'no data' : '${days}d',
        tone: AppColors.rampHigh,
      ),
      chevron: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HenDetailScreen(henId: entry.hen.id),
        ),
      ),
    );
  }
}

class _CareRow extends ConsumerWidget {
  const _CareRow({required this.event});

  final HealthEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = event.daysUntilDue ?? 0;
    final overdue = due <= 0;
    final hens = ref.watch(hensProvider).valueOrNull;
    final subject = event.henId == null
        ? 'Whole flock'
        : hens?.where((h) => h.id == event.henId).firstOrNull?.name ?? 'A hen';

    return AppRow(
      leading: IconChip(
        icon: overdue
            ? Icons.notification_important_outlined
            : Icons.event_available_outlined,
        tone: overdue ? AppColors.danger : AppColors.info,
      ),
      title: event.kind.label,
      detail: subject,
      trailing: ToneBadge(
        label: overdue
            ? due == 0
                ? 'Today'
                : '${-due}d late'
            : 'in ${due}d',
        tone: overdue ? AppColors.danger : AppColors.info,
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => const SoftCard(
        child: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

/// Shown before any birds exist. It states plainly who the app is for, so a
/// reviewer or a new user knows within one screen what they downloaded.
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  static const _points = <(String, String, String)>[
    (
      Art.hen,
      'A page for every hen',
      'Name, breed, age, egg colour and laying status, so you can tell your '
          'birds apart and see who is producing.',
    ),
    (
      Art.egg,
      'Daily egg records',
      'Log the eggs each hen lays. After a few weeks you can see exactly '
          'which birds earn their keep and which have stopped.',
    ),
    (
      Art.nest,
      'Health and worming schedule',
      'Record treatments and get the next due date worked out for you, so a '
          'missed worming does not cost you a bird.',
    ),
    (
      Art.coins,
      'Feed costs and cost per egg',
      'Enter what you pay for feed and the app works out what each egg '
          'actually costs.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppGap.page, AppGap.lg, AppGap.page, 120),
          children: [
            Text('A record book for your chickens', style: AppText.display),
            const SizedBox(height: AppGap.sm),
            Text(
              'Eggbound Rush is made for people who keep hens in the back '
              'garden. Add each of your birds, then log her eggs, her health '
              'treatments and what you spend on feed. Everything is stored on '
              'this device and works without an internet connection.',
              style: AppText.body,
            ),
            const SizedBox(height: AppGap.lg),
            if (wide)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisSpacing: AppGap.md,
                mainAxisSpacing: AppGap.md,
                childAspectRatio: 2.6,
                children: [
                  for (final (art, title, body) in _points)
                    _PurposeCard(art: art, title: title, body: body),
                ],
              )
            else
              for (final (art, title, body) in _points) ...[
                _PurposeCard(art: art, title: title, body: body),
                const SizedBox(height: AppGap.sm + 2),
              ],
            const SizedBox(height: AppGap.md),
            PillButton(
              label: 'Add your first hen',
              icon: Icons.add_rounded,
              tone: PillTone.accent,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HenEditorScreen(),
                ),
              ),
            ),
            const MeadowFooter(),
          ],
        );
      },
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard({
    required this.art,
    required this.title,
    required this.body,
  });

  final String art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Sprite(art, size: 46),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 3),
                Text(body, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

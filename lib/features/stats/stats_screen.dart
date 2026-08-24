import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/art.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/flock_repository.dart';
import '../flock/flock_providers.dart';
import '../flock/flock_screen.dart';
import '../flock/hen_detail_screen.dart';

enum _Range { week, month, quarter }

extension on _Range {
  int get days => switch (this) {
        _Range.week => 7,
        _Range.month => 30,
        _Range.quarter => 90,
      };

  String get label => switch (this) {
        _Range.week => '7 days',
        _Range.month => '30 days',
        _Range.quarter => '90 days',
      };
}

/// Production analysis: how the flock as a whole is doing, and how each bird
/// contributes to that. Everything is computed from the keeper's own records
/// on this device.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(dailySeriesProvider(_range.days));
    final summaryAsync = ref.watch(flockSummaryProvider);
    final productionAsync = ref.watch(henProductionProvider);
    final costsAsync = ref.watch(feedCostsProvider);

    return Scaffold(
      body: Column(
        children: [
          RibbonHeader(
            title: 'Statistics',
            subtitle: 'Worked out from your records, on this device',
            mascot: Art.henNesting,
            onBack: Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
            bottom: SegmentedPills<_Range>(
              values: _Range.values,
              labelOf: (value) => value.label,
              selected: _range,
              onChanged: (value) => setState(() => _range = value),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppGap.page, AppGap.md + 2, AppGap.page, 120),
              children: [
                summaryAsync.maybeWhen(
                  data: (summary) => summary.activeHens == 0
                      ? const EmptyHint(
                          icon: Icons.insights_outlined,
                          art: Art.nest,
                          title: 'Nothing to analyse yet',
                          message:
                              'Add your hens and log a few days of eggs. This '
                              'screen then shows your weekly output, which '
                              'birds produce most, and what each egg costs.',
                        )
                      : _Overview(summary: summary),
                  orElse: () => const SizedBox.shrink(),
                ),

                SectionTitle(
                  'Eggs per day',
                  subtitle: 'Across the last ${_range.label}',
                ),
                SoftCard(
                  child: seriesAsync.when(
                    loading: () => const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) =>
                        Text('$error', style: AppText.caption),
                    data: (series) => _Trend(series: series),
                  ),
                ),

                const SectionTitle(
                  'Per hen',
                  subtitle: 'Who is earning her feed',
                ),
                productionAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text('$error', style: AppText.caption),
                  data: (entries) => entries.isEmpty
                      ? const InfoNote(
                          'Add hens to compare their output side by side.',
                        )
                      : _PerHen(entries: entries, days: _range.days),
                ),

                const SectionTitle('Cost'),
                costsAsync.maybeWhen(
                  data: (costs) => _CostSummary(costs: costs),
                  orElse: () => const SizedBox.shrink(),
                ),

                const MeadowFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});

  final FlockSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.weekChangePercent;

    return Column(
      children: [
        HeroCard(
          value: '${summary.eggsThisWeek}',
          label: 'Eggs this week',
          art: Art.basket,
          caption: change == null
              ? 'No previous week to compare against yet'
              : '${change >= 0 ? 'Up' : 'Down'} ${change.abs().round()}% on '
                  'the previous 7 days',
        ),
        const SizedBox(height: AppGap.md),
        Row(
          children: [
            Expanded(
              child: ArtTile(
                art: Art.egg,
                value: '${summary.eggsAllTime}',
                label: 'eggs all time',
                tone: AppColors.goldDeep,
              ),
            ),
            const SizedBox(width: AppGap.sm + 2),
            Expanded(
              child: ArtTile(
                art: Art.hen,
                value: '${summary.layingHens}',
                label: 'of ${summary.activeHens} laying',
                tone: AppColors.forest,
              ),
            ),
            const SizedBox(width: AppGap.sm + 2),
            Expanded(
              child: ArtTile(
                art: Art.nest,
                value: '${(summary.weeklyLayRate * 100).round()}%',
                label: 'lay rate',
                tone: AppColors.rampLow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.series});

  final List<({DateTime day, int count})> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Text('No data for this period yet.', style: AppText.body);
    }

    final total = series.fold<int>(0, (sum, point) => sum + point.count);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Sprite(Art.nest, size: 52),
            const SizedBox(width: AppGap.md),
            Expanded(
              child: Text(
                'No eggs logged in this period. Use "Log eggs" on the home '
                'screen to start building the picture.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      );
    }

    final peak = series.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final average = total / series.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RidgeChart(
          values: [for (final point in series) point.count],
          labels: [
            formatShortDate(series.first.day),
            formatShortDate(series[series.length ~/ 2].day),
            formatShortDate(series.last.day),
          ],
          height: 150,
        ),
        const Divider(height: AppGap.lg + 6),
        Row(
          children: [
            _Figure(value: '$total', label: 'total'),
            _Figure(value: average.toStringAsFixed(1), label: 'per day'),
            _Figure(value: '$peak', label: 'best day'),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppText.section),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _PerHen extends StatelessWidget {
  const _PerHen({required this.entries, required this.days});

  final List<HenProduction> entries;
  final int days;

  @override
  Widget build(BuildContext context) {
    // Ranking makes the comparison immediate; the top bird sets the scale.
    final ranked = [...entries]
      ..sort((a, b) => b.eggsInWindow.compareTo(a.eggsInWindow));
    final peak = ranked.first.eggsInWindow;

    return SoftCard(
      child: Column(
        children: [
          for (final entry in ranked)
            BreakdownRow(
              leading: HenAvatar(hen: entry.hen, size: 30),
              label: entry.hen.name,
              value: '${entry.eggsInWindow}',
              share: '${entry.ratePerWeek(days).toStringAsFixed(1)}/wk',
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

class _CostSummary extends StatelessWidget {
  const _CostSummary({required this.costs});

  final FeedCostSummary costs;

  @override
  Widget build(BuildContext context) {
    final perEgg = costs.costPerEgg;
    if (perEgg == null) {
      return const InfoNote(
        'Log your feed purchases under Feed & costs and the app will work out '
        'what each egg costs you.',
      );
    }

    return Row(
      children: [
        Expanded(
          child: ArtTile(
            art: Art.eggGolden,
            value: perEgg.toStringAsFixed(2),
            label: 'cost per egg',
            tone: AppColors.goldDeep,
          ),
        ),
        const SizedBox(width: AppGap.sm + 2),
        Expanded(
          child: ArtTile(
            art: Art.coins,
            value: costs.totalSpent.toStringAsFixed(2),
            label: 'feed spend to date',
            tone: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

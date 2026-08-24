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

/// Feed spending and the figure it produces: what one egg costs. This is the
/// question that decides whether a backyard flock pays for itself.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(feedEntriesProvider);
    final costsAsync = ref.watch(feedCostsProvider);
    final activeHens = ref.watch(
      flockSummaryProvider.select((s) => s.valueOrNull?.activeHens ?? 0),
    );

    return Scaffold(
      body: Column(
        children: [
          RibbonHeader(
            title: 'Feed & costs',
            subtitle: 'What your eggs actually cost you',
            mascot: Art.henWalking,
            onBack: Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
            trailing: HeaderIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Add a feed purchase',
              onPressed: () => showAddFeedSheet(context),
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (entries) => ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppGap.page, AppGap.md + 2, AppGap.page, 110),
                children: [
                  costsAsync.maybeWhen(
                    data: (costs) =>
                        _CostBlock(costs: costs, activeHens: activeHens),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  SectionTitle(
                    'Purchases',
                    subtitle:
                        entries.isEmpty ? null : '${entries.length} logged',
                  ),
                  if (entries.isEmpty)
                    EmptyHint(
                      icon: Icons.shopping_bag_outlined,
                      art: Art.hay,
                      title: 'No purchases logged',
                      message: 'Add each bag of feed you buy with its weight '
                          'and price. The app divides that spend across the '
                          'eggs collected since, giving you a real cost per '
                          'egg.',
                      action: PillButton(
                        label: 'Add a purchase',
                        icon: Icons.add_rounded,
                        tone: PillTone.accent,
                        onPressed: () => showAddFeedSheet(context),
                      ),
                    )
                  else ...[
                    _PurchaseBreakdown(entries: entries),
                    const SizedBox(height: AppGap.md),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final entry in entries) _FeedRow(entry: entry),
                        ],
                      ),
                    ),
                  ],
                  const MeadowFooter(
                    message: 'Swipe a purchase left to remove it.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostBlock extends StatelessWidget {
  const _CostBlock({required this.costs, required this.activeHens});

  final FeedCostSummary costs;
  final int activeHens;

  @override
  Widget build(BuildContext context) {
    if (costs.totalSpent <= 0) {
      return const InfoNote(
        'Once you log a feed purchase and collect some eggs, your cost per '
        'egg appears here.',
      );
    }

    final perEgg = costs.costPerEgg;
    final perKg = costs.averageCostPerKg;
    final daysLeft = costs.estimatedDaysRemaining(activeHens);

    return Column(
      children: [
        HeroCard(
          value: perEgg == null ? '—' : perEgg.toStringAsFixed(2),
          label: 'Cost per egg',
          gradient: AppGradients.goldenEgg,
          art: Art.eggGolden,
          caption: perEgg == null
              ? 'No eggs recorded since your first feed purchase yet.'
              : 'Across ${costs.eggsSinceFirstPurchase} eggs since '
                  '${formatDate(costs.since!)}',
        ),
        const SizedBox(height: AppGap.md),
        Row(
          children: [
            Expanded(
              child: ArtTile(
                art: Art.coins,
                value: costs.totalSpent.toStringAsFixed(2),
                label: 'total spent',
                tone: AppColors.goldDeep,
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
            const SizedBox(width: AppGap.sm + 2),
            Expanded(
              child: ArtTile(
                art: Art.trough,
                value: perKg == null ? '—' : perKg.toStringAsFixed(2),
                label: 'average per kg',
                tone: AppColors.forest,
              ),
            ),
          ],
        ),
        if (daysLeft != null) ...[
          const SizedBox(height: AppGap.sm + 2),
          _FeedRemainingTile(days: daysLeft, activeHens: activeHens),
        ],
      ],
    );
  }
}

class _FeedRemainingTile extends StatelessWidget {
  const _FeedRemainingTile({required this.days, required this.activeHens});

  final int days;
  final int activeHens;

  @override
  Widget build(BuildContext context) {
    final (tone, badge) = switch (days) {
      > 14 => (AppColors.accent, null as String?),
      > 6 => (AppColors.warn, 'Low'),
      _ => (AppColors.danger, 'Very low'),
    };

    final valueText = days <= 0 ? '< 1' : '$days';
    final caption = 'est. for $activeHens '
        '${activeHens == 1 ? 'hen' : 'hens'} · ~0.12 kg/hen/day';

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Sprite(Art.hay, size: 34),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ESTIMATED FEED LEFT', style: AppText.overline),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valueText,
                      style: AppText.metric.copyWith(color: tone),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'days',
                      style: AppText.body.copyWith(color: tone),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(caption, style: AppText.caption),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppGap.sm),
            ToneBadge(label: badge, tone: tone),
          ],
        ],
      ),
    );
  }
}

/// Where the money went, by product. A keeper buying pellets, corn and grit
/// separately can see at a glance which line dominates the bill.
class _PurchaseBreakdown extends StatelessWidget {
  const _PurchaseBreakdown({required this.entries});

  final List<FeedEntry> entries;

  static const _tones = [
    AppColors.gold,
    AppColors.forest,
    AppColors.info,
    AppColors.berry,
    AppColors.bark,
  ];

  @override
  Widget build(BuildContext context) {
    final byName = <String, double>{};
    for (final entry in entries) {
      byName.update(entry.name, (v) => v + entry.cost,
          ifAbsent: () => entry.cost);
    }
    final total = byName.values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) return const SizedBox.shrink();

    final ranked = byName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHERE THE MONEY GOES', style: AppText.overline),
          const SizedBox(height: AppGap.sm),
          for (var i = 0; i < ranked.length; i++)
            BreakdownRow(
              label: ranked[i].key,
              value: ranked[i].value.toStringAsFixed(2),
              share: '${((ranked[i].value / total) * 100).round()}%',
              fraction: ranked[i].value / total,
              tone: _tones[i % _tones.length],
            ),
        ],
      ),
    );
  }
}

class _FeedRow extends ConsumerWidget {
  const _FeedRow({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('feed-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(flockActionsProvider).deleteFeedEntry(entry.id),
      child: AppRow(
        leading: const Sprite(Art.hay, size: 38),
        title: entry.name,
        detail: '${entry.weightKg.toStringAsFixed(0)} kg · '
            '${formatDate(entry.purchasedOn)}',
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.cost.toStringAsFixed(2), style: AppText.bodyStrong),
            Text('${entry.costPerKg.toStringAsFixed(2)}/kg',
                style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddFeedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66201808),
    builder: (_) => const _AddFeedSheet(),
  );
}

class _AddFeedSheet extends ConsumerStatefulWidget {
  const _AddFeedSheet();

  @override
  ConsumerState<_AddFeedSheet> createState() => _AddFeedSheetState();
}

class _AddFeedSheetState extends ConsumerState<_AddFeedSheet> {
  final _name = TextEditingController(text: 'Layer pellets');
  final _weight = TextEditingController();
  final _cost = TextEditingController();

  DateTime _purchasedOn = startOfDay(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final weight = double.tryParse(_weight.text.replaceAll(',', '.'));
    final cost = double.tryParse(_cost.text.replaceAll(',', '.'));

    if (weight == null || weight <= 0 || cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a weight and a price.')),
      );
      return;
    }

    setState(() => _saving = true);
    await ref.read(flockActionsProvider).addFeedEntry(
          name: _name.text.trim().isEmpty ? 'Feed' : _name.text.trim(),
          weightKg: weight,
          cost: cost,
          purchasedOn: _purchasedOn,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedOn,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _purchasedOn = startOfDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Add a feed purchase',
      subtitle: 'Amounts are plain numbers in whatever currency you use.',
      art: Art.hay,
      action: PillButton(
        label: _saving ? 'Saving…' : 'Save purchase',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: _saving ? null : _submit,
      ),
      children: [
        AppTextField(
          label: 'What you bought',
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppGap.md + 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Weight (kg)',
                controller: _weight,
                numeric: true,
                hint: '25',
              ),
            ),
            const SizedBox(width: AppGap.md - 2),
            Expanded(
              child: AppTextField(
                label: 'Price paid',
                controller: _cost,
                numeric: true,
                hint: '18.50',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppGap.md + 2),
        DateField(
          label: 'Purchased on',
          value: _purchasedOn,
          onPick: _pickDate,
        ),
        const SizedBox(height: AppGap.md),
      ],
    );
  }
}

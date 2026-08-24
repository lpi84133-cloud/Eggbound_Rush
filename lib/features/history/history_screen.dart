import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/models.dart';
import '../pasture/pasture_controller.dart';

enum _Filter { all, eggs, objects, zones }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.eggs => 'Eggs',
        _Filter.objects => 'Objects',
        _Filter.zones => 'Zones',
      };

  bool matches(ActivityKind kind) => switch (this) {
        _Filter.all => true,
        _Filter.eggs => kind == ActivityKind.eggMarked ||
            kind == ActivityKind.eggCollected ||
            kind == ActivityKind.eggRemoved,
        _Filter.objects => kind == ActivityKind.objectPlaced ||
            kind == ActivityKind.objectMoved ||
            kind == ActivityKind.objectRemoved,
        _Filter.zones => kind == ActivityKind.zoneCreated ||
            kind == ActivityKind.zoneUpdated ||
            kind == ActivityKind.zoneRemoved,
      };
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'History',
            subtitle: 'A local log of what you changed and collected',
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
              onPressed: () => _confirmClear(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 0),
            child: SegmentedPills<_Filter>(
              values: _Filter.values,
              labelOf: (value) => value.label,
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (activities) {
                final filtered = activities
                    .where((activity) => _filter.matches(activity.kind))
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyHint(
                      icon: Icons.history_rounded,
                      title: 'Nothing logged here yet',
                      message: _filter == _Filter.all
                          ? 'Place an object or mark an egg, and every change '
                              'will appear in this log.'
                          : 'No ${_filter.label.toLowerCase()} activity in your '
                              'log yet.',
                    ),
                  );
                }

                final groups = _groupByDay(filtered);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(_dayLabel(group.day)),
                        SoftCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppGap.md,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < group.items.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _ActivityRow(activity: group.items[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('Clear the history log?', style: AppText.title),
        content: Text(
          'This removes the log entries only. Your pasture layout, eggs and '
          'zones stay exactly as they are. Care Points earned so far are '
          'recalculated from the log, so they will reset too.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear',
                style: AppText.bodyStrong.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pastureControllerProvider.notifier).clearHistory();
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }

  static List<_DayGroup> _groupByDay(List<Activity> activities) {
    final groups = <DateTime, List<Activity>>{};
    for (final activity in activities) {
      final key = DateTime(
        activity.createdAt.year,
        activity.createdAt.month,
        activity.createdAt.day,
      );
      groups.putIfAbsent(key, () => []).add(activity);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final key in keys) _DayGroup(key, groups[key]!)];
  }
}

class _DayGroup {
  const _DayGroup(this.day, this.items);

  final DateTime day;
  final List<Activity> items;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual(activity.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: AppText.bodyStrong),
                Text(
                  activity.detail ??
                      DateFormat('HH:mm').format(activity.createdAt),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (activity.points > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${activity.points}',
                style: AppText.caption.copyWith(
                  color: AppColors.barkDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static (IconData, Color) _visual(ActivityKind kind) => switch (kind) {
        ActivityKind.eggCollected => (
            Icons.check_circle_rounded,
            AppColors.meadow
          ),
        ActivityKind.eggMarked => (Icons.egg_outlined, AppColors.amber),
        ActivityKind.eggRemoved => (Icons.close_rounded, AppColors.inkFaint),
        ActivityKind.objectPlaced => (Icons.add_rounded, AppColors.water),
        ActivityKind.objectMoved => (Icons.open_with_rounded, AppColors.water),
        ActivityKind.objectRemoved => (
            Icons.delete_outline_rounded,
            AppColors.inkFaint
          ),
        ActivityKind.zoneCreated => (
            Icons.dashboard_customize_rounded,
            AppColors.zoneCollection
          ),
        ActivityKind.zoneUpdated => (Icons.tune_rounded, AppColors.zoneCollection),
        ActivityKind.zoneRemoved => (
            Icons.delete_outline_rounded,
            AppColors.inkFaint
          ),
        ActivityKind.itemUnlocked => (Icons.eco_rounded, AppColors.gold),
        ActivityKind.themeChanged => (Icons.palette_rounded, AppColors.bark),
      };
}

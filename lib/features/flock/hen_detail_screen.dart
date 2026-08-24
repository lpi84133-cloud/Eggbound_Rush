import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/art.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/flock.dart';
import 'flock_providers.dart';
import 'flock_screen.dart';
import 'hen_editor_screen.dart';
import 'log_eggs_sheet.dart';
import 'log_health_sheet.dart';

/// Everything recorded about one bird: her details, her laying history and
/// the treatments she has had.
class HenDetailScreen extends ConsumerWidget {
  const HenDetailScreen({super.key, required this.henId});

  final int henId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final henAsync = ref.watch(henByIdProvider(henId));

    return Scaffold(
      body: henAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error', style: AppText.body)),
        data: (hen) => hen == null
            ? Center(
                child: Text('This hen is no longer in your records.',
                    style: AppText.body),
              )
            : _Body(hen: hen),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.hen});

  final Hen hen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(henEggRecordsProvider(hen.id));
    final healthAsync = ref.watch(henHealthProvider(hen.id));
    final productionAsync = ref.watch(henProductionProvider);
    final windowDays = ref.watch(productionWindowProvider);

    final production = productionAsync.valueOrNull
        ?.where((entry) => entry.hen.id == hen.id)
        .firstOrNull;

    return Column(
      children: [
        RibbonHeader(
          title: hen.name,
          subtitle: [
            if (hen.breed != null && hen.breed!.isNotEmpty) hen.breed!,
            hen.ageLabel,
          ].join(' · '),
          mascot: Art.henPecking,
          onBack: () => Navigator.of(context).pop(),
          trailing: HeaderIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HenEditorScreen(existing: hen),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppGap.page, AppGap.md + 2, AppGap.page, AppGap.xl),
            children: [
              if (production != null)
                HeroCard(
                  value: '${production.eggsInWindow}',
                  label: 'Eggs in $windowDays days',
                  caption:
                      '${production.ratePerWeek(windowDays).toStringAsFixed(1)}'
                      ' per week · ${production.eggsAllTime} all time',
                  trailing: HenAvatar(hen: hen, size: 62),
                ),

              const SizedBox(height: AppGap.md),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Log eggs',
                      icon: Icons.egg_outlined,
                      expand: true,
                      onPressed: () => showLogEggsSheet(context, hen: hen),
                    ),
                  ),
                  const SizedBox(width: AppGap.md - 2),
                  Expanded(
                    child: PillButton(
                      label: 'Log care',
                      icon: Icons.medical_services_outlined,
                      tone: PillTone.quiet,
                      expand: true,
                      onPressed: () => showLogHealthSheet(context, hen: hen),
                    ),
                  ),
                ],
              ),

              const SectionTitle('Details'),
              RowGroup(
                children: [
                  AppRow(
                    leading: const IconChip(icon: Icons.egg_outlined),
                    title: '${hen.eggColor.label} eggs',
                    detail: 'Shell colour',
                    trailing: Container(
                      width: 22,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(hen.eggColor.swatch),
                        borderRadius:
                            const BorderRadius.all(Radius.elliptical(11, 13)),
                        border: Border.all(color: AppColors.lineStrong),
                      ),
                    ),
                  ),
                  AppRow(
                    leading: const IconChip(
                        icon: Icons.favorite_border_rounded,
                        tone: AppColors.info),
                    title: hen.status.label,
                    detail: hen.status.hint,
                  ),
                  AppRow(
                    leading: const IconChip(
                        icon: Icons.cake_outlined, tone: AppColors.warn),
                    title: hen.hatchedOn == null
                        ? 'Hatch date unknown'
                        : formatDate(hen.hatchedOn!),
                    detail: hen.ageNote ?? 'Add a hatch date to track her age',
                  ),
                  AppRow(
                    leading: const IconChip(icon: Icons.home_outlined),
                    title: formatDate(hen.acquiredOn),
                    detail: 'In your flock since',
                  ),
                ],
              ),

              if (hen.notes != null && hen.notes!.isNotEmpty) ...[
                const SectionTitle('Notes'),
                SoftCard(child: Text(hen.notes!, style: AppText.body)),
              ],

              const SectionTitle('Laying history'),
              recordsAsync.when(
                loading: () => const _Loading(),
                error: (error, _) => Text('$error', style: AppText.caption),
                data: (records) => records.isEmpty
                    ? EmptyHint(
                        icon: Icons.egg_outlined,
                        art: Art.nest,
                        title: 'No eggs recorded yet',
                        message:
                            'Tap "Log eggs" whenever ${hen.name} lays. Over a '
                            'few weeks this becomes a reliable picture of her '
                            'output.',
                      )
                    : RowGroup(
                        children: [
                          for (final record in records)
                            _EggRow(record: record),
                        ],
                      ),
              ),

              const SectionTitle('Health & treatments'),
              healthAsync.when(
                loading: () => const _Loading(),
                error: (error, _) => Text('$error', style: AppText.caption),
                data: (events) => events.isEmpty
                    ? const EmptyHint(
                        icon: Icons.medical_services_outlined,
                        title: 'Nothing logged yet',
                        message:
                            'Record worming, mite treatments and vet visits '
                            'here. The app will tell you when the next one is '
                            'due.',
                      )
                    : RowGroup(
                        children: [
                          for (final event in events)
                            _HealthRow(event: event),
                        ],
                      ),
              ),

              const MeadowFooter(
                message: 'Swipe an entry left to remove it.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EggRow extends ConsumerWidget {
  const _EggRow({required this.record});

  final EggRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('egg-${record.id}'),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) =>
          ref.read(flockActionsProvider).deleteEggRecord(record.id),
      child: AppRow(
        leading: const IconChip(icon: Icons.egg_outlined, size: 34),
        title: formatDate(record.collectedOn),
        detail: record.note?.isNotEmpty == true ? record.note : null,
        trailing: Text(
          '+${record.count}',
          style: AppText.bodyStrong.copyWith(color: AppColors.accentDeep),
        ),
      ),
    );
  }
}

class _HealthRow extends ConsumerWidget {
  const _HealthRow({required this.event});

  final HealthEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = event.daysUntilDue;
    final detail = StringBuffer(formatDate(event.performedOn));
    if (event.henId == null) detail.write(' · whole flock');

    return Dismissible(
      key: ValueKey('health-${event.id}'),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) =>
          ref.read(flockActionsProvider).deleteHealthEvent(event.id),
      child: AppRow(
        leading: IconChip(
          icon: Icons.medical_services_outlined,
          size: 34,
          tone: event.isOverdue ? AppColors.danger : AppColors.info,
        ),
        title: event.kind.label,
        detail: detail.toString(),
        trailing: due == null
            ? null
            : Text(
                due < 0
                    ? '${-due}d late'
                    : due == 0
                        ? 'today'
                        : 'in ${due}d',
                style: AppText.caption.copyWith(
                  color: due <= 0 ? AppColors.danger : AppColors.inkMuted,
                  fontWeight: due <= 0 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: AppColors.danger,
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
}

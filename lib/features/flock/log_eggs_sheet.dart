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

/// Logs today's eggs. When a hen is passed in the sheet records against her
/// directly; otherwise the keeper picks a bird or records a coop total.
Future<void> showLogEggsSheet(BuildContext context, {Hen? hen}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66101510),
    builder: (_) => _LogEggsSheet(hen: hen),
  );
}

class _LogEggsSheet extends ConsumerStatefulWidget {
  const _LogEggsSheet({this.hen});

  final Hen? hen;

  @override
  ConsumerState<_LogEggsSheet> createState() => _LogEggsSheetState();
}

class _LogEggsSheetState extends ConsumerState<_LogEggsSheet> {
  late int? _henId = widget.hen?.id;
  DateTime _day = startOfDay(DateTime.now());
  int _count = 1;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    await ref.read(flockActionsProvider).logEggs(
          henId: _henId,
          count: _count,
          on: _day,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hensAsync = ref.watch(hensProvider);

    return AppSheet(
      title: widget.hen == null
          ? 'Log eggs'
          : 'Log eggs for ${widget.hen!.name}',
      subtitle: 'Recording who laid what is what makes the productivity '
          'figures meaningful.',
      art: Art.basket,
      action: PillButton(
        label: _saving ? 'Saving…' : 'Save record',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: _saving ? null : _submit,
      ),
      children: [
        FieldShell(
          label: 'How many',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountStepper(
                value: _count,
                onChanged: (value) => setState(() => _count = value),
              ),
              const SizedBox(height: AppGap.sm + 2),
              // Drawing the count back makes a mis-tap on the stepper obvious
              // before it is saved.
              EggGrid(count: _count, eggSize: 26, perRow: 8, max: 24),
            ],
          ),
        ),
        const SizedBox(height: AppGap.lg),
        FieldShell(
          label: 'Day',
          child: _DayPicker(
            value: _day,
            onChanged: (value) => setState(() => _day = value),
          ),
        ),
        if (widget.hen == null) ...[
          const SizedBox(height: AppGap.lg),
          FieldShell(
            label: 'Which hen',
            child: hensAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('$error', style: AppText.caption),
              data: (hens) => _HenChooser(
                hens: hens,
                selected: _henId,
                onChanged: (value) => setState(() => _henId = value),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppGap.md),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));

    final options = <(DateTime, String)>[
      (today, 'Today'),
      (yesterday, 'Yesterday'),
      (dayBefore, formatShortDate(dayBefore)),
    ];

    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppGap.sm),
          Expanded(
            child: _DayOption(
              label: options[i].$2,
              selected: value == options[i].$1,
              onTap: () => onChanged(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayOption extends StatelessWidget {
  const _DayOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: AppRadius.brSmall,
      child: InkWell(
        borderRadius: AppRadius.brSmall,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brSmall,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(
                  color: selected ? Colors.white : AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HenChooser extends StatelessWidget {
  const _HenChooser({
    required this.hens,
    required this.selected,
    required this.onChanged,
  });

  final List<Hen> hens;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // A coop total is the honest option when several hens share a nest
        // box and the keeper genuinely cannot attribute the eggs.
        _ChooserRow(
          label: 'Whole coop',
          detail: 'Do not attribute to a specific hen',
          selected: selected == null,
          onTap: () => onChanged(null),
          leading: const IconChip(icon: Icons.home_work_outlined, size: 36),
        ),
        for (final hen in hens) ...[
          const SizedBox(height: AppGap.sm),
          _ChooserRow(
            label: hen.name,
            detail: hen.breed?.isNotEmpty == true
                ? hen.breed!
                : '${hen.eggColor.label} eggs',
            selected: selected == hen.id,
            onTap: () => onChanged(hen.id),
            leading: HenAvatar(hen: hen, size: 36),
          ),
        ],
      ],
    );
  }
}

class _ChooserRow extends StatelessWidget {
  const _ChooserRow({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    required this.leading,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: selected ? AppColors.accentSoft : AppColors.surface,
      border: Border.all(
        color: selected ? AppColors.accent : AppColors.line,
        width: selected ? 1.6 : 1,
      ),
      shadow: !selected,
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppGap.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? AppColors.accent : AppColors.lineStrong,
          ),
        ],
      ),
    );
  }
}

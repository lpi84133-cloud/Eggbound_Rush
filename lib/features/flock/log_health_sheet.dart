import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/art.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/flock.dart';
import 'flock_providers.dart';

/// Records a treatment and, where the treatment repeats on a schedule,
/// pre-fills the next due date so the keeper does not have to remember it.
Future<void> showLogHealthSheet(BuildContext context, {Hen? hen}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66101510),
    builder: (_) => _LogHealthSheet(hen: hen),
  );
}

class _LogHealthSheet extends ConsumerStatefulWidget {
  const _LogHealthSheet({this.hen});

  final Hen? hen;

  @override
  ConsumerState<_LogHealthSheet> createState() => _LogHealthSheetState();
}

class _LogHealthSheetState extends ConsumerState<_LogHealthSheet> {
  final _note = TextEditingController();
  final DateTime _performedOn = startOfDay(DateTime.now());

  HealthEventKind _kind = HealthEventKind.miteTreatment;
  late DateTime? _nextDueOn = _defaultDue(_kind);
  bool _saving = false;

  DateTime? _defaultDue(HealthEventKind kind) {
    final interval = kind.defaultInterval;
    return interval == null ? null : _performedOn.add(interval);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    await ref.read(flockActionsProvider).logHealthEvent(
          henId: widget.hen?.id,
          kind: _kind,
          performedOn: _performedOn,
          nextDueOn: _nextDueOn,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickNextDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueOn ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextDueOn = startOfDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.hen == null
          ? 'Log flock care'
          : 'Log care for ${widget.hen!.name}',
      subtitle: widget.hen == null
          ? 'This applies to every bird in your flock.'
          : 'Recorded against ${widget.hen!.name} only.',
      art: Art.henWalking,
      action: PillButton(
        label: _saving ? 'Saving…' : 'Save record',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: _saving ? null : _submit,
      ),
      children: [
        FieldShell(
          label: 'What did you do',
          child: Wrap(
            spacing: AppGap.sm,
            runSpacing: AppGap.sm,
            children: [
              for (final kind in HealthEventKind.values)
                SelectChip(
                  label: kind.label,
                  selected: kind == _kind,
                  onTap: () => setState(() {
                    _kind = kind;
                    _nextDueOn = _defaultDue(kind);
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppGap.lg),
        DateField(
          label: 'Remind me again on',
          hint: _kind.defaultInterval == null
              ? 'Optional for this kind of record.'
              : 'Pre-filled with the usual interval — adjust if your vet '
                  'advises otherwise.',
          value: _nextDueOn,
          emptyLabel: 'No reminder',
          icon: Icons.event_repeat_rounded,
          onPick: _pickNextDue,
          onClear: _nextDueOn == null
              ? null
              : () => setState(() => _nextDueOn = null),
        ),
        const SizedBox(height: AppGap.lg),
        AppTextField(
          label: 'Notes',
          hint: 'Product used, dose, what you observed…',
          controller: _note,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppGap.md),
      ],
    );
  }
}

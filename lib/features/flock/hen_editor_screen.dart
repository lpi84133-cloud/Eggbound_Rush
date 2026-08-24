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

/// Add or edit one bird. Only a name is required — a keeper standing in the
/// run with one hand full should be able to finish this in a few seconds and
/// fill in the rest later.
class HenEditorScreen extends ConsumerStatefulWidget {
  const HenEditorScreen({super.key, this.existing});

  final Hen? existing;

  @override
  ConsumerState<HenEditorScreen> createState() => _HenEditorScreenState();
}

class _HenEditorScreenState extends ConsumerState<HenEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _notes;
  final _breedFocus = FocusNode();
  final _notesFocus = FocusNode();

  late EggColor _eggColor;
  late HenStatus _status;
  late DateTime _acquiredOn;
  DateTime? _hatchedOn;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final hen = widget.existing;
    _name = TextEditingController(text: hen?.name ?? '');
    _breed = TextEditingController(text: hen?.breed ?? '');
    _notes = TextEditingController(text: hen?.notes ?? '');
    _eggColor = hen?.eggColor ?? EggColor.brown;
    _status = hen?.status ?? HenStatus.laying;
    _acquiredOn = hen?.acquiredOn ?? startOfDay(DateTime.now());
    _hatchedOn = hen?.hatchedOn;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _notes.dispose();
    _breedFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 15),
      lastDate: now,
    );
    if (picked != null) onPicked(startOfDay(picked));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your hen a name first.')),
      );
      return;
    }

    setState(() => _saving = true);
    final actions = ref.read(flockActionsProvider);
    final breed = _breed.text.trim();
    final notes = _notes.text.trim();

    try {
      if (_isEditing) {
        await actions.updateHen(
          widget.existing!.copyWith(
            name: name,
            breed: breed,
            eggColor: _eggColor,
            status: _status,
            acquiredOn: _acquiredOn,
            hatchedOn: _hatchedOn,
            clearHatched: _hatchedOn == null,
            notes: notes,
          ),
        );
      } else {
        await actions.addHen(
          name: name,
          eggColor: _eggColor,
          acquiredOn: _acquiredOn,
          breed: breed.isEmpty ? null : breed,
          hatchedOn: _hatchedOn,
          status: _status,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          RibbonHeader(
            title: _isEditing ? 'Edit hen' : 'Add a hen',
            subtitle: _isEditing
                ? widget.existing!.name
                : 'Her records start from today',
            mascot: Art.henNesting,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;

                final identity = <Widget>[
                  AppTextField(
                    label: 'Name',
                    hint: 'Henrietta',
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _breedFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppGap.md + 2),
                  AppTextField(
                    label: 'Breed',
                    hint: 'Rhode Island Red',
                    controller: _breed,
                    focusNode: _breedFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _breedFocus.unfocus(),
                  ),
                ];

                final dates = <Widget>[
                  DateField(
                    label: 'Hatch date',
                    hint: 'Lets the app judge whether her age explains a '
                        'drop in laying.',
                    value: _hatchedOn,
                    emptyLabel: 'Not known',
                    icon: Icons.cake_outlined,
                    onPick: () => _pickDate(
                      initial: _hatchedOn,
                      onPicked: (value) => setState(() => _hatchedOn = value),
                    ),
                    onClear: _hatchedOn == null
                        ? null
                        : () => setState(() => _hatchedOn = null),
                  ),
                  const SizedBox(height: AppGap.md + 2),
                  DateField(
                    label: 'In your flock since',
                    value: _acquiredOn,
                    icon: Icons.home_outlined,
                    onPick: () => _pickDate(
                      initial: _acquiredOn,
                      onPicked: (value) => setState(() => _acquiredOn = value),
                    ),
                  ),
                ];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppGap.page, AppGap.lg, AppGap.page, AppGap.xl),
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(children: identity)),
                          const SizedBox(width: AppGap.lg),
                          Expanded(child: Column(children: dates)),
                        ],
                      )
                    else
                      ...identity,

                    const SectionTitle(
                      'Egg colour',
                      subtitle:
                          'Used to tell whose egg is whose when hens share '
                          'a nest box.',
                    ),
                    _ColorPicker(
                      value: _eggColor,
                      onChanged: (color) => setState(() => _eggColor = color),
                    ),

                    const SectionTitle('Laying status'),
                    _StatusPicker(
                      value: _status,
                      onChanged: (status) => setState(() => _status = status),
                    ),

                    if (!wide) ...[
                      const SizedBox(height: AppGap.sm),
                      const SectionTitle('Dates'),
                      ...dates,
                    ],

                    const SectionTitle('Notes'),
                    AppTextField(
                      label: 'Anything to remember',
                      hint: 'Distinguishing marks, temperament, quirks…',
                      controller: _notes,
                      focusNode: _notesFocus,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: AppGap.xl),
                    PillButton(
                      label: _saving
                          ? 'Saving…'
                          : _isEditing
                              ? 'Save changes'
                              : 'Add to my flock',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _saving ? null : _save,
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: AppGap.md),
                      _ArchiveBlock(hen: widget.existing!),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone widget so picking a colour only rebuilds the chip row,
/// not the entire form with its text fields.
class _ColorPicker extends StatefulWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final EggColor value;
  final ValueChanged<EggColor> onChanged;

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late EggColor _local;

  @override
  void initState() {
    super.initState();
    _local = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppGap.sm,
      runSpacing: AppGap.sm,
      children: [
        for (final color in EggColor.values)
          SelectChip(
            label: color.label,
            selected: color == _local,
            onTap: () {
              setState(() => _local = color);
              widget.onChanged(color);
            },
            leading: _EggSwatch(color: color),
          ),
      ],
    );
  }
}

/// Same isolation for laying-status chips.
class _StatusPicker extends StatefulWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final HenStatus value;
  final ValueChanged<HenStatus> onChanged;

  @override
  State<_StatusPicker> createState() => _StatusPickerState();
}

class _StatusPickerState extends State<_StatusPicker> {
  late HenStatus _local;

  @override
  void initState() {
    super.initState();
    _local = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppGap.sm,
          runSpacing: AppGap.sm,
          children: [
            for (final status in HenStatus.values)
              SelectChip(
                label: status.label,
                selected: status == _local,
                onTap: () {
                  setState(() => _local = status);
                  widget.onChanged(status);
                },
              ),
          ],
        ),
        const SizedBox(height: AppGap.md),
        InfoNote(_local.hint),
      ],
    );
  }
}

class _EggSwatch extends StatelessWidget {
  const _EggSwatch({required this.color});

  final EggColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 24,
      decoration: BoxDecoration(
        color: Color(color.swatch),
        borderRadius: const BorderRadius.all(Radius.elliptical(10, 12)),
        border: Border.all(color: AppColors.lineStrong),
      ),
    );
  }
}

class _ArchiveBlock extends ConsumerWidget {
  const _ArchiveBlock({required this.hen});

  final Hen hen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = hen.isArchived;
    return Column(
      children: [
        PillButton(
          label: archived ? 'Return to active flock' : 'Archive this hen',
          icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          tone: archived ? PillTone.quiet : PillTone.danger,
          expand: true,
          onPressed: () async {
            final actions = ref.read(flockActionsProvider);
            if (archived) {
              await actions.restoreHen(hen.id);
            } else {
              await actions.archiveHen(hen.id);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppGap.sm),
        Text(
          archived
              ? 'She will appear in your flock list again.'
              : 'Archiving hides her from the flock list but keeps every egg '
                  'and health record she has.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

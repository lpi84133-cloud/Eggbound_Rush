import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../domain/models.dart';

class ZoneDraft {
  const ZoneDraft({
    required this.name,
    required this.kind,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    this.deleted = false,
  });

  final String name;
  final ZoneKind kind;
  final double cx;
  final double cy;
  final double w;
  final double h;
  final bool deleted;

  ZoneDraft copyWith({
    String? name,
    ZoneKind? kind,
    double? cx,
    double? cy,
    double? w,
    double? h,
  }) =>
      ZoneDraft(
        name: name ?? this.name,
        kind: kind ?? this.kind,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        w: w ?? this.w,
        h: h ?? this.h,
      );
}

Future<ZoneDraft?> showZoneEditor(
  BuildContext context, {
  required ZoneDraft initial,
  required String themeAsset,
  bool allowDelete = false,
}) {
  return showModalBottomSheet<ZoneDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ZoneEditorSheet(
      initial: initial,
      themeAsset: themeAsset,
      allowDelete: allowDelete,
    ),
  );
}

class _ZoneEditorSheet extends StatefulWidget {
  const _ZoneEditorSheet({
    required this.initial,
    required this.themeAsset,
    required this.allowDelete,
  });

  final ZoneDraft initial;
  final String themeAsset;
  final bool allowDelete;

  @override
  State<_ZoneEditorSheet> createState() => _ZoneEditorSheetState();
}

class _ZoneEditorSheetState extends State<_ZoneEditorSheet> {
  late ZoneDraft _draft = widget.initial;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial.name);

  static const _minSize = 0.14;
  static const _maxSize = 0.92;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _move(Offset delta, Size boardSize) {
    setState(() {
      final nextCx = (_draft.cx + delta.dx / boardSize.width)
          .clamp(_draft.w / 2, 1 - _draft.w / 2);
      final nextCy = (_draft.cy + delta.dy / boardSize.height)
          .clamp(_draft.h / 2, 1 - _draft.h / 2);
      _draft = _draft.copyWith(cx: nextCx, cy: nextCy);
    });
  }

  void _resize(Offset delta, Size boardSize) {
    setState(() {
      final nextW = (_draft.w + delta.dx * 2 / boardSize.width)
          .clamp(_minSize, _maxSize);
      final nextH = (_draft.h + delta.dy * 2 / boardSize.height)
          .clamp(_minSize, _maxSize);
      final cx = _draft.cx.clamp(nextW / 2, 1 - nextW / 2);
      final cy = _draft.cy.clamp(nextH / 2, 1 - nextH / 2);
      _draft = _draft.copyWith(w: nextW, h: nextH, cx: cx, cy: cy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_draft.kind.color);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: AppRadius.brLarge,
            boxShadow: AppShadow.lifted,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: AppGap.md),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  widget.allowDelete ? 'Edit zone' : 'New zone',
                  style: AppText.title,
                ),
                const SizedBox(height: 4),
                Text(
                  'Drag the frame to move it, pull the corner to resize.',
                  style: AppText.body,
                ),
                const SizedBox(height: AppGap.md),
                AspectRatio(
                  aspectRatio: 0.72,
                  child: ClipRRect(
                    borderRadius: AppRadius.brMedium,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(widget.themeAsset, fit: BoxFit.cover),
                            Positioned(
                              left: (_draft.cx - _draft.w / 2) *
                                  boardSize.width,
                              top: (_draft.cy - _draft.h / 2) *
                                  boardSize.height,
                              width: _draft.w * boardSize.width,
                              height: _draft.h * boardSize.height,
                              child: GestureDetector(
                                onPanUpdate: (details) =>
                                    _move(details.delta, boardSize),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.24),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: color, width: 2.5),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Text(
                                          _nameController.text.isEmpty
                                              ? 'Zone'
                                              : _nameController.text,
                                          textAlign: TextAlign.center,
                                          style: AppText.bodyStrong.copyWith(
                                            color: Colors.white,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xAA14330F),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: GestureDetector(
                                          onPanUpdate: (details) =>
                                              _resize(details.delta, boardSize),
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.open_in_full_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppGap.lg),
                Text('Name', style: AppText.label),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 28,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.paper,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.brSmall,
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.brSmall,
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: AppGap.md),
                Text('Purpose', style: AppText.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: AppGap.sm,
                  runSpacing: AppGap.sm,
                  children: [
                    for (final kind in ZoneKind.values)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _draft = _draft.copyWith(kind: kind)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: kind == _draft.kind
                                ? Color(kind.color)
                                : AppColors.shell,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            kind.label,
                            style: AppText.label.copyWith(
                              color: kind == _draft.kind
                                  ? Colors.white
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppGap.lg),
                PillButton(
                  label: widget.allowDelete ? 'Save changes' : 'Create zone',
                  icon: Icons.check_rounded,
                  expand: true,
                  onPressed: () {
                    final name = _nameController.text.trim();
                    Navigator.of(context).pop(
                      _draft.copyWith(name: name.isEmpty ? 'Zone' : name),
                    );
                  },
                ),
                if (widget.allowDelete) ...[
                  const SizedBox(height: AppGap.sm),
                  PillButton(
                    label: 'Delete zone',
                    icon: Icons.delete_outline_rounded,
                    tone: PillTone.danger,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(
                      ZoneDraft(
                        name: _draft.name,
                        kind: _draft.kind,
                        cx: _draft.cx,
                        cy: _draft.cy,
                        w: _draft.w,
                        h: _draft.h,
                        deleted: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/pasture_repository.dart';
import '../../domain/catalog.dart';
import '../../domain/models.dart';

/// Renders the pasture layout and turns taps and drags into normalised
/// coordinates. It holds no business logic: the parent decides what a gesture
/// means.
class PastureBoard extends StatefulWidget {
  const PastureBoard({
    super.key,
    required this.snapshot,
    required this.backgroundAsset,
    required this.showZones,
    required this.onTapEmpty,
    required this.onTapObject,
    required this.onTapEgg,
    required this.onMoveObject,
    required this.onMoveEgg,
    this.highlightZoneId,
  });

  final PastureSnapshot snapshot;
  final String backgroundAsset;
  final bool showZones;
  final void Function(double x, double y) onTapEmpty;
  final void Function(PastureObject object) onTapObject;
  final void Function(EggMark egg) onTapEgg;
  final void Function(PastureObject object, double x, double y) onMoveObject;
  final void Function(EggMark egg, double x, double y) onMoveEgg;
  final int? highlightZoneId;

  @override
  State<PastureBoard> createState() => _PastureBoardState();
}

class _PastureBoardState extends State<PastureBoard> {
  static const _edgeInset = 0.045;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        final objects = [...widget.snapshot.objects]
          ..sort((a, b) => a.y.compareTo(b.y));
        final eggs = widget.snapshot.pendingEggs;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final dx = (details.localPosition.dx / size.width)
                .clamp(_edgeInset, 1 - _edgeInset);
            final dy = (details.localPosition.dy / size.height)
                .clamp(_edgeInset, 1 - _edgeInset);
            widget.onTapEmpty(dx, dy);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The background never changes while pieces move, so isolating
              // its layer stops it from repainting during a drag.
              RepaintBoundary(
                child: Image.asset(widget.backgroundAsset, fit: BoxFit.cover),
              ),
              if (widget.showZones)
                for (final zone in widget.snapshot.zones)
                  _ZoneFrame(
                    zone: zone,
                    size: size,
                    highlighted: zone.id == widget.highlightZoneId,
                  ),
              for (final object in objects)
                _DraggablePiece(
                  key: ValueKey('object-${object.id}'),
                  boardSize: size,
                  position: Offset(object.x, object.y),
                  width: object.item.width,
                  asset: object.item.asset,
                  onTap: () => widget.onTapObject(object),
                  onCommit: (x, y) => widget.onMoveObject(object, x, y),
                ),
              for (final egg in eggs)
                _DraggablePiece(
                  key: ValueKey('egg-${egg.id}'),
                  boardSize: size,
                  position: Offset(egg.x, egg.y),
                  width: 42,
                  asset: egg.type.asset,
                  pulsing: true,
                  onTap: () => widget.onTapEgg(egg),
                  onCommit: (x, y) => widget.onMoveEgg(egg, x, y),
                ),
              // Labels ride above the pieces so a hen standing in the corner
              // never hides the name of the zone she is in.
              if (widget.showZones)
                for (final zone in widget.snapshot.zones)
                  _ZoneLabel(zone: zone, size: size),
            ],
          ),
        );
      },
    );
  }
}

class _ZoneFrame extends StatelessWidget {
  const _ZoneFrame({
    required this.zone,
    required this.size,
    required this.highlighted,
  });

  final PastureZone zone;
  final Size size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = Color(zone.kind.color);
    // Plain DecoratedBox avoids creating an implicit AnimationController
    // per zone. Highlighting changes are infrequent so animation is skipped.
    return Positioned(
      left: zone.left * size.width,
      top: zone.top * size.height,
      width: zone.w * size.width,
      height: zone.h * size.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(highlighted ? 66 : 33),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withAlpha(highlighted ? 242 : 140),
              width: highlighted ? 2.5 : 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.zone, required this.size});

  final PastureZone zone;
  final Size size;

  @override
  Widget build(BuildContext context) {
    // withAlpha keeps the label background opaque enough to read without the
    // per-build Color.withValues() allocation this hot path used to make.
    final labelColor = Color(zone.kind.color).withAlpha(240);
    // The label straddles the top edge of its frame, the way a fieldset
    // legend sits in its border. That keeps it out of the area where pieces
    // actually stand, so a hen near the corner never collides with a name.
    return Positioned(
      left: zone.left * size.width + 12,
      top: zone.top * size.height - 12,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: labelColor,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withAlpha(215), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            zone.name,
            style: AppText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggablePiece extends StatefulWidget {
  const _DraggablePiece({
    super.key,
    required this.boardSize,
    required this.position,
    required this.width,
    required this.asset,
    required this.onTap,
    required this.onCommit,
    this.pulsing = false,
  });

  final Size boardSize;
  final Offset position;
  final double width;
  final String asset;
  final VoidCallback onTap;
  final void Function(double x, double y) onCommit;
  final bool pulsing;

  @override
  State<_DraggablePiece> createState() => _DraggablePieceState();
}

class _DraggablePieceState extends State<_DraggablePiece>
    with SingleTickerProviderStateMixin {
  static const _edgeInset = 0.045;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _dragging = false;

  /// While dragging, the piece tracks its own live position and only writes
  /// back to the board when the finger lifts. This keeps a drag confined to
  /// this single widget instead of rebuilding the whole board every frame.
  late Offset _live = widget.position;

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_DraggablePiece old) {
    super.didUpdateWidget(old);
    if (!_dragging && widget.position != old.position) {
      _live = widget.position;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value) => Offset(
        value.dx.clamp(_edgeInset, 1 - _edgeInset),
        value.dy.clamp(_edgeInset, 1 - _edgeInset),
      );

  /// Catalog widths are authored against a 430pt-wide board. Scaling to the
  /// actual board keeps the same proportions on a narrow phone, where fixed
  /// sizes made a single hen cover a quarter of the screen and collide with
  /// her neighbours.
  double get _scaledWidth {
    final factor = (widget.boardSize.width / 430).clamp(0.62, 1.25);
    return widget.width * factor;
  }

  @override
  Widget build(BuildContext context) {
    final pos = _dragging ? _live : widget.position;
    final width = _scaledWidth;
    final left = pos.dx * widget.boardSize.width - width / 2;
    final top = pos.dy * widget.boardSize.height - width / 2;

    return Positioned(
      left: left,
      top: top,
      width: width,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: (_) {
            setState(() {
              _dragging = true;
              _live = widget.position;
            });
          },
          onPanUpdate: (details) => setState(() {
            _live = _clamp(Offset(
              _live.dx + details.delta.dx / widget.boardSize.width,
              _live.dy + details.delta.dy / widget.boardSize.height,
            ));
          }),
          onPanEnd: (_) {
            final target = _live;
            setState(() => _dragging = false);
            widget.onCommit(target.dx, target.dy);
          },
          child: AnimatedScale(
            scale: _dragging ? 1.12 : 1,
            duration: const Duration(milliseconds: 140),
            child: widget.pulsing
                ? FadeTransition(
                    opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
                    child: _sprite(),
                  )
                : _sprite(),
          ),
        ),
      ),
    );
  }

  Widget _sprite() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = _scaledWidth;
    final img = Image.asset(
      widget.asset,
      width: width,
      fit: BoxFit.contain,
      cacheWidth: (width * dpr).round(),
    );
    // BoxShadow requires a GPU saveLayer every time the layer is rasterised.
    // Only pay that cost while the piece is actively being dragged; at rest
    // the sprite is composited from its cached raster layer with no shadow.
    if (!_dragging) return img;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x59142B0F),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: img,
    );
  }
}

/// Small preview of an item, shared by the catalog and the customization
/// screen.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, required this.asset, this.size = 54});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        cacheWidth: (size * dpr).round(),
      ),
    );
  }
}

/// Colour associated with a catalog category, reused in badges and filters.
Color categoryColor(ItemCategory category) => switch (category) {
      ItemCategory.chicken => AppColors.amber,
      ItemCategory.nest => AppColors.bark,
      ItemCategory.equipment => AppColors.water,
      ItemCategory.decor => AppColors.meadow,
    };

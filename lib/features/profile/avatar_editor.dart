import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';

/// Square crop editor with pinch-to-zoom and drag, written in-app so the
/// avatar flow needs no extra native cropper dependency.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({super.key, required this.sourceFile});

  final File sourceFile;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  static const _outputSize = 512;

  ui.Image? _image;
  Object? _error;

  double _zoom = 1;
  double _startZoom = 1;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Size _viewport = Size.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final bytes = await widget.sourceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  double get _baseScale {
    final image = _image!;
    return math.max(
      _viewport.width / image.width,
      _viewport.height / image.height,
    );
  }

  Offset _clampOffset(Offset value, double scale) {
    final image = _image!;
    final displayed = Size(image.width * scale, image.height * scale);
    final minDx = _viewport.width - displayed.width;
    final minDy = _viewport.height - displayed.height;
    return Offset(
      value.dx.clamp(math.min(minDx, 0.0), 0.0),
      value.dy.clamp(math.min(minDy, 0.0), 0.0),
    );
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);

    final scale = _baseScale * _zoom;
    final source = Rect.fromLTWH(
      -_offset.dx / scale,
      -_offset.dy / scale,
      _viewport.width / scale,
      _viewport.height / scale,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, _outputSize.toDouble(), _outputSize.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(_outputSize, _outputSize);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    cropped.dispose();

    if (data == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    final path = await _writeAvatar(data.buffer.asUint8List());
    if (mounted) Navigator.of(context).pop(path);
  }

  static Future<String> _writeAvatar(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'profile'));
    if (!folder.existsSync()) folder.createSync(recursive: true);

    // A fresh file name each time keeps Flutter's image cache from serving the
    // previous avatar.
    for (final stale in folder.listSync()) {
      if (stale is File && p.basename(stale.path).startsWith('avatar_')) {
        stale.deleteSync();
      }
    }
    final file = File(p.join(
      folder.path,
      'avatar_${DateTime.now().millisecondsSinceEpoch}.png',
    ));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.barkDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Adjust your photo',
                      style: AppText.title.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyHint(
                          icon: Icons.image_not_supported_outlined,
                          title: 'This image could not be opened',
                          message: 'Pick a different photo and try again.',
                        ),
                      )
                    : _image == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _buildCropArea(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Drag to reposition, pinch to zoom.',
                    style: AppText.caption.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppGap.md),
                  PillButton(
                    label: _saving ? 'Saving…' : 'Use this photo',
                    icon: Icons.check_rounded,
                    expand: true,
                    onPressed: _image == null || _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth - 40, constraints.maxHeight - 40);
        final viewport = Size(side, side);
        if (_viewport != viewport) {
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _offset = _centeredOffset(_baseScale * _zoom);
            });
          });
        }

        return GestureDetector(
          onScaleStart: (details) {
            _startZoom = _zoom;
            _startOffset = _offset - details.localFocalPoint;
          },
          onScaleUpdate: (details) {
            setState(() {
              _zoom = (_startZoom * details.scale).clamp(1.0, 5.0);
              final scale = _baseScale * _zoom;
              final proposed = _startOffset + details.localFocalPoint;
              _offset = _clampOffset(proposed, scale);
            });
          },
          child: ClipOval(
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Positioned(
                    left: _offset.dx,
                    top: _offset.dy,
                    width: _image!.width * _baseScale * _zoom,
                    height: _image!.height * _baseScale * _zoom,
                    child: RawImage(image: _image, fit: BoxFit.fill),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Offset _centeredOffset(double scale) {
    final image = _image!;
    return Offset(
      (_viewport.width - image.width * scale) / 2,
      (_viewport.height - image.height * scale) / 2,
    );
  }
}

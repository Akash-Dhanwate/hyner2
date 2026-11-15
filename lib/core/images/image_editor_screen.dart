import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../features/settings/presentation/settings_image_helper.dart';

/// Bounded raster editing. The caller owns persistence; Cancel never changes it.
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({
    super.key,
    required this.bytes,
    required this.title,
    this.profile = false,
    this.signature = false,
  });
  final Uint8List bytes;
  final String title;
  final bool profile, signature;
  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  ui.Image? _image;
  double _zoom = 1, _startZoom = 1;
  Offset _offset = Offset.zero,
      _startOffset = Offset.zero,
      _startFocal = Offset.zero;
  late double _ratio = widget.signature ? 2.6 : 1;
  Size _viewport = Size.zero;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await prepareSettingsImage(widget.bytes);
      final codec = await ui.instantiateImageCodec(bytes);
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'This image cannot be opened. Choose a PNG, JPEG or WebP up to 8 MB.';
        });
      }
    }
  }

  void _reset() {
    _zoom = 1;
    _offset = Offset.zero;
  }

  double _scale(ui.Image image) =>
      math.max(_viewport.width / image.width, _viewport.height / image.height) *
      _zoom;
  Offset _clamp(Offset value) {
    final image = _image;
    if (image == null || _viewport.isEmpty) return Offset.zero;
    final scale = _scale(image);
    final x = math.max(0.0, (image.width * scale - _viewport.width) / 2);
    final y = math.max(0.0, (image.height * scale - _viewport.height) / 2);
    return Offset(value.dx.clamp(-x, x), value.dy.clamp(-y, y));
  }

  Rect _source(ui.Image image) {
    final scale = _scale(image);
    final offset = _clamp(_offset);
    final w = math.min(image.width.toDouble(), _viewport.width / scale);
    final h = math.min(image.height.toDouble(), _viewport.height / scale);
    return Rect.fromLTWH(
      ((image.width - w) / 2 - offset.dx / scale).clamp(0.0, image.width - w),
      ((image.height - h) / 2 - offset.dy / scale).clamp(0.0, image.height - h),
      w,
      h,
    );
  }

  Future<void> _rotate() async {
    final image = _image;
    if (_busy || image == null) return;
    setState(() => _busy = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(image.height.toDouble(), 0)
        ..rotate(math.pi / 2);
      canvas.drawImage(image, Offset.zero, Paint());
      final picture = recorder.endRecording();
      ui.Image rotated;
      try {
        rotated = await picture.toImage(image.height, image.width);
      } finally {
        picture.dispose();
      }
      if (!mounted) {
        rotated.dispose();
        return;
      }
      setState(() {
        _image = rotated;
        _reset();
      });
      image.dispose();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The image could not be rotated. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final image = _image;
    if (_busy || image == null || _viewport.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final src = _source(image);
      final maxEdge = widget.profile ? 512 : 1024;
      final outputScale = math.min(
        1.0,
        maxEdge / math.max(src.width, src.height),
      );
      final width = math.max(1, (src.width * outputScale).round());
      final height = math.max(1, (src.height * outputScale).round());
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      ui.Image result;
      try {
        result = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
      ByteData? data;
      try {
        data = await result.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        result.dispose();
      }
      if (data == null || data.lengthInBytes > maxSavedSettingsImageBytes) {
        throw const FormatException();
      }
      if (mounted) {
        Navigator.pop(
          context,
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'This crop could not be saved. Try a smaller crop.';
        });
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Drag to position. Pinch or use the slider to zoom.',
                ),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                if (image != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(
                        constraints.maxWidth,
                        math.min(
                          480.0,
                          math.min(
                                400.0,
                                MediaQuery.sizeOf(context).height * .55,
                              ) *
                              _ratio,
                        ),
                      );
                      _viewport = Size(width, width / _ratio);
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: _viewport.height,
                          child: Semantics(
                            label: widget.profile
                                ? 'Circular profile photo preview'
                                : widget.signature
                                ? 'Signature preview as shown on documents'
                                : 'Logo crop preview',
                            image: true,
                            child: GestureDetector(
                              key: const Key('image-crop-area'),
                              onScaleStart: _busy
                                  ? null
                                  : (details) {
                                      _startZoom = _zoom;
                                      _startOffset = _offset;
                                      _startFocal = details.localFocalPoint;
                                    },
                              onScaleUpdate: _busy
                                  ? null
                                  : (details) => setState(() {
                                      _zoom = (_startZoom * details.scale)
                                          .clamp(1.0, 5.0);
                                      _offset = _clamp(
                                        _startOffset +
                                            details.localFocalPoint -
                                            _startFocal,
                                      );
                                    }),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  widget.profile ? width : 4,
                                ),
                                child: CustomPaint(
                                  painter: _CropPainter(image, _source(image)),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Zoom ${_zoom.toStringAsFixed(1)}×'),
                  Slider(
                    key: const Key('image-zoom'),
                    value: _zoom,
                    min: 1,
                    max: 5,
                    semanticFormatterCallback: (v) =>
                        '${v.toStringAsFixed(1)} times zoom',
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _zoom = v;
                            _offset = _clamp(_offset);
                          }),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final move in [
                        (
                          Icons.arrow_back,
                          const Offset(-24, 0),
                          'Move image left',
                        ),
                        (
                          Icons.arrow_forward,
                          const Offset(24, 0),
                          'Move image right',
                        ),
                        (
                          Icons.arrow_upward,
                          const Offset(0, -24),
                          'Move image up',
                        ),
                        (
                          Icons.arrow_downward,
                          const Offset(0, 24),
                          'Move image down',
                        ),
                      ])
                        IconButton(
                          tooltip: move.$3,
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _offset = _clamp(_offset + move.$2),
                                ),
                          icon: Icon(move.$1),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final move in [
                        (
                          Icons.arrow_back,
                          const Offset(-24, 0),
                          'Move image left',
                        ),
                        (
                          Icons.arrow_forward,
                          const Offset(24, 0),
                          'Move image right',
                        ),
                        (
                          Icons.arrow_upward,
                          const Offset(0, -24),
                          'Move image up',
                        ),
                        (
                          Icons.arrow_downward,
                          const Offset(0, 24),
                          'Move image down',
                        ),
                      ])
                        IconButton(
                          tooltip: move.$3,
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _offset = _clamp(_offset + move.$2),
                                ),
                          icon: Icon(move.$1),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('rotate-image'),
                        onPressed: _busy ? null : _rotate,
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Rotate'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => setState(_reset),
                        child: const Text('Reset crop'),
                      ),
                    ],
                  ),
                  if (!widget.profile) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in [
                          (1.0, 'Square'),
                          (2.6, 'Wide'),
                          (image.width / image.height, 'Full image'),
                        ])
                          ChoiceChip(
                            label: Text(choice.$2),
                            selected: _ratio == choice.$1,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _ratio = choice.$1;
                                    _reset();
                                  }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('use-edited-image'),
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Use this image'),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.source != source;
}

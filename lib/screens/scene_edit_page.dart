import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_media_assets.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart';
import '../widgets/post_crop_preview.dart';

enum _SceneEditTool { size, crop, adjust }

/// Scene-only edit step (Figma 2756:10720) plus Size / Crop / Adjust panels.
class SceneEditPage extends StatefulWidget {
  const SceneEditPage({
    super.key,
    this.imagePath,
    this.videoThumbnailBytes,
    this.initialTransform,
    this.showSizeTool = true,
    this.lockedAspectRatio,
    required this.onBack,
    required this.onNext,
  });

  final String? imagePath;
  final Uint8List? videoThumbnailBytes;
  final PostImageTransform? initialTransform;
  /// Scene Size tool (aspect chips). Event posting locks 3:4 and hides this.
  final bool showSizeTool;
  final CropAspectRatio? lockedAspectRatio;
  final VoidCallback onBack;
  final ValueChanged<PostImageTransform> onNext;

  @override
  State<SceneEditPage> createState() => _SceneEditPageState();
}

class _SceneEditPageState extends State<SceneEditPage> {
  static const _bannerHeight = 53.0;
  static const _previewRadius = 8.0;
  static const _orange = Color(0xFFE07020);
  static const _chipFill = Color(0xFFE8E6DF);

  late PostImageTransform _transform;
  PostImageTransform? _toolSnapshot;
  _SceneEditTool? _openTool;
  double _imageAspect = 3 / 4;
  bool _imageAspectReady = false;

  Rect? _gestureStartBox;
  Offset _gestureStartFocalPoint = Offset.zero;

  AdjustSubTool? _adjustSub;
  bool _showAdjustValue = false;

  bool get _hasImage =>
      widget.imagePath != null && widget.imagePath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final locked = widget.lockedAspectRatio;
    _transform = (widget.initialTransform ??
            PostImageTransform(
              aspectRatio: locked ?? CropAspectRatio.ratio9x16,
            ))
        .copy();
    if (locked != null) _transform.aspectRatio = locked;
    _transform.fitMode = CropFitMode.fill;
    _loadImageAspect();
  }

  Future<void> _loadImageAspect() async {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) return;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _imageAspect = frame.image.width / frame.image.height;
        if (!_imageAspectReady) {
          _imageAspectReady = true;
          _syncCropToSelectedAspect(forceMaxFill: true);
        }
      });
    } catch (_) {}
  }

  void _open(_SceneEditTool tool) {
    setState(() {
      _toolSnapshot = _transform.copy();
      _openTool = tool;
      if (tool == _SceneEditTool.size || tool == _SceneEditTool.crop) {
        _syncCropToSelectedAspect();
      }
      if (tool == _SceneEditTool.adjust) {
        _adjustSub = null;
        _showAdjustValue = false;
      }
    });
  }

  /// Keeps the crop box locked to the Size-selected ratio so Crop pans/zooms
  /// inside that frame instead of stretching a leftover box.
  void _syncCropToSelectedAspect({bool forceMaxFill = false}) {
    _transform.fitMode = CropFitMode.fill;
    final cropAspect = _transform.aspectRatio.value;
    final box = _transform.resolvedCropRect(_imageAspect);
    final expectedK = cropAspect / _imageAspect;
    final boxK = box.height == 0 ? 0.0 : box.width / box.height;
    final matches = (boxK - expectedK).abs() <= expectedK.abs() * 0.02 + 0.002;
    if (forceMaxFill || !matches) {
      _transform.cropRect = CropCoverMath.defaultFillBox(
        cropAspect,
        _imageAspect,
      );
    }
  }

  void _cancelTool() {
    setState(() {
      if (_toolSnapshot != null) _transform = _toolSnapshot!.copy();
      _toolSnapshot = null;
      _openTool = null;
    });
  }

  void _doneTool() {
    setState(() {
      _toolSnapshot = null;
      _openTool = null;
    });
  }

  void _setAspect(CropAspectRatio ratio) {
    if (_transform.aspectRatio == ratio) return;
    setState(() {
      _transform.aspectRatio = ratio;
      _transform.fitMode = CropFitMode.fill;
      // Always the largest fill for this ratio. Relocking the previous box
      // shrinks it on every switch and looks like a cumulative zoom.
      _transform.cropRect = CropCoverMath.defaultFillBox(
        ratio.value,
        _imageAspect,
      );
    });
  }

  void _onCropScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _transform.resolvedCropRect(_imageAspect);
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onCropScaleUpdate(ScaleUpdateDetails details, Size frameSize) {
    final startBox = _gestureStartBox;
    if (startBox == null) return;
    final cropAspect = _transform.aspectRatio.value;
    final focalDelta = details.localFocalPoint - _gestureStartFocalPoint;
    final dxNorm = frameSize.width == 0
        ? 0.0
        : focalDelta.dx / frameSize.width * startBox.width;
    final dyNorm = frameSize.height == 0
        ? 0.0
        : focalDelta.dy / frameSize.height * startBox.height;
    final panned = CropCoverMath.translateBox(
      box: startBox,
      deltaNorm: -Offset(dxNorm, dyNorm),
    );
    final scaled = CropCoverMath.scaleBox(
      box: panned,
      scaleFactor: details.scale,
      cropAspect: cropAspect,
      imageAspect: _imageAspect,
    );
    final positioned = CropCoverMath.translateBox(
      box: scaled,
      deltaNorm: Offset.zero,
    );
    setState(() {
      _transform.fitMode = CropFitMode.fill;
      _transform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: positioned,
        rotationDegrees: _transform.rotationDegrees,
        imageAspect: _imageAspect,
      );
    });
  }

  void _onCropScaleEnd(ScaleEndDetails details) {
    _gestureStartBox = null;
  }

  void _rotate90() {
    setState(() {
      _transform.rotationDegrees = (_transform.rotationDegrees + 90) % 360;
      _transform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: _transform.resolvedCropRect(_imageAspect),
        rotationDegrees: _transform.rotationDegrees,
        imageAspect: _imageAspect,
      );
    });
  }

  void _flip() {
    setState(() {
      _transform.flipHorizontal = !_transform.flipHorizontal;
    });
  }

  void _onAdjustSubToolTap(AdjustSubTool tool) {
    setState(() {
      _adjustSub = tool;
      _showAdjustValue = false;
    });
  }

  void _onAdjustValueChanged(double value) {
    final sub = _adjustSub;
    if (sub == null) return;
    setState(() {
      _transform.setAdjustValue(sub, value);
      _showAdjustValue = true;
    });
  }

  void _onAdjustDragEnd() {
    setState(() => _showAdjustValue = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showAdjustValue = false);
    });
  }

  TextStyle get _bannerStyle => GoogleFonts.geist(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: HomeFeedTokens.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openTool == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelTool();
      },
      child: _openTool != null ? _buildToolPage(_openTool!) : _buildHome(),
    );
  }

  Widget _buildHome() {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _banner(
            topInset: topInset,
            leading: GestureDetector(
              onTap: widget.onBack,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 7,
                height: 14,
                child: OverflowBox(
                  maxWidth: 9,
                  maxHeight: 16,
                  child: SvgPicture.asset(
                    PostMediaAssets.sceneEditBack,
                    width: 9,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      HomeFeedTokens.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            title: 'Edit',
            trailing: GestureDetector(
              onTap: () => widget.onNext(_transform.copy()),
              behavior: HitTestBehavior.opaque,
              child: Text('Next', style: _bannerStyle),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: _aspectFrame(child: _mediaPreview()),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(32, 12, 32, 16 + bottomInset),
            child: Row(
              mainAxisAlignment: widget.showSizeTool
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.showSizeTool)
                  _LabeledIcon(
                    asset: PostMediaAssets.sceneEditSize,
                    label: 'Size',
                    onTap: () => _open(_SceneEditTool.size),
                  ),
                _LabeledIcon(
                  asset: PostMediaAssets.sceneEditCrop,
                  label: 'Crop',
                  onTap: () => _open(_SceneEditTool.crop),
                ),
                _LabeledIcon(
                  asset: PostMediaAssets.sceneEditAdjust,
                  label: 'Adjust',
                  onTap: () => _open(_SceneEditTool.adjust),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPage(_SceneEditTool tool) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _banner(
            topInset: topInset,
            leading: GestureDetector(
              onTap: _cancelTool,
              behavior: HitTestBehavior.opaque,
              child: Text('Cancel', style: _bannerStyle),
            ),
            trailing: GestureDetector(
              onTap: _doneTool,
              behavior: HitTestBehavior.opaque,
              child: Text('Done', style: _bannerStyle),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _toolPreview(tool),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
            child: switch (tool) {
              _SceneEditTool.size => _sizeBar(),
              _SceneEditTool.crop => _cropBar(),
              _SceneEditTool.adjust => _adjustBar(),
            },
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required double topInset,
    required Widget leading,
    String? title,
    required Widget trailing,
  }) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _bannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(children: [leading, const Spacer(), trailing]),
                if (title != null) Text(title, style: _bannerStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Size _frameSizeFor(BoxConstraints constraints) {
    final ratio = _transform.aspectRatio.value;
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
      return Size.zero;
    }
    var width = constraints.maxWidth;
    var height = width / ratio;
    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * ratio;
    }
    return Size(width, height);
  }

  Widget _aspectFrame({
    required Widget child,
    bool orangeBorder = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _frameSizeFor(constraints);
        return Center(
          child: SizedBox(
            width: frame.width,
            height: frame.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_previewRadius),
                border: orangeBorder
                    ? Border.all(color: _orange, width: 3)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  orangeBorder ? 5 : _previewRadius,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toolPreview(_SceneEditTool tool) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _frameSizeFor(constraints);
        return Center(
          child: SizedBox(
            width: frame.width,
            height: frame.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_previewRadius),
                border: tool == _SceneEditTool.size
                    ? Border.all(color: _orange, width: 3)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  tool == _SceneEditTool.size ? 5 : _previewRadius,
                ),
                child: Builder(
                  builder: (context) {
                    Widget content = Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_hasImage)
                          PostCropPreview.buildTransformedContent(
                            imagePath: widget.imagePath!,
                            transform: _transform,
                            imageAspect: _imageAspect,
                          )
                        else
                          _mediaPreview(),
                        if (tool == _SceneEditTool.crop)
                          const IgnorePointer(child: _RuleOfThirdsGrid()),
                        if (tool == _SceneEditTool.adjust &&
                            _adjustSub != null &&
                            _showAdjustValue)
                          IgnorePointer(
                            child: _AdjustValueOverlay(
                              text: _transform
                                  .adjustValueFor(_adjustSub!)
                                  .round()
                                  .toString(),
                            ),
                          ),
                      ],
                    );
                    if (tool == _SceneEditTool.crop && _hasImage) {
                      content = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onCropScaleStart,
                        onScaleUpdate: (d) => _onCropScaleUpdate(d, frame),
                        onScaleEnd: _onCropScaleEnd,
                        child: content,
                      );
                    }
                    return content;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mediaPreview() {
    if (_hasImage) {
      return PostCropPreview.buildTransformedContent(
        imagePath: widget.imagePath!,
        transform: _transform,
        imageAspect: _imageAspect,
      );
    }
    if (widget.videoThumbnailBytes != null) {
      return Image.memory(
        widget.videoThumbnailBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return const ColoredBox(color: HomeFeedTokens.skeletonBase);
  }

  Widget _sizeBar() {
    const ratios = [
      CropAspectRatio.ratio16x9,
      CropAspectRatio.ratio9x16,
      CropAspectRatio.ratio3x4,
      CropAspectRatio.ratio1x1,
    ];
    return Row(
      children: [
        const _SquareIcon(
          selected: true,
          child: Icon(
            Icons.crop_5_4,
            size: 16,
            color: HomeFeedTokens.textInverse,
          ),
        ),
        for (final ratio in ratios) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _AspectChip(
              label: switch (ratio) {
                CropAspectRatio.ratio16x9 => '16:9',
                CropAspectRatio.ratio9x16 => '9:16',
                CropAspectRatio.ratio3x4 => '3:4',
                CropAspectRatio.ratio1x1 => '1:1',
              },
              selected: _transform.aspectRatio == ratio,
              onTap: () => _setAspect(ratio),
            ),
          ),
        ],
      ],
    );
  }

  Widget _cropBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SvgPicture.asset(PostMediaAssets.sceneEditCrop, width: 32, height: 32),
        _SquareIcon(
          selected: false,
          onTap: _rotate90,
          child: Icon(
            Icons.crop_rotate,
            size: 18,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        _SquareIcon(
          selected: false,
          onTap: _flip,
          child: Icon(Icons.flip, size: 18, color: HomeFeedTokens.textPrimary),
        ),
      ],
    );
  }

  Widget _adjustBar() {
    final sub = _adjustSub;
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: sub == null
              ? null
              : Center(
                  child: _AdjustDial(
                    value: _transform.adjustValueFor(sub),
                    onChanged: _onAdjustValueChanged,
                    onDragEnd: _onAdjustDragEnd,
                  ),
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset(
              PostMediaAssets.sceneEditAdjust,
              width: 32,
              height: 32,
            ),
            _SquareIcon(
              selected: sub == AdjustSubTool.brightness,
              onTap: () => _onAdjustSubToolTap(AdjustSubTool.brightness),
              child: Icon(
                Icons.wb_sunny_outlined,
                size: 18,
                color: sub == AdjustSubTool.brightness
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
              ),
            ),
            _SquareIcon(
              selected: sub == AdjustSubTool.contrast,
              onTap: () => _onAdjustSubToolTap(AdjustSubTool.contrast),
              child: Icon(
                Icons.contrast,
                size: 18,
                color: sub == AdjustSubTool.contrast
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
              ),
            ),
            _SquareIcon(
              selected: sub == AdjustSubTool.exposure,
              onTap: () => _onAdjustSubToolTap(AdjustSubTool.exposure),
              child: Icon(
                Icons.exposure_outlined,
                size: 18,
                color: sub == AdjustSubTool.exposure
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabeledIcon extends StatelessWidget {
  const _LabeledIcon({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(asset, width: 32, height: 32),
          Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({required this.selected, required this.child, this.onTap});

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: selected
              ? HomeFeedTokens.textPrimary
              : _SceneEditPageState._chipFill,
          child: SizedBox(width: 32, height: 32, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _AspectChip extends StatelessWidget {
  const _AspectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? HomeFeedTokens.textPrimary
              : _SceneEditPageState._chipFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? HomeFeedTokens.textInverse
                : HomeFeedTokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _RuleOfThirdsGrid extends StatelessWidget {
  const _RuleOfThirdsGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdjustValueOverlay extends StatelessWidget {
  const _AdjustValueOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textInverse,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _AdjustDial extends StatelessWidget {
  const _AdjustDial({
    required this.value,
    required this.onChanged,
    required this.onDragEnd,
  });

  static const _valuePerPixel = 0.5;

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return _TickDial(
      offsetX: -(value - 50) / _valuePerPixel,
      onHorizontalDragUpdate: (deltaDx) {
        onChanged((value - deltaDx * _valuePerPixel).clamp(0.0, 100.0));
      },
      onDragEnd: onDragEnd,
    );
  }
}

class _TickDial extends StatelessWidget {
  const _TickDial({
    required this.offsetX,
    required this.onHorizontalDragUpdate,
    required this.onDragEnd,
  });

  static const _dialWidth = 160.0;
  static const _dialHeight = 12.0;

  final double offsetX;
  final ValueChanged<double> onHorizontalDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dialWidth,
      height: 28,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                onHorizontalDragUpdate(details.delta.dx);
              },
              onHorizontalDragEnd: (_) => onDragEnd(),
              child: ClipRect(
                child: CustomPaint(
                  size: const Size(_dialWidth, _dialHeight),
                  painter: _TickDialPainter(offsetX: offsetX),
                ),
              ),
            ),
          ),
          Positioned(
            top: _dialHeight + 2,
            child: Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textPrimary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickDialPainter extends CustomPainter {
  const _TickDialPainter({required this.offsetX});

  static const _tickSpacing = 6.0;
  static const _baselineY = 11.625;

  final double offsetX;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final paint = Paint()
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;

    for (var i = -14; i <= 14; i++) {
      final x = centerX + i * _tickSpacing + offsetX;
      if (x < 2 || x > size.width - 2) continue;

      final dist = (x - centerX).abs();
      final height = (11.0 - dist * 0.18).clamp(3.0, 11.0);
      final opacity = (1.0 - dist * 0.025).clamp(0.35, 1.0);
      paint.color = HomeFeedTokens.textPrimary.withValues(alpha: opacity);

      canvas.drawLine(
        Offset(x, _baselineY),
        Offset(x, _baselineY - height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TickDialPainter oldDelegate) =>
      oldDelegate.offsetX != offsetX;
}

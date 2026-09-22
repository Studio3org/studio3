import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/post_media_assets.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart';
import '../widgets/post_crop_preview.dart';
import '../theme/app_fonts.dart';

enum _PieceEditTool { fitFill, crop, adjust }

/// Piece per-image editor (opened from the cover-page pencil). 3:4 only,
/// Fit/Fill, Crop, and Adjust — same chrome as scene Edit.
class PieceSceneStyleEditor extends StatefulWidget {
  const PieceSceneStyleEditor({
    super.key,
    required this.imagePath,
    required this.transform,
    required this.imageAspect,
  });

  final String imagePath;
  final PostImageTransform transform;
  final double imageAspect;

  @override
  State<PieceSceneStyleEditor> createState() => _PieceSceneStyleEditorState();
}

class _PieceSceneStyleEditorState extends State<PieceSceneStyleEditor> {
  static const _bannerHeight = 53.0;
  static const _previewRadius = 8.0;
  static const _orange = Color(0xFFE07020);
  static const _chipFill = Color(0xFFE8E6DF);

  late PostImageTransform _transform;
  _PieceEditTool? _openTool;
  PostImageTransform? _toolSnapshot;
  AdjustSubTool? _adjustSub;
  bool _showAdjustValue = false;

  Rect? _gestureStartBox;
  Offset _gestureStartFocalPoint = Offset.zero;

  double get _imageAspect => widget.imageAspect;

  @override
  void initState() {
    super.initState();
    _transform = widget.transform.copy();
    _transform.aspectRatio = CropAspectRatio.ratio3x4;
  }

  void _close() => Navigator.pop(context);

  void _save() => Navigator.pop(context, _transform.copy());

  TextStyle get _bannerStyle => AppFonts.geist(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: HomeFeedTokens.textPrimary,
  );

  void _open(_PieceEditTool tool) {
    setState(() {
      _toolSnapshot = _transform.copy();
      _openTool = tool;
      _transform.aspectRatio = CropAspectRatio.ratio3x4;
      if (tool == _PieceEditTool.crop &&
          _transform.fitMode == CropFitMode.fill) {
        _syncCropBox();
      }
      if (tool == _PieceEditTool.adjust) {
        _adjustSub = null;
        _showAdjustValue = false;
      }
    });
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

  void _syncCropBox({bool forceMaxFill = false}) {
    _transform.aspectRatio = CropAspectRatio.ratio3x4;
    _transform.fitMode = CropFitMode.fill;
    final cropAspect = CropAspectRatio.ratio3x4.value;
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

  void _setFitMode(CropFitMode mode) {
    if (_transform.fitMode == mode) return;
    setState(() {
      _transform.aspectRatio = CropAspectRatio.ratio3x4;
      if (mode == CropFitMode.fill) {
        _transform.fitMode = CropFitMode.fill;
        _transform.cropRect = CropCoverMath.defaultFillBox(
          CropAspectRatio.ratio3x4.value,
          _imageAspect,
        );
      } else {
        _transform.fitMode = CropFitMode.fit;
      }
    });
  }

  void _onCropScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _transform.resolvedCropRect(_imageAspect);
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onCropScaleUpdate(ScaleUpdateDetails details, Size frameSize) {
    final startBox = _gestureStartBox;
    if (startBox == null) return;
    final cropAspect = CropAspectRatio.ratio3x4.value;
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
    setState(() => _transform.flipHorizontal = !_transform.flipHorizontal);
  }

  Size _frameSizeFor(BoxConstraints constraints) {
    const ratio = 3 / 4;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openTool == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_openTool != null) {
          _cancelTool();
        } else {
          _close();
        }
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
              onTap: _close,
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
              onTap: _save,
              behavior: HitTestBehavior.opaque,
              child: Text('Done', style: _bannerStyle),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final frame = _frameSizeFor(constraints);
                  return _preview(frame: frame, tool: null);
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(32, 8, 32, 16 + bottomInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LabeledIcon(
                  asset: PostMediaAssets.sceneEditSize,
                  label: 'Fit',
                  onTap: () => _open(_PieceEditTool.fitFill),
                ),
                _LabeledIcon(
                  asset: PostMediaAssets.sceneEditCrop,
                  label: 'Crop',
                  onTap: () => _open(_PieceEditTool.crop),
                ),
                _LabeledIcon(
                  asset: PostMediaAssets.sceneEditAdjust,
                  label: 'Adjust',
                  onTap: () => _open(_PieceEditTool.adjust),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPage(_PieceEditTool tool) {
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final frame = _frameSizeFor(constraints);
                  return _preview(frame: frame, tool: tool);
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
            child: switch (tool) {
              _PieceEditTool.fitFill => _fitFillBar(),
              _PieceEditTool.crop => _cropBar(),
              _PieceEditTool.adjust => _adjustBar(),
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

  Widget _preview({required Size frame, required _PieceEditTool? tool}) {
    final path = widget.imagePath;
    final canCrop =
        tool == _PieceEditTool.crop && _transform.fitMode == CropFitMode.fill;
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        PostCropPreview.buildTransformedContent(
          imagePath: path,
          transform: _transform,
          imageAspect: _imageAspect,
        ),
        if (tool == _PieceEditTool.crop)
          const IgnorePointer(child: _RuleOfThirdsGrid()),
        if (tool == _PieceEditTool.adjust &&
            _adjustSub != null &&
            _showAdjustValue)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _transform.adjustValueFor(_adjustSub!).round().toString(),
                  style: AppFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textInverse,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (canCrop) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onCropScaleStart,
        onScaleUpdate: (d) => _onCropScaleUpdate(d, frame),
        onScaleEnd: (_) => _gestureStartBox = null,
        child: content,
      );
    }
    return Center(
      child: SizedBox(
        width: frame.width,
        height: frame.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_previewRadius),
            border: tool == _PieceEditTool.fitFill
                ? Border.all(color: _orange, width: 3)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              tool == _PieceEditTool.fitFill ? 5 : _previewRadius,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _fitFillBar() {
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
        const SizedBox(width: 8),
        Expanded(
          child: _ChoiceChip(
            label: 'Fit',
            selected: _transform.fitMode == CropFitMode.fit,
            onTap: () => _setFitMode(CropFitMode.fit),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChoiceChip(
            label: 'Fill',
            selected: _transform.fitMode == CropFitMode.fill,
            onTap: () => _setFitMode(CropFitMode.fill),
          ),
        ),
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
                  child: _AdjustTickDial(
                    value: _transform.adjustValueFor(sub),
                    onChanged: (value) {
                      setState(() {
                        _transform.setAdjustValue(sub, value);
                        _showAdjustValue = true;
                      });
                    },
                    onDragEnd: () {
                      setState(() => _showAdjustValue = true);
                      Future<void>.delayed(
                        const Duration(milliseconds: 900),
                        () {
                          if (mounted) {
                            setState(() => _showAdjustValue = false);
                          }
                        },
                      );
                    },
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
              onTap: () =>
                  setState(() => _adjustSub = AdjustSubTool.brightness),
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
              onTap: () => setState(() => _adjustSub = AdjustSubTool.contrast),
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
              onTap: () => setState(() => _adjustSub = AdjustSubTool.exposure),
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
            style: AppFonts.geist(
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
              : _PieceSceneStyleEditorState._chipFill,
          child: SizedBox(width: 32, height: 32, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
              : _PieceSceneStyleEditorState._chipFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppFonts.geist(
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

class _AdjustTickDial extends StatelessWidget {
  const _AdjustTickDial({
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
    return SizedBox(
      width: 160,
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
                onChanged(
                  (value - details.delta.dx * _valuePerPixel).clamp(0.0, 100.0),
                );
              },
              onHorizontalDragEnd: (_) => onDragEnd(),
              child: ClipRect(
                child: CustomPaint(
                  size: const Size(160, 12),
                  painter: _TickPainter(
                    offsetX: -(value - 50) / _valuePerPixel,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
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

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.offsetX});

  final double offsetX;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final paint = Paint()
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    for (var i = -14; i <= 14; i++) {
      final x = centerX + i * 6.0 + offsetX;
      if (x < 2 || x > size.width - 2) continue;
      final dist = (x - centerX).abs();
      final height = (11.0 - dist * 0.18).clamp(3.0, 11.0);
      final opacity = (1.0 - dist * 0.025).clamp(0.35, 1.0);
      paint.color = HomeFeedTokens.textPrimary.withValues(alpha: opacity);
      canvas.drawLine(Offset(x, 11.625), Offset(x, 11.625 - height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.offsetX != offsetX;
}

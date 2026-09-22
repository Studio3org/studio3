import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/post_media_assets.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart'
    show CropAspectRatio, CropCoverMath, CropFitMode;
import '../utils/image_adjust_math.dart';
import '../widgets/post_crop_preview.dart';
import 'piece_scene_style_editor.dart';
import '../theme/app_fonts.dart';

part 'post_image_editor_page.dart';

/// Image edit step — posting flow (Figma 1961:1453 / 1973:1223 / 1986:1416).
class PostEditPage extends StatefulWidget {
  const PostEditPage({
    super.key,
    required this.postType,
    this.customImagePaths,
    this.initialImageIndex = 0,
    this.initialTransforms,
    this.onClose,
    this.onPickMore,
    this.onNext,
  });

  final String postType;
  final List<String>? customImagePaths;
  final int initialImageIndex;
  final List<PostImageTransform>? initialTransforms;
  final VoidCallback? onClose;

  /// Piece flow only — "+" tile on the cover-reorder strip. Given how many
  /// more images can still be picked, returns the full updated asset
  /// selection (or null if the user cancelled) — the cover screen then
  /// merges it into the existing images without losing any edits already
  /// made (Figma 2716:5774).
  final Future<List<AssetEntity>?> Function(int remainingSlots)? onPickMore;
  final void Function(
    List<String> imagePaths,
    List<PostImageTransform> transforms,
    int previewImageIndex,
  )?
  onNext;

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  static const _previewHorizontalInset = 6.0;
  static const _previewGapBelowBanner = 36.0;
  static const _previewRadius = 8.0;
  static const _thumbSize = 56.0;
  static const _thumbGap = 6.0;
  static const _thumbStripTopGap = 12.0;
  static const _bottomControlsOffset = 42.0;
  static const _cropToolsGapAboveSelector = 12.0;
  static const _gapAboveAspectSelector = 20.0;
  static const _maxCropHeightFraction = 0.52;

  late final List<String> _imagePaths;
  late final List<PostImageTransform> _transforms;
  final Map<String, double> _imageAspects = {};

  int _activeImageIndex = 0;
  String? _editTool;
  CropSubTool? _activeCropSubTool;
  AdjustSubTool? _activeAdjustSubTool;

  bool _showAdjustValue = false;
  bool _showRotationValue = false;

  // Snapshot of the crop box/rotation/focal-point taken at the start of a
  // pan/pinch-zoom/rotate gesture — the update handler always derives the
  // new state from this snapshot (not incrementally) so it can't drift.
  Rect? _gestureStartBox;
  double _gestureStartRotation = 0;
  Offset _gestureStartFocalPoint = Offset.zero;

  bool get _isCropMode => _editTool == 'crop';
  bool get _isAdjustMode => _editTool == 'adjust';
  bool get _isSelectionMode => _editTool == null;
  bool get _isRotateMode =>
      _isCropMode && _activeCropSubTool == CropSubTool.rotate;

  PostImageTransform get _currentTransform => _transforms[_activeImageIndex];

  double _aspectForPath(String path) => _imageAspects[path] ?? 1.0;

  @override
  void initState() {
    super.initState();
    _imagePaths = List<String>.from(widget.customImagePaths ?? const []);
    _transforms =
        widget.initialTransforms != null &&
            widget.initialTransforms!.length == _imagePaths.length
        ? widget.initialTransforms!.map((t) => t.copy()).toList()
        : List.generate(
            _imagePaths.length,
            (_) => PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4),
          );
    for (final t in _transforms) {
      t.aspectRatio = CropAspectRatio.ratio3x4;
    }
    _activeImageIndex = widget.initialImageIndex.clamp(
      0,
      _imagePaths.length - 1,
    );
    for (final path in _imagePaths.toSet()) {
      _loadImageAspect(path);
    }
  }

  Future<void> _loadImageAspect(String path) async {
    if (_imageAspects.containsKey(path)) return;
    try {
      ui.Image? decoded;
      if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        decoded = frame.image;
      } else {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        decoded = frame.image;
      }
      final w = decoded.width.toDouble();
      final h = decoded.height.toDouble();
      if (!mounted || h == 0) return;
      setState(() => _imageAspects[path] = w / h);
    } catch (_) {
      if (mounted) setState(() => _imageAspects[path] = 1.0);
    }
  }

  void _applyRotation(double degrees) {
    setState(() {
      _currentTransform.rotationDegrees = degrees;
      final imageAspect = _aspectForPath(_imagePaths[_activeImageIndex]);
      _currentTransform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: _currentTransform.resolvedCropRect(imageAspect),
        rotationDegrees: degrees,
        imageAspect: imageAspect,
      );
      _showRotationValue = true;
    });
  }

  /// Fill mode's photo is fully interactive: one finger pans, two fingers
  /// pinch-zoom and rotate — all in a single `onScale*` gesture stream.
  /// Everything is derived from the snapshot taken in [_onCropScaleStart],
  /// never incrementally, so repeated updates can't accumulate drift.
  void _onCropScaleStart(ScaleStartDetails details) {
    final imageAspect = _aspectForPath(_imagePaths[_activeImageIndex]);
    _gestureStartBox = _currentTransform.resolvedCropRect(imageAspect);
    _gestureStartRotation = _currentTransform.rotationDegrees;
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onCropScaleUpdate(ScaleUpdateDetails details, Size frameSize) {
    final startBox = _gestureStartBox;
    if (startBox == null) return;
    final imageAspect = _aspectForPath(_imagePaths[_activeImageIndex]);
    final cropAspect = _currentTransform.aspectRatio.value;

    // Pan: a drag spanning the full frame width/height should pan by one
    // box-width/height across the image, so the photo tracks the finger
    // 1:1 on screen regardless of current zoom.
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
      imageAspect: imageAspect,
    );

    final newRotation =
        _gestureStartRotation + details.rotation * 180 / math.pi;

    setState(() {
      _currentTransform.rotationDegrees = newRotation;
      _currentTransform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: scaled,
        rotationDegrees: newRotation,
        imageAspect: imageAspect,
      );
      _showRotationValue = details.rotation.abs() > 0.001;
    });
  }

  void _onCropScaleEnd(ScaleEndDetails details) {
    _gestureStartBox = null;
    if (_showRotationValue) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showRotationValue = false);
      });
    }
  }

  void _toggleFitMode() {
    final imageAspect = _aspectForPath(_imagePaths[_activeImageIndex]);
    final base = _currentTransform.resolvedCropRect(imageAspect);
    setState(() {
      if (_currentTransform.fitMode == CropFitMode.fit) {
        // Fit → Fill: re-lock the current box to the aspect ratio, centered.
        _currentTransform.fitMode = CropFitMode.fill;
        _currentTransform.cropRect = CropCoverMath.relockToAspect(
          box: base,
          cropAspect: _currentTransform.aspectRatio.value,
          imageAspect: imageAspect,
        );
      } else {
        // Fill → Fit: keep the box remembered for later, Fit itself
        // always shows the whole image regardless (see resolvedCropRect).
        _currentTransform.fitMode = CropFitMode.fit;
      }
    });
  }

  int _rotationTurnPercent(double degrees) {
    var d = degrees % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return (d / 360 * 100).round();
  }

  void _onRotationDragEnd() {
    setState(() => _showRotationValue = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showRotationValue = false);
    });
  }

  void _onCropSubToolTap(CropSubTool tool) {
    setState(() {
      _editTool = 'crop';
      if (tool == CropSubTool.rotate) {
        _activeCropSubTool = CropSubTool.rotate;
        _showRotationValue = _currentTransform.rotationDegrees.abs() > 0.01;
        return;
      }
      if (tool == CropSubTool.flipHorizontal) {
        _currentTransform.flipHorizontal = !_currentTransform.flipHorizontal;
      } else if (tool == CropSubTool.flipVertical) {
        _currentTransform.flipVertical = !_currentTransform.flipVertical;
      }
    });
  }

  void _resetForCurrentMode() {
    setState(() {
      if (_isCropMode) {
        _currentTransform.resetCrop();
      } else if (_isAdjustMode) {
        _currentTransform.resetAdjust();
      }
      _showAdjustValue = false;
      _showRotationValue = false;
    });
  }

  void _finishEditing() {
    setState(() {
      _editTool = null;
      _activeCropSubTool = null;
      _activeAdjustSubTool = null;
      _showAdjustValue = false;
      _showRotationValue = false;
    });
  }

  void _openCreatePage() {
    _finishEditing();
    if (widget.onNext != null) {
      widget.onNext!(
        List<String>.from(_imagePaths),
        _transforms.map((t) => t.copy()).toList(),
        // Pieces always publish the whole gallery with index 0 as the cover
        // (see "Set your cover", Figma 2716:5774) — the preview index isn't
        // "whatever the user was last looking at", it's always the cover.
        widget.postType == 'piece' ? 0 : _activeImageIndex,
      );
      return;
    }
  }

  void _onAdjustSubToolTap(AdjustSubTool tool) {
    setState(() {
      _editTool = 'adjust';
      _activeAdjustSubTool = tool;
    });
  }

  void _onAdjustValueChanged(double value) {
    if (_activeAdjustSubTool == null) return;
    setState(() {
      _currentTransform.setAdjustValue(_activeAdjustSubTool!, value);
      _showAdjustValue = true;
    });
  }

  void _onAdjustDragEnd() {
    setState(() => _showAdjustValue = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showAdjustValue = false);
    });
  }

  /// Both Fill and Fit are always shaped to the selected crop aspect ratio
  /// — Fill shows the true filled-edge-to-edge output (pannable/pinchable
  /// in crop mode), Fit shows the true letterboxed output (never
  /// interactive) — see `PostCropPreview.buildTransformedContent`.
  Size _cropFrameSize(
    double maxWidth,
    double maxHeight,
    CropAspectRatio ratio,
  ) {
    var width = maxWidth;
    var height = width / ratio.value;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio.value;
    }
    return Size(width, height);
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final activePath = _imagePaths[_activeImageIndex];
      _imagePaths.insert(newIndex, _imagePaths.removeAt(oldIndex));
      _transforms.insert(newIndex, _transforms.removeAt(oldIndex));
      _activeImageIndex = _imagePaths.indexOf(activePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.postType == 'piece') return _buildPieceCoverFlow(context);

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasMultiple = _imagePaths.length > 1;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxCropWidth =
        MediaQuery.sizeOf(context).width - (_previewHorizontalInset * 2);
    final maxCropHeight = screenHeight * _maxCropHeightFraction;
    final imageAspect = _aspectForPath(_imagePaths[_activeImageIndex]);
    final isFillMode = _currentTransform.fitMode == CropFitMode.fill;
    // Interactive (pan/pinch-zoom/rotate) only while Crop is actively open
    // and in Fill mode — Fit is always fully automatic (see
    // `PostImageTransform.resolvedCropRect`), and outside crop mode this
    // just shows the real, non-interactive result.
    final isInteractive = isFillMode && _isCropMode;
    final viewportSize = _cropFrameSize(
      maxCropWidth,
      maxCropHeight,
      _currentTransform.aspectRatio,
    );

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _EditBanner(
            topInset: topInset,
            onClose: widget.onClose ?? () => Navigator.pop(context),
            onNext: _openCreatePage,
          ),
          const SizedBox(height: _previewGapBelowBanner),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _previewHorizontalInset,
            ),
            child: SizedBox(
              width: maxCropWidth,
              height: maxCropHeight,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_previewRadius),
                  child: SizedBox(
                    width: viewportSize.width,
                    height: viewportSize.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isInteractive)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: _onCropScaleStart,
                            onScaleUpdate: (details) =>
                                _onCropScaleUpdate(details, viewportSize),
                            onScaleEnd: _onCropScaleEnd,
                            child: PostCropPreview.buildTransformedContent(
                              imagePath: _imagePaths[_activeImageIndex],
                              transform: _currentTransform,
                              imageAspect: imageAspect,
                            ),
                          )
                        else
                          IgnorePointer(
                            child: PostCropPreview.buildTransformedContent(
                              imagePath: _imagePaths[_activeImageIndex],
                              transform: _currentTransform,
                              imageAspect: imageAspect,
                            ),
                          ),
                        if (_isAdjustMode &&
                            _activeAdjustSubTool != null &&
                            _showAdjustValue)
                          IgnorePointer(
                            child: _PreviewValueOverlay(
                              text: _currentTransform
                                  .adjustValueFor(_activeAdjustSubTool!)
                                  .round()
                                  .toString(),
                            ),
                          ),
                        if (_isCropMode &&
                            _showRotationValue &&
                            (_isRotateMode ||
                                _currentTransform.rotationDegrees.abs() > 0.01))
                          IgnorePointer(
                            child: _PreviewValueOverlay(
                              text:
                                  '${_rotationTurnPercent(_currentTransform.rotationDegrees)}%',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasMultiple && _isSelectionMode) ...[
            const SizedBox(height: _thumbStripTopGap),
            SizedBox(
              height: _thumbSize,
              child: _CenteredThumbStrip(
                itemCount: _imagePaths.length,
                itemBuilder: (context, index) {
                  final active = index == _activeImageIndex;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _finishEditing();
                      _activeImageIndex = index;
                    }),
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: active
                              ? HomeFeedTokens.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _EditThumbPreview(
                          assetPath: _imagePaths[index],
                          transform: _transforms[index],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const Spacer(),
          if (_isCropMode) ...[
            const SizedBox(height: _gapAboveAspectSelector),
            Padding(
              // Left inset mirrors the button's own width + right inset so
              // the aspect chips still land visually centered on screen.
              padding: const EdgeInsets.only(left: 52, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _CropAspectSelector(
                      selected: _currentTransform.aspectRatio,
                      onSelected: (ratio) {
                        // Applies to every image in the post, not just the
                        // active one — a multi-image post should share one
                        // output aspect ratio. Each image's own Fill/Fit
                        // mode and box position stay independent; only
                        // images currently in Fill get their box relocked
                        // (using their own imageAspect).
                        setState(() {
                          for (var i = 0; i < _transforms.length; i++) {
                            final t = _transforms[i];
                            final imgAspect = _aspectForPath(_imagePaths[i]);
                            final base = t.resolvedCropRect(imgAspect);
                            t.aspectRatio = ratio;
                            if (t.fitMode == CropFitMode.fill) {
                              t.cropRect = CropCoverMath.relockToAspect(
                                box: base,
                                cropAspect: ratio.value,
                                imageAspect: imgAspect,
                              );
                            }
                          }
                        });
                      },
                    ),
                  ),
                  _FitFillToggleButton(
                    fitMode: _currentTransform.fitMode,
                    onTap: _toggleFitMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _EditResetDoneRow(
                onReset: _resetForCurrentMode,
                onDone: _finishEditing,
              ),
            ),
            const SizedBox(height: 8),
            if (_isRotateMode) ...[
              Center(
                child: _RotationDial(
                  rotationDegrees: _currentTransform.rotationDegrees,
                  onRotationChanged: _applyRotation,
                  onDragEnd: _onRotationDragEnd,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _CropTransformBar(
              selectedTool: _activeCropSubTool,
              onToolTap: _onCropSubToolTap,
            ),
            const SizedBox(height: _cropToolsGapAboveSelector),
          ],
          if (_isAdjustMode) ...[
            if (_activeAdjustSubTool != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _EditResetDoneRow(
                  onReset: _resetForCurrentMode,
                  onDone: _finishEditing,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: _AdjustDial(
                  value: _currentTransform.adjustValueFor(
                    _activeAdjustSubTool!,
                  ),
                  onChanged: _onAdjustValueChanged,
                  onDragEnd: _onAdjustDragEnd,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _AdjustTransformBar(
              selectedTool: _activeAdjustSubTool,
              onToolTap: _onAdjustSubToolTap,
            ),
            const SizedBox(height: _cropToolsGapAboveSelector),
          ],
          Center(
            child: _EditToolSelector(
              editTool: _editTool,
              onChanged: (tool) => setState(() {
                _editTool = tool;
                if (tool != 'crop') _activeCropSubTool = null;
                if (tool != 'adjust') {
                  _activeAdjustSubTool = null;
                  _showAdjustValue = false;
                } else {
                  _activeAdjustSubTool ??= AdjustSubTool.brightness;
                }
              }),
            ),
          ),
          SizedBox(height: bottomInset + _bottomControlsOffset),
        ],
      ),
    );
  }

  static const _piecesMaxSelection = 5;

  Future<void> _openImageEditor() async {
    final path = _imagePaths[_activeImageIndex];
    final result = await Navigator.push<PostImageTransform>(
      context,
      MaterialPageRoute(
        builder: (_) => PieceSceneStyleEditor(
          imagePath: path,
          transform: _transforms[_activeImageIndex],
          imageAspect: _aspectForPath(path),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _transforms[_activeImageIndex] = result);
    }
  }

  /// Piece cover-selection step: all picked photos, reorder, then the
  /// pencil opens Fit/Fill · Crop · Adjust for that image.
  Widget _buildPieceCoverFlow(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _SetCoverBanner(
            topInset: topInset,
            onBack: widget.onClose ?? () => Navigator.pop(context),
            onNext: _openCreatePage,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_previewRadius),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            child: PostCropPreview.buildTransformedContent(
                              imagePath: _imagePaths[_activeImageIndex],
                              transform: _currentTransform,
                              imageAspect:
                                  _aspectForPath(_imagePaths[_activeImageIndex]),
                            ),
                          ),
                          if (_activeImageIndex == 0)
                            const Positioned(
                              left: 8,
                              top: 8,
                              child: _CoverPillBadge(
                                text: 'Cover',
                                opacity: 0.6,
                              ),
                            ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _CoverPillBadge(
                              text:
                                  '${_activeImageIndex + 1}/${_imagePaths.length}',
                              opacity: 0.3,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _openImageEditor,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  PostMediaAssets.createPencilIcon,
                                  width: 14,
                                  height: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drag to reorder',
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: _CoverReorderStrip(
                      imagePaths: _imagePaths,
                      transforms: _transforms,
                      activeIndex: _activeImageIndex,
                      onTapImage: (index) => setState(() {
                        _activeImageIndex = index;
                      }),
                      onReorder: _reorderImages,
                      onAddMore: _imagePaths.length < _piecesMaxSelection
                          ? _pickMoreImages
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Merges newly-picked assets into the existing gallery by resolved file
  /// path — images still present keep their existing (and possibly edited)
  /// transform and relative order; only genuinely new picks get a fresh
  /// [PostImageTransform] (Figma 2716:5774's "+" tile).
  Future<void> _pickMoreImages() async {
    final onPickMore = widget.onPickMore;
    if (onPickMore == null) return;
    final remaining = _piecesMaxSelection - _imagePaths.length;
    if (remaining <= 0) return;
    final assets = await onPickMore(remaining);
    if (assets == null || !mounted) return;

    final newPaths = <String>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) newPaths.add(file.path);
    }
    if (!mounted) return;

    final activePath = _imagePaths.isNotEmpty
        ? _imagePaths[_activeImageIndex]
        : null;
    final oldPaths = List<String>.from(_imagePaths);
    final oldTransforms = List<PostImageTransform>.from(_transforms);
    final mergedTransforms = newPaths.map((path) {
      final existingIndex = oldPaths.indexOf(path);
      return existingIndex >= 0
          ? oldTransforms[existingIndex]
          : PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4);
    }).toList();

    setState(() {
      _imagePaths
        ..clear()
        ..addAll(newPaths);
      _transforms
        ..clear()
        ..addAll(mergedTransforms);
      _activeImageIndex = activePath != null && _imagePaths.contains(activePath)
          ? _imagePaths.indexOf(activePath)
          : 0;
    });
    for (final path in newPaths.toSet()) {
      _loadImageAspect(path);
    }
  }
}

class _CenteredThumbStrip extends StatelessWidget {
  const _CenteredThumbStrip({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            itemCount * _PostEditPageState._thumbSize +
            (itemCount - 1) * _PostEditPageState._thumbGap;

        if (contentWidth <= constraints.maxWidth) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < itemCount; index++) ...[
                  if (index > 0)
                    const SizedBox(width: _PostEditPageState._thumbGap),
                  itemBuilder(context, index),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: itemCount,
          separatorBuilder: (context, _) =>
              const SizedBox(width: _PostEditPageState._thumbGap),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class _EditResetDoneRow extends StatelessWidget {
  const _EditResetDoneRow({required this.onReset, required this.onDone});

  static const _errorRed = Color(0xFFC03030);

  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onReset,
          behavior: HitTestBehavior.opaque,
          child: Text(
            'RESET',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _errorRed,
              letterSpacing: 0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: onDone,
          behavior: HitTestBehavior.opaque,
          child: Text(
            'DONE',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textInverse,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditThumbPreview extends StatelessWidget {
  const _EditThumbPreview({required this.assetPath, required this.transform});

  final String assetPath;
  final PostImageTransform transform;

  @override
  Widget build(BuildContext context) {
    Widget image = PostCropPreview.sourceImage(assetPath);

    if (!ImageAdjustMath.isNeutral(
      brightness: transform.brightness,
      contrast: transform.contrast,
      exposure: transform.exposure,
    )) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          ImageAdjustMath.combinedMatrix(
            brightness: transform.brightness,
            contrast: transform.contrast,
            exposure: transform.exposure,
          ),
        ),
        child: image,
      );
    }

    return image;
  }
}

/// Circular toggle shown below the aspect-ratio selector: shows the icon
/// for the mode a tap would switch *to* (Fit mode shows the Fill icon, and
/// vice versa) — no existing custom SVG for this, so plain Material icons.
class _FitFillToggleButton extends StatelessWidget {
  const _FitFillToggleButton({required this.fitMode, required this.onTap});

  final CropFitMode fitMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final switchingToFill = fitMode == CropFitMode.fit;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          switchingToFill
              ? Icons.fullscreen_rounded
              : Icons.fit_screen_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _PreviewValueOverlay extends StatelessWidget {
  const _PreviewValueOverlay({required this.text});

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
          style: AppFonts.inter(
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

class _AdjustTransformBar extends StatelessWidget {
  const _AdjustTransformBar({
    required this.selectedTool,
    required this.onToolTap,
  });

  static const _iconSize = 30.0;
  static const _barWidth = 170.0;
  static const _barHeight = 40.0;

  final AdjustSubTool? selectedTool;
  final ValueChanged<AdjustSubTool> onToolTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: Center(
        child: SizedBox(
          width: _barWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AdjustToolButton(
                  asset: PostMediaAssets.adjustBrightness,
                  selected: selectedTool == AdjustSubTool.brightness,
                  onTap: () => onToolTap(AdjustSubTool.brightness),
                ),
                _AdjustToolButton(
                  asset: PostMediaAssets.adjustContrast,
                  selected: selectedTool == AdjustSubTool.contrast,
                  onTap: () => onToolTap(AdjustSubTool.contrast),
                ),
                _AdjustToolButton(
                  asset: PostMediaAssets.adjustExposure,
                  selected: selectedTool == AdjustSubTool.exposure,
                  onTap: () => onToolTap(AdjustSubTool.exposure),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustToolButton extends StatelessWidget {
  const _AdjustToolButton({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: _AdjustTransformBar._iconSize,
            height: _AdjustTransformBar._iconSize,
          ),
          if (selected) ...[
            const SizedBox(height: 4),
            Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textInverse,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ] else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _CropAspectSelector extends StatelessWidget {
  const _CropAspectSelector({required this.selected, required this.onSelected});

  static const _selectorBg = Color(0xE6231F1B);

  final CropAspectRatio selected;
  final ValueChanged<CropAspectRatio> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _selectorBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ratio in const [
              CropAspectRatio.ratio3x4,
              CropAspectRatio.ratio16x9,
            ]) ...[
              _CropAspectChip(
                label: ratio.label,
                selected: selected == ratio,
                onTap: () => onSelected(ratio),
              ),
              if (ratio != CropAspectRatio.ratio16x9) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _CropAspectChip extends StatelessWidget {
  const _CropAspectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _textSecondary = Color(0xFF8C8880);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? HomeFeedTokens.textInverse : _textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RotationDial extends StatelessWidget {
  const _RotationDial({
    required this.rotationDegrees,
    required this.onRotationChanged,
    required this.onDragEnd,
  });

  static const _degreesPerPixel = 0.35;

  final double rotationDegrees;
  final ValueChanged<double> onRotationChanged;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return _TickDial(
      offsetX: -rotationDegrees / _degreesPerPixel,
      onHorizontalDragUpdate: (deltaDx) {
        onRotationChanged(rotationDegrees - deltaDx * _degreesPerPixel);
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
                color: HomeFeedTokens.textInverse,
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
      paint.color = Colors.white.withValues(alpha: opacity);

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

class _CropTransformBar extends StatelessWidget {
  const _CropTransformBar({
    required this.selectedTool,
    required this.onToolTap,
  });

  static const _iconSize = 30.0;
  static const _barWidth = 170.0;
  static const _barHeight = 40.0;

  final CropSubTool? selectedTool;
  final ValueChanged<CropSubTool> onToolTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: Center(
        child: SizedBox(
          width: _barWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CropToolButton(
                  asset: PostMediaAssets.cropRotate,
                  selected: selectedTool == CropSubTool.rotate,
                  onTap: () => onToolTap(CropSubTool.rotate),
                ),
                _CropToolButton(
                  asset: PostMediaAssets.cropPerspectiveH,
                  selected: false,
                  onTap: () => onToolTap(CropSubTool.flipHorizontal),
                ),
                _CropToolButton(
                  asset: PostMediaAssets.cropPerspectiveV,
                  selected: false,
                  onTap: () => onToolTap(CropSubTool.flipVertical),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropToolButton extends StatelessWidget {
  const _CropToolButton({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: _CropTransformBar._iconSize,
            height: _CropTransformBar._iconSize,
          ),
          if (selected) ...[
            const SizedBox(height: 4),
            Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textInverse,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ] else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _EditBanner extends StatelessWidget {
  const _EditBanner({
    required this.topInset,
    required this.onClose,
    required this.onNext,
    this.nextLabel = 'Next',
  });

  static const _bannerHeight = 64.0;

  final double topInset;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _bannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        PostMediaAssets.closeIcon,
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          HomeFeedTokens.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onNext,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            nextLabel,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Edit',
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
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

class _EditToolSelector extends StatelessWidget {
  const _EditToolSelector({required this.editTool, required this.onChanged});

  static const _selectorBg = Color(0xE6231F1B);

  final String? editTool;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _selectorBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _EditToolTab(
            label: 'Crop',
            selected: editTool == 'crop',
            onTap: () => onChanged('crop'),
          ),
          _EditToolTab(
            label: 'Adjust',
            selected: editTool == 'adjust',
            onTap: () => onChanged('adjust'),
          ),
        ],
      ),
    );
  }
}

class _EditToolTab extends StatelessWidget {
  const _EditToolTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _textSecondary = Color(0xFF8C8880);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: selected ? HomeFeedTokens.textInverse : _textSecondary,
        ),
      ),
    );
  }
}

class _SetCoverBanner extends StatelessWidget {
  const _SetCoverBanner({
    required this.topInset,
    required this.onBack,
    required this.onNext,
  });

  static const _bannerHeight = 64.0;

  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _bannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        PostMediaAssets.chevronBack,
                        width: 8,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          HomeFeedTokens.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onNext,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Next',
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Set your cover',
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
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

class _CoverPillBadge extends StatelessWidget {
  const _CoverPillBadge({required this.text, required this.opacity});

  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomeFeedTokens.textPrimary.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: AppFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: HomeFeedTokens.textInverse,
        ),
      ),
    );
  }
}

/// Drag-to-reorder strip of picked images plus a trailing "add more" tile —
/// the first image is always the post's cover (Figma 2716:5774/5973).
class _CoverReorderStrip extends StatelessWidget {
  const _CoverReorderStrip({
    required this.imagePaths,
    required this.transforms,
    required this.activeIndex,
    required this.onTapImage,
    required this.onReorder,
    required this.onAddMore,
  });

  static const _tileWidth = 60.0;
  static const _tileHeight = 76.0;
  static const _gap = 8.0;

  final List<String> imagePaths;
  final List<PostImageTransform> transforms;
  final int activeIndex;
  final ValueChanged<int> onTapImage;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onAddMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            proxyDecorator: (child, index, animation) =>
                Material(color: Colors.transparent, child: child),
            itemCount: imagePaths.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final path = imagePaths[index];
              final active = index == activeIndex;
              return Padding(
                key: ValueKey(path),
                padding: EdgeInsets.only(
                  right: index == imagePaths.length - 1 ? 0 : _gap,
                ),
                child: GestureDetector(
                  onTap: () => onTapImage(index),
                  child: Container(
                    width: _tileWidth,
                    height: _tileHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active
                            ? HomeFeedTokens.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _EditThumbPreview(
                        assetPath: path,
                        transform: transforms[index],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (onAddMore != null) ...[
          const SizedBox(width: _gap),
          GestureDetector(
            onTap: onAddMore,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: const _DashedRoundedBorderPainter(
                color: HomeFeedTokens.textSecondary,
              ),
              child: SizedBox(
                width: _tileWidth,
                height: _tileHeight,
                child: Center(
                  child: SvgPicture.asset(
                    PostMediaAssets.coverAddIcon,
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dashed rounded-rect border for the "add more" tile — Flutter's
/// [BoxDecoration] has no dashed-border support, so this walks the rect's
/// path in fixed-length segments (Figma 2716:5978).
class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color});

  final Color color;

  static const _radius = 8.0;
  static const _dashWidth = 4.0;
  static const _dashGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

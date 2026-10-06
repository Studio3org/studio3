part of 'post_edit_page.dart';

/// Instagram-style focused single-image editor, opened from the piece
/// flow's "Set your cover" screen by tapping the Edit button on the
/// preview (Figma 2716:5774) — crop (two-finger pinch-zoom/pan/rotate) and
/// adjust tools are the same ones already built for the general edit flow,
/// just scoped to one image and reached explicitly instead of always-on.
class PostImageEditorPage extends StatefulWidget {
  const PostImageEditorPage({
    super.key,
    required this.imagePath,
    required this.transform,
    required this.imageAspect,
  });

  final String imagePath;
  final PostImageTransform transform;
  final double imageAspect;

  @override
  State<PostImageEditorPage> createState() => _PostImageEditorPageState();
}

class _PostImageEditorPageState extends State<PostImageEditorPage> {
  static const _previewHorizontalInset = 6.0;
  static const _previewGapBelowBanner = 36.0;
  static const _previewRadius = 8.0;
  static const _bottomControlsOffset = 42.0;
  static const _cropToolsGapAboveSelector = 12.0;
  static const _maxCropHeightFraction = 0.52;

  // Edited in place, then only handed back to the caller on "Done" — Close
  // discards it, so the copy taken here never leaks back if cancelled.
  late final PostImageTransform _transform = widget.transform.copy();

  // Instagram-style: crop is the tool that's live the moment this screen
  // opens (in Fill mode, so pinch-zoom/pan work immediately), not a mode
  // the user has to opt into first. Tapping Done in either tool's panel
  // collapses back to null (bare tab bar, frozen preview) exactly like the
  // general multi-image editor, so re-entering a tool is always explicit.
  String? _editTool = 'crop';
  CropSubTool? _activeCropSubTool;
  AdjustSubTool? _activeAdjustSubTool;

  bool _showAdjustValue = false;
  bool _showRotationValue = false;

  Rect? _gestureStartBox;
  double _gestureStartRotation = 0;
  Offset _gestureStartFocalPoint = Offset.zero;

  bool get _isCropMode => _editTool == 'crop';
  bool get _isAdjustMode => _editTool == 'adjust';
  bool get _isRotateMode =>
      _isCropMode && _activeCropSubTool == CropSubTool.rotate;

  void _applyRotation(double degrees) {
    setState(() {
      _transform.rotationDegrees = degrees;
      _transform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: _transform.resolvedCropRect(widget.imageAspect),
        rotationDegrees: degrees,
        imageAspect: widget.imageAspect,
      );
      _showRotationValue = true;
    });
  }

  void _onCropScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _transform.resolvedCropRect(widget.imageAspect);
    _gestureStartRotation = _transform.rotationDegrees;
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
      imageAspect: widget.imageAspect,
    );

    final newRotation =
        _gestureStartRotation + details.rotation * 180 / math.pi;

    setState(() {
      _transform.rotationDegrees = newRotation;
      _transform.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: scaled,
        rotationDegrees: newRotation,
        imageAspect: widget.imageAspect,
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
    final base = _transform.resolvedCropRect(widget.imageAspect);
    setState(() {
      if (_transform.fitMode == CropFitMode.fill) {
        _transform.fitMode = CropFitMode.fit;
      } else {
        _transform.fitMode = CropFitMode.fill;
        _transform.cropRect = CropCoverMath.relockToAspect(
          box: base,
          cropAspect: _transform.aspectRatio.value,
          imageAspect: widget.imageAspect,
        );
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
      if (tool == CropSubTool.rotate) {
        _activeCropSubTool = CropSubTool.rotate;
        _showRotationValue = _transform.rotationDegrees.abs() > 0.01;
        return;
      }
      if (tool == CropSubTool.flipHorizontal) {
        _transform.flipHorizontal = !_transform.flipHorizontal;
      } else if (tool == CropSubTool.flipVertical) {
        _transform.flipVertical = !_transform.flipVertical;
      }
    });
  }

  void _resetForCurrentMode() {
    setState(() {
      if (_isCropMode) {
        _transform.resetCrop();
      } else if (_isAdjustMode) {
        _transform.resetAdjust();
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

  void _onAdjustSubToolTap(AdjustSubTool tool) {
    setState(() => _activeAdjustSubTool = tool);
  }

  void _onAdjustValueChanged(double value) {
    if (_activeAdjustSubTool == null) return;
    setState(() {
      _transform.setAdjustValue(_activeAdjustSubTool!, value);
      _showAdjustValue = true;
    });
  }

  void _onAdjustDragEnd() {
    setState(() => _showAdjustValue = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showAdjustValue = false);
    });
  }

  Size _cropFrameSize(double maxWidth, double maxHeight, CropAspectRatio ratio) {
    var width = maxWidth;
    var height = width / ratio.value;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio.value;
    }
    return Size(width, height);
  }

  void _close() => Navigator.pop(context);
  void _done() => Navigator.pop(context, _transform);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxCropWidth =
        MediaQuery.sizeOf(context).width - (_previewHorizontalInset * 2);
    final maxCropHeight = screenHeight * _maxCropHeightFraction;
    final isFillMode = _transform.fitMode == CropFitMode.fill;
    final isInteractive = isFillMode && _isCropMode;
    final viewportSize =
        _cropFrameSize(maxCropWidth, maxCropHeight, _transform.aspectRatio);

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _EditBanner(
            topInset: topInset,
            onClose: _close,
            onNext: _done,
            nextLabel: 'Done',
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
                              imagePath: widget.imagePath,
                              transform: _transform,
                              imageAspect: widget.imageAspect,
                            ),
                          )
                        else
                          IgnorePointer(
                            child: PostCropPreview.buildTransformedContent(
                              imagePath: widget.imagePath,
                              transform: _transform,
                              imageAspect: widget.imageAspect,
                            ),
                          ),
                        if (_isAdjustMode &&
                            _activeAdjustSubTool != null &&
                            _showAdjustValue)
                          IgnorePointer(
                            child: _PreviewValueOverlay(
                              text: _transform
                                  .adjustValueFor(_activeAdjustSubTool!)
                                  .round()
                                  .toString(),
                            ),
                          ),
                        if (_isCropMode &&
                            _showRotationValue &&
                            (_isRotateMode ||
                                _transform.rotationDegrees.abs() > 0.01))
                          IgnorePointer(
                            child: _PreviewValueOverlay(
                              text:
                                  '${_rotationTurnPercent(_transform.rotationDegrees)}%',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (_isCropMode) ...[
            Center(
              child: _FitFillToggleButton(
                fitMode: _transform.fitMode,
                onTap: _toggleFitMode,
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
                  rotationDegrees: _transform.rotationDegrees,
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
                  value: _transform.adjustValueFor(_activeAdjustSubTool!),
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
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_image_transform.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../utils/crop_cover_math.dart'
    show CropAspectRatio, CropCoverMath, CropFitMode;
import '../widgets/post_crop_preview.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_tap_area.dart';

enum _EditTab { size, crop, adjust }

/// Scene photo editor (`ScenePhotoEditSize`, `ScenePhotoEdit`): dark in both themes. Scenes
/// can be edited; pieces cannot (they use `PostCoverPage`).
///
/// Back / Next; the photo in a 366-wide frame (radius 4) that can be dragged, pinched and
/// turned on the Crop tab; text tabs Size, Crop, Adjust (15/500, the open one Gallery White
/// with a 2 px underline). Size: Original, 4:5, 1:1, 9:16 pills. Crop: Rotate, Flip and
/// Reset pills over a zero-centred straighten slider. Adjust: Brightness, Contrast, Warmth
/// pills over a zero-centred slider with its value in Mono.
class PostEditPage extends StatefulWidget {
  const PostEditPage({
    super.key,
    required this.postType,
    this.customImagePaths,
    this.initialImageIndex = 0,
    this.initialTransforms,
    this.onClose,
    this.onNext,
  });

  final String postType;
  final List<String>? customImagePaths;
  final int initialImageIndex;
  final List<PostImageTransform>? initialTransforms;

  /// Back (to the gallery).
  final VoidCallback? onClose;
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
  static const _sizes = <CropAspectRatio?>[
    null, // Original
    CropAspectRatio.ratio4x5,
    CropAspectRatio.ratio1x1,
    CropAspectRatio.ratio9x16,
  ];

  late final List<String> _imagePaths;
  late final List<PostImageTransform> _transforms;
  final Map<String, double> _imageAspects = {};

  int _activeImageIndex = 0;
  _EditTab _tab = _EditTab.size;
  AdjustSubTool _adjustTool = AdjustSubTool.brightness;

  // Snapshot of the crop box / rotation / focal point taken at the start of a pan, pinch or
  // turn — updates are always derived from it (not incrementally) so nothing drifts.
  Rect? _gestureStartBox;
  double _gestureStartRotation = 0;
  Offset _gestureStartFocalPoint = Offset.zero;

  PostImageTransform get _current => _transforms[_activeImageIndex];
  double _aspectFor(String path) => _imageAspects[path] ?? 1.0;
  double get _activeImageAspect => _aspectFor(_imagePaths[_activeImageIndex]);

  @override
  void initState() {
    super.initState();
    _imagePaths = List<String>.from(widget.customImagePaths ?? const []);
    _transforms =
        widget.initialTransforms != null &&
            widget.initialTransforms!.length == _imagePaths.length
        ? widget.initialTransforms!.map((t) => t.copy()).toList()
        : List.generate(_imagePaths.length, (_) => PostImageTransform());
    // This editor always fills its frame; "Original" keeps the photo's own shape and is
    // where a fresh photo starts (`ScenePhotoEditSize`). 1.0 holds its place until the
    // photo's real shape loads.
    final fresh = widget.initialTransforms == null;
    for (final t in _transforms) {
      t.fitMode = CropFitMode.fill;
      if (fresh) t.originalAspect = 1.0;
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
      final bytes = path.startsWith('assets/')
          ? (await rootBundle.load(path)).buffer.asUint8List()
          : await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final decoded = (await codec.getNextFrame()).image;
      if (!mounted || decoded.height == 0) return;
      setState(() {
        _imageAspects[path] = decoded.width / decoded.height;
        // Keep "Original" true to the photo once its size is known.
        for (var i = 0; i < _imagePaths.length; i++) {
          final t = _transforms[i];
          if (_imagePaths[i] == path && t.originalAspect != null) {
            t.originalAspect = _imageAspects[path];
            t.cropRect = null;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _imageAspects[path] = 1.0);
    }
  }

  // ---------------------------------------------------------------- size

  /// Applies to every photo, so a multi-photo post shares one shape.
  void _setSize(CropAspectRatio? ratio) {
    setState(() {
      for (var i = 0; i < _transforms.length; i++) {
        final t = _transforms[i];
        final imageAspect = _aspectFor(_imagePaths[i]);
        if (ratio == null) {
          t.originalAspect = imageAspect;
          t.cropRect = null;
        } else {
          final base = t.resolvedCropRect(imageAspect);
          t.originalAspect = null;
          t.aspectRatio = ratio;
          t.cropRect = CropCoverMath.relockToAspect(
            box: base,
            cropAspect: ratio.value,
            imageAspect: imageAspect,
          );
        }
      }
    });
  }

  bool _sizeSelected(CropAspectRatio? ratio) => ratio == null
      ? _current.originalAspect != null
      : _current.originalAspect == null && _current.aspectRatio == ratio;

  // ---------------------------------------------------------------- crop

  void _applyRotation(double degrees) {
    setState(() {
      _current.rotationDegrees = degrees;
      _current.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: _current.resolvedCropRect(_activeImageAspect),
        rotationDegrees: degrees,
        imageAspect: _activeImageAspect,
      );
    });
  }

  /// The quarter turn the photo is nearest, and how far it is straightened from it.
  double get _quarter =>
      ((_current.rotationDegrees + 45) / 90).floorToDouble() * 90;
  double get _straighten => _current.rotationDegrees - _quarter;

  void _onCropScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _current.resolvedCropRect(_activeImageAspect);
    _gestureStartRotation = _current.rotationDegrees;
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onCropScaleUpdate(ScaleUpdateDetails details, Size frame) {
    final startBox = _gestureStartBox;
    if (startBox == null) return;
    final imageAspect = _activeImageAspect;
    // A drag across the whole frame pans one box-width, so the photo tracks the finger.
    final delta = details.localFocalPoint - _gestureStartFocalPoint;
    final panned = CropCoverMath.translateBox(
      box: startBox,
      deltaNorm: -Offset(
        frame.width == 0 ? 0 : delta.dx / frame.width * startBox.width,
        frame.height == 0 ? 0 : delta.dy / frame.height * startBox.height,
      ),
    );
    final scaled = CropCoverMath.scaleBox(
      box: panned,
      scaleFactor: details.scale,
      cropAspect: _current.aspectValue,
      imageAspect: imageAspect,
    );
    final rotation = _gestureStartRotation + details.rotation * 180 / math.pi;
    setState(() {
      _current.rotationDegrees = rotation;
      _current.cropRect = CropCoverMath.clampBoxWithinRotatedImage(
        box: scaled,
        rotationDegrees: rotation,
        imageAspect: imageAspect,
      );
    });
  }

  void _resetCrop() {
    setState(() {
      final original = _current.originalAspect;
      final ratio = _current.aspectRatio;
      _current.resetCrop();
      _current.aspectRatio = ratio;
      _current.originalAspect = original;
    });
  }

  // ---------------------------------------------------------------- next

  void _next() {
    widget.onNext?.call(
      List<String>.from(_imagePaths),
      _transforms.map((t) => t.copy()).toList(),
      _activeImageIndex,
    );
  }

  Size _frameSize(double maxWidth, double maxHeight, double aspect) {
    var width = maxWidth;
    var height = width / aspect;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }
    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxWidth = mq.size.width - 24;
    final multiple = _imagePaths.length > 1;
    // Room for the tools under the frame; the board's 3:4 frame is 366 × 488.
    final maxHeight = math.max(
      200.0,
      mq.size.height -
          mq.padding.vertical -
          56 -
          12 -
          230 -
          (multiple ? 72 : 0),
    );
    final frame = _frameSize(
      maxWidth,
      math.min(maxHeight, maxWidth * 4 / 3),
      _current.aspectValue,
    );
    final interactive = _tab == _EditTab.crop;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: StudioColors.ink,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                onBack: widget.onClose ?? () => Navigator.pop(context),
                onNext: _next,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: maxWidth,
                height: math.min(maxHeight, maxWidth * 4 / 3),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox.fromSize(
                      size: frame,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: interactive ? _onCropScaleStart : null,
                        onScaleUpdate: interactive
                            ? (d) => _onCropScaleUpdate(d, frame)
                            : null,
                        onScaleEnd: interactive
                            ? (_) => _gestureStartBox = null
                            : null,
                        child: IgnorePointer(
                          child: PostCropPreview.buildTransformedContent(
                            imagePath: _imagePaths[_activeImageIndex],
                            transform: _current,
                            imageAspect: _activeImageAspect,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (multiple) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 2,
                    ),
                    clipBehavior: Clip.none,
                    itemCount: _imagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => _Thumb(
                      imagePath: _imagePaths[i],
                      transform: _transforms[i],
                      imageAspect: _aspectFor(_imagePaths[i]),
                      index: i,
                      active: i == _activeImageIndex,
                      onTap: () => setState(() => _activeImageIndex = i),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  math.max(30, mq.padding.bottom),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPills(),
                    const SizedBox(height: 22),
                    _buildSlider(),
                    const SizedBox(height: 22),
                    _ToolTabs(
                      selected: _tab,
                      onSelected: (t) => setState(() => _tab = t),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPills() {
    final pills = switch (_tab) {
      _EditTab.size => [
        for (final ratio in _sizes)
          _Pill(
            label: ratio?.label ?? 'Original',
            selected: _sizeSelected(ratio),
            onTap: () => _setSize(ratio),
          ),
      ],
      _EditTab.crop => [
        _Pill(
          label: 'Rotate',
          selected: false,
          onTap: () => _applyRotation(_current.rotationDegrees - 90),
        ),
        _Pill(
          label: 'Flip',
          selected: _current.flipHorizontal,
          onTap: () => setState(
            () => _current.flipHorizontal = !_current.flipHorizontal,
          ),
        ),
        _Pill(label: 'Reset', selected: false, onTap: _resetCrop),
      ],
      _EditTab.adjust => [
        // The note's three; Exposure stays in the model, neutral.
        for (final tool in const [
          AdjustSubTool.brightness,
          AdjustSubTool.contrast,
          AdjustSubTool.warmth,
        ])
          _Pill(
            label: switch (tool) {
              AdjustSubTool.brightness => 'Brightness',
              AdjustSubTool.contrast => 'Contrast',
              AdjustSubTool.exposure => 'Exposure',
              AdjustSubTool.warmth => 'Warmth',
            },
            selected: _adjustTool == tool,
            onTap: () => setState(() => _adjustTool = tool),
          ),
      ],
    };
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              pills[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildSliderOrNull() => switch (_tab) {
    _EditTab.size => null,
    _EditTab.crop => _ZeroSlider(
      value: _straighten,
      range: 45,
      label: '${_straighten >= 0.5 ? '+' : ''}${_straighten.round()}°',
      semanticLabel: 'Straighten',
      onChanged: (v) => _applyRotation(_quarter + v),
    ),
    _EditTab.adjust => _ZeroSlider(
      value: _current.adjustValueFor(_adjustTool) - 50,
      range: 50,
      label: _signed((_current.adjustValueFor(_adjustTool) - 50).round()),
      semanticLabel: _adjustTool.name,
      onChanged: (v) =>
          setState(() => _current.setAdjustValue(_adjustTool, v + 50)),
    ),
  };

  /// The Size tab keeps the slider's room (46) so the pills don't jump.
  Widget _buildSlider() => _buildSliderOrNull() ?? const SizedBox(height: 46);

  static String _signed(int v) => v > 0 ? '+$v' : '$v';
}

/// Back 22 in a 44 target, "Next" 15/500 as text; Gallery White (12 8 padding).
class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.square(
                  dimension: StudioSize.tapTarget,
                  child: Center(
                    child: StudioIcon(
                      StudioIcons.backBold,
                      size: 22,
                      color: StudioColors.galleryWhite,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onNext,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      'Next',
                      style: StudioType.sans(
                        15,
                        weight: StudioType.medium,
                        color: StudioColors.galleryWhite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark pill: 34 tall, 14 sides, 13. Selected: Gallery White fill, Ink 500; others a 1 px
/// #3A3A3A outline with #C8C8C8 text.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _outline = Color(0xFF3A3A3A);
  static const _text = StudioColors.onDarkChipText;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? StudioColors.galleryWhite : null,
            border: selected ? null : Border.all(color: _outline),
            borderRadius: BorderRadius.circular(StudioRadius.round),
          ),
          child: Text(
            label,
            style: StudioType.label13(
              weight: selected ? StudioType.medium : StudioType.regular,
              color: selected ? StudioColors.ink : _text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zero-centred slider (`ScenePhotoEdit`): the value in Mono 13 over a 2 px #3A3A3A track
/// with a 12-tall centre tick, a Gallery White fill from the centre to the 20 thumb.
class _ZeroSlider extends StatelessWidget {
  const _ZeroSlider({
    required this.value,
    required this.range,
    required this.label,
    required this.semanticLabel,
    required this.onChanged,
  });

  final double value;

  /// The slider runs from -range to +range.
  final double range;
  final String label;
  final String semanticLabel;
  final ValueChanged<double> onChanged;

  static const _track = Color(0xFF3A3A3A);
  static const _tick = StudioColors.onDarkTertiary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: StudioType.mono13(color: StudioColors.galleryWhite),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final t = ((value / range).clamp(-1.0, 1.0) + 1) / 2;
              void update(Offset local) => onChanged(
                ((local.dx / width).clamp(0.0, 1.0) * 2 - 1) * range,
              );
              return Semantics(
                slider: true,
                label: semanticLabel,
                value: label,
                child: Listener(
                  // A touch sets the value at once; dragging follows the finger.
                  onPointerDown: (e) => update(e.localPosition),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) => update(d.localPosition),
                    // Double tap goes back to zero.
                    onDoubleTap: () => onChanged(0),
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 11,
                            height: 2,
                            child: const ColoredBox(color: _track),
                          ),
                          Positioned(
                            left: width / 2,
                            top: 6,
                            width: 1,
                            height: 12,
                            child: const ColoredBox(color: _tick),
                          ),
                          Positioned(
                            left: math.min(width / 2, width * t),
                            width: (width * t - width / 2).abs(),
                            top: 11,
                            height: 2,
                            child: const ColoredBox(
                              color: StudioColors.galleryWhite,
                            ),
                          ),
                          Positioned(
                            left: width * t - 10,
                            top: 2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: StudioColors.galleryWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Size, Crop, Adjust as text tabs 36 apart: 44 tall, 15/500, the open one Gallery White with
/// a 2 px underline, the others #8A8A8A.
class _ToolTabs extends StatelessWidget {
  const _ToolTabs({required this.selected, required this.onSelected});

  static const _off = StudioColors.onDarkOff;

  final _EditTab selected;
  final ValueChanged<_EditTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final tab in _EditTab.values) ...[
          if (tab != _EditTab.size) const SizedBox(width: 36),
          StudioTapArea(child: Semantics(
            button: true,
            selected: tab == selected,
            child: GestureDetector(
              onTap: () => onSelected(tab),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab == selected
                          ? StudioColors.galleryWhite
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  switch (tab) {
                    _EditTab.size => 'Size',
                    _EditTab.crop => 'Crop',
                    _EditTab.adjust => 'Adjust',
                  },
                  style: StudioType.sans(
                    15,
                    weight: StudioType.medium,
                    color: tab == selected ? StudioColors.galleryWhite : _off,
                  ),
                ),
              ),
            ),
          )),
        ],
      ],
    );
  }
}

/// 42 × 56 thumb (radius 6), the shown one with a 2 px Gallery White outline 2 outside.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.imagePath,
    required this.transform,
    required this.imageAspect,
    required this.index,
    required this.active,
    required this.onTap,
  });

  final String imagePath;
  final PostImageTransform transform;
  final double imageAspect;
  final int index;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Photo ${index + 1}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 42,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: IgnorePointer(
                    child: PostCropPreview.buildTransformedContent(
                      imagePath: imagePath,
                      transform: transform,
                      imageAspect: imageAspect,
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  left: -4,
                  top: -4,
                  right: -4,
                  bottom: -4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: StudioColors.galleryWhite,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

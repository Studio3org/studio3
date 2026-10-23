import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_image_transform.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../utils/crop_cover_math.dart'
    show CropAspectRatio, CropCoverMath, CropFitMode;
import '../widgets/post_crop_preview.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_on_image.dart';

/// "Set your cover" (`PostCover`, `NotePostCover`): the piece-posting framing step. Dark in
/// both themes. One 3:4 frame (width inside 24 margins) with a thirds grid that the photo is
/// dragged or pinched into; "Cover" and "1 / N" as plain white labels; a 62 × 83 strip to
/// switch photos (the first is the cover); the guidance copy.
///
/// Framing only: piece photos are never color edited, rotated or flipped (the Flow 4 card).
/// It returns the same paths and transforms as the shared edit step, so the details step and
/// the upload are unchanged. Scenes keep their own edit step.
///
/// Long-press a thumbnail to drag it into a new place (the first is the cover); the dashed
/// tile goes back to the gallery to add photos, hidden at [maxPhotos]. Back (and system back)
/// returns to the gallery with the order and framing kept.
class PostCoverPage extends StatefulWidget {
  const PostCoverPage({
    super.key,
    required this.imagePaths,
    this.initialImageIndex = 0,
    this.initialTransforms,
    this.maxPhotos = 4,
    required this.onBack,
    required this.onAddPhotos,
    required this.onNext,
  });

  final List<String> imagePaths;
  final int initialImageIndex;
  final List<PostImageTransform>? initialTransforms;

  /// The gallery's photo limit, named in the guidance ("up to N angles").
  final int maxPhotos;

  /// Back to the gallery, with the photos in their current order and framing.
  final void Function(
    List<String> imagePaths,
    List<PostImageTransform> transforms,
  )
  onBack;

  /// The dashed tile: back to the gallery to pick more, keeping what is here.
  final void Function(
    List<String> imagePaths,
    List<PostImageTransform> transforms,
  )
  onAddPhotos;
  final void Function(
    List<String> imagePaths,
    List<PostImageTransform> transforms,
    int previewImageIndex,
  )
  onNext;

  @override
  State<PostCoverPage> createState() => _PostCoverPageState();
}

class _PostCoverPageState extends State<PostCoverPage> {
  late final List<String> _paths = List<String>.from(widget.imagePaths);
  late final List<PostImageTransform> _transforms;
  final Map<String, double> _imageAspects = {};
  late int _active;
  Rect? _gestureStartBox;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    final given = widget.initialTransforms;
    _transforms = given != null && given.length == widget.imagePaths.length
        ? given.map((t) => t.copy()).toList()
        : List.generate(widget.imagePaths.length, (_) => PostImageTransform());
    // Framing only: every piece photo is a 3:4 fill with no rotation, flip or adjustments.
    for (final t in _transforms) {
      // A box framed for another shape (e.g. after switching post type) starts over.
      if (t.aspectRatio != CropAspectRatio.ratio3x4 ||
          t.fitMode != CropFitMode.fill) {
        t.cropRect = null;
      }
      t.aspectRatio = CropAspectRatio.ratio3x4;
      t.fitMode = CropFitMode.fill;
      t.rotationDegrees = 0;
      t.flipHorizontal = false;
      t.flipVertical = false;
      t.resetAdjust();
    }
    _active = widget.initialImageIndex.clamp(0, widget.imagePaths.length - 1);
    for (final path in widget.imagePaths.toSet()) {
      _loadAspect(path);
    }
  }

  Future<void> _loadAspect(String path) async {
    try {
      final bytes = path.startsWith('assets/')
          ? (await rootBundle.load(path)).buffer.asUint8List()
          : await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      if (!mounted || image.height == 0) return;
      setState(() => _imageAspects[path] = image.width / image.height);
    } catch (_) {
      if (mounted) setState(() => _imageAspects[path] = 1.0);
    }
  }

  double _aspect(int index) => _imageAspects[_paths[index]] ?? 1.0;

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _transforms[_active].resolvedCropRect(_aspect(_active));
    _gestureStartFocal = details.localFocalPoint;
  }

  /// Drag pans, pinch zooms; both derived from the gesture's start so nothing drifts.
  void _onScaleUpdate(ScaleUpdateDetails details, Size frame) {
    final start = _gestureStartBox;
    if (start == null) return;
    final imageAspect = _aspect(_active);
    final delta = details.localFocalPoint - _gestureStartFocal;
    final panned = CropCoverMath.translateBox(
      box: start,
      deltaNorm: -Offset(
        frame.width == 0 ? 0 : delta.dx / frame.width * start.width,
        frame.height == 0 ? 0 : delta.dy / frame.height * start.height,
      ),
    );
    final scaled = CropCoverMath.scaleBox(
      box: panned,
      scaleFactor: details.scale,
      cropAspect: CropAspectRatio.ratio3x4.value,
      imageAspect: imageAspect,
    );
    setState(() => _transforms[_active].cropRect = scaled);
  }

  List<PostImageTransform> get _copies =>
      _transforms.map((t) => t.copy()).toList();

  void _next() => widget.onNext(List<String>.from(_paths), _copies, _active);

  void _back() => widget.onBack(List<String>.from(_paths), _copies);

  /// Moves a photo; the one on show stays on show wherever it lands.
  void _reorder(int from, int to) {
    if (to == from) return;
    final shown = _transforms[_active];
    setState(() {
      _paths.insert(to, _paths.removeAt(from));
      _transforms.insert(to, _transforms.removeAt(from));
      _active = _transforms.indexOf(shown);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final count = _paths.length;
    final frameWidth = mq.size.width - 48;
    final frame = Size(frameWidth, frameWidth * 4 / 3);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: StudioColors.ink,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onBack: _back, onNext: _next),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      mq.padding.bottom + 24,
                    ),
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox.fromSize(
                            size: frame,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: _onScaleStart,
                                  onScaleUpdate: (d) =>
                                      _onScaleUpdate(d, frame),
                                  onScaleEnd: (_) => _gestureStartBox = null,
                                  child:
                                      PostCropPreview.buildTransformedContent(
                                        imagePath: _paths[_active],
                                        transform: _transforms[_active],
                                        imageAspect: _aspect(_active),
                                      ),
                                ),
                                const IgnorePointer(child: _ThirdsGrid()),
                                if (_active == 0)
                                  const Positioned(
                                    left: 2,
                                    top: 4,
                                    child: IgnorePointer(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        child: StudioImageLabel(
                                          'Cover',
                                          mono: false,
                                          size: 12,
                                          weight: StudioType.medium,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (count > 1)
                                  Positioned(
                                    right: 2,
                                    bottom: 4,
                                    child: IgnorePointer(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        child: StudioImageLabel(
                                          '${_active + 1} / $count',
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Drag or pinch to fit the frame',
                        style: StudioType.caption12(
                          color: StudioColors.onDarkSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 83 + 6 + 4,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(2, 6, 4, 4),
                          clipBehavior: Clip.none,
                          buildDefaultDragHandles: false,
                          itemCount: count,
                          onReorderItem: _reorder,
                          proxyDecorator: (child, _, _) => Material(
                            type: MaterialType.transparency,
                            child: child,
                          ),
                          itemBuilder: (context, i) => Padding(
                            key: ObjectKey(_transforms[i]),
                            padding: const EdgeInsets.only(right: 10),
                            child: ReorderableDelayedDragStartListener(
                              index: i,
                              enabled: count > 1,
                              child: _Thumb(
                                imagePath: _paths[i],
                                transform: _transforms[i],
                                imageAspect: _aspect(i),
                                index: i,
                                active: i == _active,
                                onTap: () => setState(() => _active = i),
                              ),
                            ),
                          ),
                          footer: count < widget.maxPhotos
                              ? _AddTile(
                                  onTap: () => widget.onAddPhotos(
                                    List<String>.from(_paths),
                                    _copies,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Just the piece, up to ${widget.maxPhotos} angles',
                        style: StudioType.body14(
                          weight: StudioType.medium,
                          color: StudioColors.galleryWhite,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Drag to reorder. The first photo is the cover. Studio and process shots go in a Scene.',
                        style: StudioType.caption12(
                          height: 1.45,
                          color: StudioColors.onDarkSecondary,
                        ),
                      ),
                    ],
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

/// Back (22, 44 target), "Set your cover" 16/500, Next 15/500 text, all Gallery White.
class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SizedBox(
        height: 44,
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
                  dimension: 44,
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
            Expanded(
              child: Text(
                'Set your cover',
                textAlign: TextAlign.center,
                style: StudioType.sans(
                  16,
                  weight: StudioType.medium,
                  color: StudioColors.galleryWhite,
                ),
              ),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onNext,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 44,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Rule-of-thirds lines, 1 px white at 22 %.
class _ThirdsGrid extends StatelessWidget {
  const _ThirdsGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ThirdsPainter());
  }
}

class _ThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x38FFFFFF); // rgba(255,255,255,0.22)
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawRect(Rect.fromLTWH(size.width * f, 0, 1, size.height), paint);
      canvas.drawRect(Rect.fromLTWH(0, size.height * f, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => false;
}

/// 62 × 83 framed thumbnail, radius 6; the active one has a 2 px Gallery White outline 2
/// outside it; the first carries "Cover" in Mono 9.
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
      label: index == 0 ? 'Photo 1, cover' : 'Photo ${index + 1}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // The photo is under IgnorePointer, so the tile itself takes the tap.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 62,
          height: 83,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: PostCropPreview.buildTransformedContent(
                          imagePath: imagePath,
                          transform: transform,
                          imageAspect: imageAspect,
                        ),
                      ),
                      if (index == 0)
                        // Board: left -4 / bottom -2 with 8 14 padding.
                        const Positioned(
                          left: 10,
                          bottom: 6,
                          child: StudioImageLabel('Cover', size: 9),
                        ),
                    ],
                  ),
                ),
              ),
              // CSS outline: 2 px, 2 outside the tile, so it takes no layout space.
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

/// 62 × 83 dashed tile (1 px #4A4A4A, radius 6) with a 20 plus in Secondary-on-dark.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const CustomPaint(
          painter: _DashedBorderPainter(),
          child: SizedBox(
            width: 62,
            height: 83,
            child: Center(
              child: StudioIcon(
                StudioIcons.newFolder,
                size: 20,
                color: StudioColors.onDarkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `1px dashed`: 3 on, 3 off around the rounded box.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ).deflate(0.5),
      );
    final paint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => false;
}

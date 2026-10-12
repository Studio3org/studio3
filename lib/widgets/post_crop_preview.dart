import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_image_transform.dart';
import '../utils/crop_cover_math.dart' show CropFitMode;
import '../utils/image_adjust_math.dart';

/// True-to-output preview of a post image: same rotation/flip/crop-box/
/// color-adjust math as the edit screen, so every "review" step in the
/// posting flow honestly reflects what will be uploaded.
class PostCropPreview extends StatefulWidget {
  const PostCropPreview({
    super.key,
    required this.imagePath,
    required this.transform,
    this.borderRadius = BorderRadius.zero,
  });

  final String imagePath;
  final PostImageTransform transform;
  final BorderRadius borderRadius;

  /// The final cropped/output look: resolves the transform's crop box and
  /// renders exactly what will be uploaded — Fill maps the box to fill the
  /// frame edge-to-edge; Fit letterboxes the box (preserving its own
  /// aspect) centered in the frame. Shared by every read-only preview in
  /// the posting flow (thumbnails, review screen) and by the live editor
  /// itself (Fill mode wraps this in a pan/pinch-zoom/rotate gesture
  /// detector; Fit mode shows it as-is, non-interactive).
  static Widget buildTransformedContent({
    required String imagePath,
    required PostImageTransform transform,
    required double imageAspect,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameSize = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = transform.resolvedCropRect(imageAspect);
        final refSize = Size(frameSize.width, frameSize.width / imageAspect);

        final Size windowSize;
        if (transform.fitMode == CropFitMode.fill) {
          windowSize = frameSize;
        } else {
          final subimageAspect = (rect.width / rect.height) * imageAspect;
          final cropAspect = frameSize.width / frameSize.height;
          if (subimageAspect >= cropAspect) {
            windowSize = Size(frameSize.width, frameSize.width / subimageAspect);
          } else {
            windowSize = Size(frameSize.height * subimageAspect, frameSize.height);
          }
        }

        final scale = windowSize.width / (rect.width * refSize.width);
        final pivotInRef = Offset(
          rect.center.dx * refSize.width,
          rect.center.dy * refSize.height,
        );

        final image = _renderWindow(
          refImage: _flippedImage(imagePath, transform),
          refSize: refSize,
          pivotInRef: pivotInRef,
          scale: scale,
          rotationRadians: transform.rotationDegrees * math.pi / 180,
          windowSize: windowSize,
          frameSize: frameSize,
        );

        return ColoredBox(
          color: Colors.black,
          child: _applyColorAdjust(image, transform),
        );
      },
    );
  }

  /// Renders [refImage] (already flipped, not yet rotated) scaled by
  /// [scale] and rotated by [rotationRadians] about [pivotInRef], mapping
  /// that pivot to the center of a [windowSize] window, clipped to that
  /// window, itself centered within [frameSize] (letterbox bars show
  /// through as whatever background the caller paints behind this).
  ///
  /// Coordinates: [refSize] is the whole source image laid out at
  /// `frameSize.width` wide, at its own natural aspect ratio — a fixed,
  /// arbitrary reference scale used only so every distance in this
  /// function is a concrete pixel value. [OverflowBox] lets the
  /// [refSize]-sized child lay out at its full (usually larger-than-window)
  /// size despite the tight constraints flowing down from [frameSize];
  /// [ClipRect] then crops the transformed paint to the visible window.
  static Widget _renderWindow({
    required Widget refImage,
    required Size refSize,
    required Offset pivotInRef,
    required double scale,
    required double rotationRadians,
    required Size windowSize,
    required Size frameSize,
  }) {
    final matrix = Matrix4.identity()
      ..translateByDouble(windowSize.width / 2, windowSize.height / 2, 0, 1)
      ..rotateZ(rotationRadians)
      ..scaleByDouble(scale, scale, 1.0, 1)
      ..translateByDouble(-pivotInRef.dx, -pivotInRef.dy, 0, 1);

    final windowed = ClipRect(
      child: OverflowBox(
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: Alignment.topLeft,
        child: Transform(
          alignment: Alignment.topLeft,
          transform: matrix,
          child: SizedBox(
            width: refSize.width,
            height: refSize.height,
            child: refImage,
          ),
        ),
      ),
    );

    return Center(
      child: SizedBox(
        width: windowSize.width,
        height: windowSize.height,
        child: windowed,
      ),
    );
  }

  /// The source image with flip applied — rotation is handled by
  /// [_renderWindow]'s matrix (about the crop-box pivot), not here, so it
  /// stays consistent between the windowed (output) and full-image
  /// (editor) render paths.
  static Widget _flippedImage(
    String imagePath,
    PostImageTransform transform,
  ) {
    final flipX = transform.flipHorizontal ? -1.0 : 1.0;
    final flipY = transform.flipVertical ? -1.0 : 1.0;
    if (flipX == 1.0 && flipY == 1.0) return sourceImage(imagePath);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(flipX, flipY, 1.0, 1),
      child: sourceImage(imagePath),
    );
  }

  static Widget _applyColorAdjust(Widget image, PostImageTransform transform) {
    if (ImageAdjustMath.isNeutral(
      brightness: transform.brightness,
      contrast: transform.contrast,
      exposure: transform.exposure,
    )) {
      return image;
    }
    return ColorFiltered(
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

  /// Loads [path] as an asset (bundled dummy grid images) or a real file
  /// (gallery-picked photos), matching the dual-path handling used
  /// throughout the posting flow.
  static Widget sourceImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  State<PostCropPreview> createState() => _PostCropPreviewState();
}

class _PostCropPreviewState extends State<PostCropPreview> {
  double? _imageAspect;

  @override
  void initState() {
    super.initState();
    _loadAspect();
  }

  @override
  void didUpdateWidget(covariant PostCropPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _imageAspect = null;
      _loadAspect();
    }
  }

  Future<void> _loadAspect() async {
    final path = widget.imagePath;
    try {
      ui.Image decoded;
      if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        decoded = (await codec.getNextFrame()).image;
      } else {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        decoded = (await codec.getNextFrame()).image;
      }
      final w = decoded.width.toDouble();
      final h = decoded.height.toDouble();
      if (!mounted || h == 0) return;
      setState(() => _imageAspect = w / h);
    } catch (_) {
      if (mounted) setState(() => _imageAspect = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AspectRatio(
        aspectRatio: widget.transform.aspectRatio.value,
        child: PostCropPreview.buildTransformedContent(
          imagePath: widget.imagePath,
          transform: widget.transform,
          imageAspect: _imageAspect ?? 1.0,
        ),
      ),
    );
  }
}

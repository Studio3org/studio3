import 'dart:ui' show Rect;

import '../utils/crop_cover_math.dart';

/// Per-image crop transform state for the posting edit flow.
class PostImageTransform {
  PostImageTransform({
    this.aspectRatio = CropAspectRatio.ratio3x4,
    this.rotationDegrees = 0,
    this.cropRect,
    this.fitMode = CropFitMode.fill,
    this.flipVertical = false,
    this.flipHorizontal = false,
    this.brightness = 50,
    this.contrast = 50,
    this.exposure = 50,
    this.warmth = 50,
    this.originalAspect,
  });

  CropAspectRatio aspectRatio;
  double rotationDegrees;
  /// The draggable crop box, normalized to the displayed image's own
  /// bounds (`left`/`right` as fractions of image width, `top`/`bottom` as
  /// fractions of image height — see `crop_cover_math.dart`'s doc comment
  /// for the full coordinate contract). `null` means "use the computed
  /// default for the current [fitMode]/[aspectRatio]" — see
  /// [resolvedCropRect] — so a fresh [PostImageTransform] always has a
  /// sensible box without every call site needing to know `imageAspect`
  /// up front.
  Rect? cropRect;
  /// Fill locks the box to [aspectRatio] (content fills the output frame
  /// edge-to-edge); Fit lets the box take any shape (content is
  /// letterboxed into the output frame, preserving the box's own aspect).
  CropFitMode fitMode;
  bool flipVertical;
  bool flipHorizontal;
  /// Adjust sliders — 0–100, 50 is neutral.
  double brightness;
  double contrast;
  double exposure;
  double warmth;

  /// Set when "Original" is chosen (`ScenePhotoEditSize`): the output keeps the photo's own
  /// width / height instead of [aspectRatio].
  double? originalAspect;

  /// Width / height of the output.
  double get aspectValue => originalAspect ?? aspectRatio.value;

  void reset() {
    resetCrop();
    resetAdjust();
  }

  void resetCrop() {
    aspectRatio = CropAspectRatio.ratio3x4;
    originalAspect = null;
    rotationDegrees = 0;
    cropRect = null;
    fitMode = CropFitMode.fill;
    flipVertical = false;
    flipHorizontal = false;
  }

  void resetAdjust() {
    brightness = 50;
    contrast = 50;
    exposure = 50;
    warmth = 50;
  }

  PostImageTransform copy() => PostImageTransform(
        aspectRatio: aspectRatio,
        rotationDegrees: rotationDegrees,
        cropRect: cropRect,
        fitMode: fitMode,
        flipVertical: flipVertical,
        flipHorizontal: flipHorizontal,
        brightness: brightness,
        contrast: contrast,
        exposure: exposure,
        warmth: warmth,
        originalAspect: originalAspect,
      );

  double adjustValueFor(AdjustSubTool tool) => switch (tool) {
        AdjustSubTool.brightness => brightness,
        AdjustSubTool.contrast => contrast,
        AdjustSubTool.exposure => exposure,
        AdjustSubTool.warmth => warmth,
      };

  void setAdjustValue(AdjustSubTool tool, double value) {
    final clamped = value.clamp(0.0, 100.0);
    switch (tool) {
      case AdjustSubTool.brightness:
        brightness = clamped;
      case AdjustSubTool.contrast:
        contrast = clamped;
      case AdjustSubTool.exposure:
        exposure = clamped;
      case AdjustSubTool.warmth:
        warmth = clamped;
    }
  }

  /// The crop box currently in effect. Fit is always the whole image —
  /// fully static, no user adjustment — so any stored [cropRect] is only
  /// used in Fill mode; it's preserved (not cleared) across a trip through
  /// Fit so switching back to Fill restores exactly where the user left it.
  Rect resolvedCropRect(double imageAspect) {
    if (fitMode == CropFitMode.fit) return CropCoverMath.defaultFitBox();
    return cropRect ?? CropCoverMath.defaultFillBox(aspectValue, imageAspect);
  }
}

/// Active crop sub-tool within crop mode.
enum CropSubTool {
  rotate,
  flipVertical,
  flipHorizontal,
}

/// Active adjust sub-tool within adjust mode.
enum AdjustSubTool {
  brightness,
  contrast,
  exposure,
  warmth,
}

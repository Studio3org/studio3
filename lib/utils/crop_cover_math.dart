import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Crop frame aspect ratios (width / height).
enum CropAspectRatio {
  ratio3x4(3 / 4, 'Portrait'),
  ratio16x9(16 / 9, 'Landscape');

  const CropAspectRatio(this.value, this.label);

  final double value;
  final String label;
}

/// How the crop box behaves: [fill] locks the box to the selected
/// [CropAspectRatio] (its content fills the output frame edge-to-edge);
/// [fit] lets the box take any shape/size (its content is letterboxed into
/// the output frame, preserving the box's own aspect, nothing cropped).
enum CropFitMode { fill, fit }

/// Geometry for the draggable/resizable crop box.
///
/// All rects here are normalized to the **displayed image's own bounds**:
/// `left`/`right` are fractions of the image's width, `top`/`bottom` are
/// fractions of its height (both in `[0,1]`) — independent of screen pixel
/// size, so the same rect means the same crop whether it's being dragged
/// in the editor or resolved for a thumbnail or the final render.
///
/// Because `x` fractions and `y` fractions scale by different physical
/// units (image width vs. image height), a box's on-screen aspect ratio is
/// `(box.width * imageAspect) / box.height` — not `box.width / box.height`
/// directly. Aspect-locking math below accounts for this via
/// `k = cropAspect / imageAspect`, the box's *fraction-space* aspect that
/// corresponds to a true on-screen `cropAspect`.
abstract final class CropCoverMath {
  CropCoverMath._();

  static const double minBoxFraction = 0.12;

  /// Largest aspect-locked box centered in the image — the default framing
  /// for Fill mode (equivalent to the old cover-scale's role, expressed as
  /// a rect instead of a scale).
  static Rect defaultFillBox(double cropAspect, double imageAspect) {
    final k = cropAspect / imageAspect;
    final double w, h;
    if (k <= 1) {
      w = k;
      h = 1;
    } else {
      w = 1;
      h = 1 / k;
    }
    return Rect.fromCenter(center: const Offset(0.5, 0.5), width: w, height: h);
  }

  /// The whole image — Fit mode defaults to "show everything."
  static Rect defaultFitBox() => const Rect.fromLTRB(0, 0, 1, 1);

  /// Resizes [box] around its own center by [scaleFactor] (>1 = zoom in —
  /// shrink the box, showing less of the image magnified; <1 = zoom out —
  /// grow the box, showing more) — keeping the Fill aspect lock
  /// (`cropAspect/imageAspect`). Clamped between `defaultFillBox` (max
  /// zoom-out: the box can never grow past what's needed to fill the
  /// frame, so no empty space is ever revealed) and [minBoxFraction] (max
  /// zoom-in).
  static Rect scaleBox({
    required Rect box,
    required double scaleFactor,
    required double cropAspect,
    required double imageAspect,
  }) {
    if (scaleFactor <= 0 || scaleFactor.isNaN) return box;
    final k = cropAspect / imageAspect;
    final maxBox = defaultFillBox(cropAspect, imageAspect);
    var w = (box.width / scaleFactor).clamp(minBoxFraction, maxBox.width);
    var h = w / k;
    if (h > maxBox.height) {
      h = maxBox.height;
      w = h * k;
    }
    return Rect.fromCenter(center: box.center, width: w, height: h);
  }

  /// Repositions [box] by [deltaNorm] (normalized like above), clamped so
  /// it can't be dragged outside the image.
  static Rect translateBox({required Rect box, required Offset deltaNorm}) {
    final shifted = box.shift(deltaNorm);
    var dx = 0.0, dy = 0.0;
    if (shifted.left < 0) dx = -shifted.left;
    if (shifted.right > 1) dx = 1 - shifted.right;
    if (shifted.top < 0) dy = -shifted.top;
    if (shifted.bottom > 1) dy = 1 - shifted.bottom;
    return shifted.shift(Offset(dx, dy));
  }

  /// Re-locks [box] to `cropAspect/imageAspect`, preserving its center and
  /// shrinking as little as possible, clamped inside `[0,1]²`. Used when
  /// switching aspect ratios in Fill mode, or switching Fit→Fill.
  static Rect relockToAspect({
    required Rect box,
    required double cropAspect,
    required double imageAspect,
  }) {
    final k = cropAspect / imageAspect;
    final center = box.center;
    var w = box.width;
    var h = w / k;
    if (h > box.height) {
      h = box.height;
      w = h * k;
    }
    var rect = Rect.fromCenter(center: center, width: w, height: h);
    if (rect.width > 1 || rect.height > 1) {
      return defaultFillBox(cropAspect, imageAspect);
    }
    var dx = 0.0, dy = 0.0;
    if (rect.left < 0) dx = -rect.left;
    if (rect.right > 1) dx = 1 - rect.right;
    if (rect.top < 0) dy = -rect.top;
    if (rect.bottom > 1) dy = 1 - rect.bottom;
    return rect.shift(Offset(dx, dy));
  }

  /// Keeps [box] valid while the straighten dial rotates the image content
  /// about the box's own center: repositions (never resizes) [box] so its
  /// rotated footprint stays within the image bounds. This is an exact
  /// solution to "does a rotated rect of this size fit, positioned
  /// somewhere, inside an axis-aligned image" (not an approximation) —
  /// it computes the box's own rotated bounding box and clamps the box's
  /// center to keep that bounding box inside the image. If the box's
  /// rotated bounding box is simply larger than the image on some axis (an
  /// oversized box at a steep angle), that axis falls back to centering
  /// rather than leaving the box in an unresolvable position.
  static Rect clampBoxWithinRotatedImage({
    required Rect box,
    required double rotationDegrees,
    required double imageAspect,
  }) {
    if (rotationDegrees % 360 == 0) return box;

    final boxWMetric = box.width * imageAspect;
    final boxHMetric = box.height;
    final rad = rotationDegrees * math.pi / 180;
    final c = math.cos(rad).abs();
    final s = math.sin(rad).abs();
    final bboxW = boxWMetric * c + boxHMetric * s;
    final bboxH = boxWMetric * s + boxHMetric * c;

    final centerXMetric = box.center.dx * imageAspect;
    final centerYMetric = box.center.dy;

    final minCx = bboxW / 2, maxCx = imageAspect - bboxW / 2;
    final minCy = bboxH / 2, maxCy = 1.0 - bboxH / 2;

    final clampedCx =
        minCx <= maxCx ? centerXMetric.clamp(minCx, maxCx) : imageAspect / 2;
    final clampedCy = minCy <= maxCy ? centerYMetric.clamp(minCy, maxCy) : 0.5;

    final dxFrac = (clampedCx - centerXMetric) / imageAspect;
    final dyFrac = clampedCy - centerYMetric;
    return box.shift(Offset(dxFrac, dyFrac));
  }
}

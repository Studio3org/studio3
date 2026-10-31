import 'dart:math' as math;

/// Builds a [ColorFilter.matrix] for brightness / contrast / exposure / warmth.
/// Each value is 0–100 with 50 as neutral (no change). Warmth shifts red up and blue down
/// (or the reverse below 50).
abstract final class ImageAdjustMath {
  ImageAdjustMath._();

  static List<double> combinedMatrix({
    required double brightness,
    required double contrast,
    required double exposure,
    double warmth = 50,
  }) {
    final warm = (warmth - 50) / 50 * 0.12;
    final brightnessOffset = (brightness - 50) / 50 * 0.55;
    final contrastScale = 1 + (contrast - 50) / 50 * 1.4;
    final exposureScale = math.pow(2, (exposure - 50) / 18).toDouble();

    final scale = contrastScale * exposureScale;
    // Flutter's matrix takes its offset column in 0–255, not 0–1 (see the invert example on
    // `ColorFilter.matrix`). Left in 0–1, brightness and warmth did nothing and contrast only
    // scaled instead of pivoting around mid-grey.
    final offset = (brightnessOffset + (1 - contrastScale) * 0.5) * 255;
    final warmOffset = warm * 255;

    return [
      scale, 0, 0, 0, offset + warmOffset,
      0, scale, 0, 0, offset,
      0, 0, scale, 0, offset - warmOffset,
      0, 0, 0, 1, 0,
    ];
  }

  static bool isNeutral({
    required double brightness,
    required double contrast,
    required double exposure,
    double warmth = 50,
  }) =>
      (brightness - 50).abs() < 0.01 &&
      (contrast - 50).abs() < 0.01 &&
      (exposure - 50).abs() < 0.01 &&
      (warmth - 50).abs() < 0.01;
}

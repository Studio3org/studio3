import 'package:flutter/material.dart';

/// Phone Figma type (11–14) stays 1:1 on phones. Tablets get a bump so the
/// same sizes don't look tiny on a large canvas. System accessibility scale
/// is kept and multiplied by the layout bump.
abstract final class AppTextScale {
  static const double phoneShortestSide = 600;
  static const double largeTabletShortestSide = 900;

  static const double phone = 1.0;
  static const double tablet = 1.18;
  static const double largeTablet = 1.25;

  static double factorFor(double shortestSide) {
    if (shortestSide >= largeTabletShortestSide) return largeTablet;
    if (shortestSide >= phoneShortestSide) return tablet;
    return phone;
  }

  static TextScaler scalerOf(MediaQueryData media) {
    final bump = factorFor(media.size.shortestSide);
    final system = media.textScaler.scale(14) / 14;
    return TextScaler.linear((system * bump).clamp(0.8, 1.85));
  }
}

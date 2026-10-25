import 'package:flutter/material.dart';

/// Multiplier on Figma phone type (11–14px) so it stays readable on device.
/// Phone is bumped too — a 1.0 factor is why the last change was invisible
/// on phones and on a phone-sized emulator.
abstract final class AppTextScale {
  static const double phoneShortestSide = 600;
  static const double largeTabletShortestSide = 900;

  static const double phone = 1.15;
  static const double tablet = 1.28;
  static const double largeTablet = 1.35;

  static double factorFor(double shortestSide) {
    if (shortestSide >= largeTabletShortestSide) return largeTablet;
    if (shortestSide >= phoneShortestSide) return tablet;
    return phone;
  }

  static TextScaler scalerOf(MediaQueryData media) {
    final bump = factorFor(media.size.shortestSide);
    final system = media.textScaler.scale(14) / 14;
    return TextScaler.linear((system * bump).clamp(0.8, 2.0));
  }
}

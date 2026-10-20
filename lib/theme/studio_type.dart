import 'package:flutter/material.dart';

/// New-UI text (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 3; `HandoffRules` "Type").
///
/// * **Geist** for all UI, at 400 and 500 only (500 = titles, names, buttons, selected).
/// * **Geist Mono** for facts only: dates, times, counts, dimensions, chips, tags, codes,
///   record numbers — never sentences, names, prices or shipping times.
/// * Outfit is the wordmark only, and ships as a logo file (`assets/brand/`), not text.
///
/// Every style sets an explicit [TextStyle.height] with even leading so Flutter lays text
/// out in the same line box as the boards' CSS. Where a board sets no `line-height`
/// ("normal"), the default is [normalLineHeight]; pass the board's own `line-height` where
/// it sets one (e.g. 1.1, 1.45, 1.5).
///
/// Colors are not baked in: pass `color:` from `context.studio`.
abstract final class StudioType {
  static const String geist = 'Geist';
  static const String geistMono = 'GeistMono';

  /// CSS `line-height: normal` for Geist / Geist Mono at [size], as Chrome computes it: the
  /// font's ascent (1005/1000 em) and descent (295/1000 em) are each rounded to whole
  /// pixels. A flat 1.3 drifts ~0.6 px per 22 px line against the boards.
  static double normalLineHeight(double size) =>
      ((size * 1.005).round() + (size * 0.295).round()) / size;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;

  /// A Geist style exactly as a board's CSS sets it: `font-size`, `font-weight`,
  /// `line-height` (unitless), `letter-spacing` (px).
  static TextStyle sans(
    double size, {
    FontWeight weight = regular,
    double? height,
    double letterSpacing = 0,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: geist,
      fontSize: size,
      fontWeight: weight,
      height: height ?? normalLineHeight(size),
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing,
      color: color,
      decoration: decoration,
      decorationColor: color,
    );
  }

  /// A Geist Mono style (facts only — see the class doc).
  static TextStyle mono(
    double size, {
    FontWeight weight = regular,
    double? height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: geistMono,
      fontSize: size,
      fontWeight: weight,
      height: height ?? normalLineHeight(size),
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // Named styles for values that repeat across many boards. Screen-specific values stay
  // as `sans(...)` calls with the board's numbers, so nothing is rounded to a near style.

  /// Screen titles: "Enter your code" (32/500, -0.6, 1.1).
  static TextStyle title32({Color? color}) =>
      sans(32, weight: medium, height: 1.1, letterSpacing: -0.6, color: color);

  /// "How do you want to share it?" (30/500, -0.6, 1.1).
  static TextStyle title30({Color? color}) =>
      sans(30, weight: medium, height: 1.1, letterSpacing: -0.6, color: color);

  /// Piece title on the piece page (26/500, -0.5); "Explore" / "Profile" headers.
  static TextStyle title26({Color? color}) =>
      sans(26, weight: medium, letterSpacing: -0.5, color: color);

  /// Sheet titles, profile name (22/500).
  static TextStyle title22({Color? color, double letterSpacing = 0}) =>
      sans(22, weight: medium, letterSpacing: letterSpacing, color: color);

  /// Shelf / section headers (20/500).
  static TextStyle header20({Color? color}) => sans(20, weight: medium, color: color);

  /// Option-row titles (19/500, -0.2).
  static TextStyle option19({Color? color}) =>
      sans(19, weight: medium, letterSpacing: -0.2, color: color);

  /// Top-bar titles and bottom-bar values (17).
  static TextStyle header17({FontWeight weight = medium, Color? color}) =>
      sans(17, weight: weight, color: color);

  /// Body copy (16 / 1.45 or the board's value).
  static TextStyle body16({double height = 1.45, Color? color}) =>
      sans(16, height: height, color: color);

  static TextStyle body15({double height = 1.45, Color? color}) =>
      sans(15, height: height, color: color);

  static TextStyle body14({FontWeight weight = regular, double? height, Color? color}) =>
      sans(14, weight: weight, height: height, color: color);

  /// Field labels (13).
  static TextStyle label13({FontWeight weight = regular, Color? color}) =>
      sans(13, weight: weight, color: color);

  /// Captions and bar labels (12).
  static TextStyle caption12({double? height, Color? color}) =>
      sans(12, height: height, color: color);

  /// Chips, tags, small facts (Mono 11).
  static TextStyle mono11({Color? color, double letterSpacing = 0}) =>
      mono(11, letterSpacing: letterSpacing, color: color);

  /// Dimensions / dates lines (Mono 13).
  static TextStyle mono13({Color? color}) => mono(13, color: color);
}

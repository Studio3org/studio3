import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Drop-in replacements for [GoogleFonts.inter] and [GoogleFonts.geist] that also carry
/// [AppTheme.emojiFallback] — every call site in the app used to call [GoogleFonts]
/// directly, and none of them rendered an emoji correctly on iOS.
///
/// The reason a single global fix (an app-root `DefaultTextStyle`, or patching the theme
/// alone) does not work here: [TextStyle.merge] keeps a base style's `fontFamilyFallback`
/// only when the style merged on top leaves that field null, and [GoogleFonts.inter]/
/// [GoogleFonts.geist] do not leave it null — they set it themselves (to manage their own
/// weight-variant lookup), so it always wins the merge and silently discards whatever
/// fallback the theme or an ambient `DefaultTextStyle` provided. Confirmed with a widget
/// test before writing this file; see test/emoji_fallback_test.dart.
///
/// Same parameters as the functions they replace, so every call site converts by renaming
/// `GoogleFonts.inter(`/`GoogleFonts.geist(` to `AppFonts.inter(`/`AppFonts.geist(` and
/// nothing else — no argument was added, removed, or reordered.
abstract final class AppFonts {
  static TextStyle inter({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return _withEmojiFallback(
      GoogleFonts.inter(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      ),
    );
  }

  static TextStyle geist({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return _withEmojiFallback(
      GoogleFonts.geist(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      ),
    );
  }

  /// Appended, not replaced: keeps whatever GoogleFonts already put there (its own
  /// weight-variant bookkeeping) and adds the emoji fonts after it, so a glyph search
  /// still tries GoogleFonts' own fallback first and only reaches for emoji glyphs when
  /// that comes up empty.
  static TextStyle _withEmojiFallback(TextStyle style) {
    return style.copyWith(
      fontFamilyFallback: [
        ...?style.fontFamilyFallback,
        ...AppTheme.emojiFallback,
      ],
    );
  }
}

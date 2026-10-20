import 'package:flutter/material.dart';

/// Theme-aware Studio 3 auth palette — Ivory/Slate in light, near-black/Ivory
/// in dark (values taken from the `SignInFirst` / `SignInFirstDark` design
/// screens). Registered on [ThemeData.extensions] in `AppTheme.light` and
/// `AppTheme.dark`; read it via `context.authColors` rather than a static
/// constant so every auth screen follows the device's light/dark setting.
class AuthPalette extends ThemeExtension<AuthPalette> {
  const AuthPalette({
    required this.background,
    required this.backgroundDeep,
    required this.surface,
    required this.surfaceElevated,
    required this.greyAccent,
    required this.border,
    required this.borderFocus,
    required this.textPrimary,
    required this.textMuted,
    required this.textDim,
    required this.error,
    required this.accent,
    required this.success,
  });

  /// Page/scaffold background (Ivory in light, near-black in dark).
  final Color background;

  /// Same value as [background]; also used as the foreground color painted
  /// on top of [accent] (primary-button text, spinner) — works in both
  /// themes because [accent] is always the opposite extreme of the page
  /// background.
  final Color backgroundDeep;
  final Color surface;
  final Color surfaceElevated;
  final Color greyAccent;
  final Color border;
  final Color borderFocus;
  final Color textPrimary;
  final Color textMuted;
  final Color textDim;
  final Color error;

  /// Primary-button / active-control fill — ink in light, ivory in dark.
  final Color accent;
  final Color success;

  static const light = AuthPalette(
    background: Color(0xFFFAF9F5), // Ivory
    backgroundDeep: Color(0xFFFAF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0EEE6), // warm grey 150
    greyAccent: Color(0xFFE8E6DC), // warm grey 200
    border: Color(0x261F1E1D), // Slate @ 15%
    borderFocus: Color(0xFF141413), // Slate
    textPrimary: Color(0xFF141413), // Slate
    textMuted: Color(0xFF73726C), // warm grey 550
    textDim: Color(0xFF9C9A92), // warm grey 450
    error: Color(0xFFB3261E),
    accent: Color(0xFF141413), // Slate (ink)
    success: Color(0xFF2E7D32),
  );

  static const dark = AuthPalette(
    background: Color(0xFF0B0B10),
    backgroundDeep: Color(0xFF0B0B10),
    surface: Color(0xFF17171D),
    surfaceElevated: Color(0xFF212128),
    greyAccent: Color(0x29FAFAF8), // Ivory @ 16%
    border: Color(0x2EFAFAF8), // Ivory @ 18%
    borderFocus: Color(0xFFFAFAF8),
    textPrimary: Color(0xFFFAFAF8),
    textMuted: Color(0xB3FAFAF8), // Ivory @ 70%
    textDim: Color(0x80FAFAF8), // Ivory @ 50%
    error: Color(0xFFFF6B6B),
    accent: Color(0xFFFAFAF8), // Ivory
    success: Color(0xFF4ADE80),
  );

  @override
  AuthPalette copyWith({
    Color? background,
    Color? backgroundDeep,
    Color? surface,
    Color? surfaceElevated,
    Color? greyAccent,
    Color? border,
    Color? borderFocus,
    Color? textPrimary,
    Color? textMuted,
    Color? textDim,
    Color? error,
    Color? accent,
    Color? success,
  }) {
    return AuthPalette(
      background: background ?? this.background,
      backgroundDeep: backgroundDeep ?? this.backgroundDeep,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      greyAccent: greyAccent ?? this.greyAccent,
      border: border ?? this.border,
      borderFocus: borderFocus ?? this.borderFocus,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      error: error ?? this.error,
      accent: accent ?? this.accent,
      success: success ?? this.success,
    );
  }

  @override
  AuthPalette lerp(ThemeExtension<AuthPalette>? other, double t) {
    if (other is! AuthPalette) return this;
    return AuthPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundDeep: Color.lerp(backgroundDeep, other.backgroundDeep, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      greyAccent: Color.lerp(greyAccent, other.greyAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      error: Color.lerp(error, other.error, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AuthPaletteContext on BuildContext {
  /// The current theme's auth palette — Ivory/Slate in light mode,
  /// near-black/Ivory in dark mode. Falls back to [AuthPalette.light] if a
  /// screen somehow renders under a [ThemeData] that didn't register it.
  AuthPalette get authColors =>
      Theme.of(this).extension<AuthPalette>() ?? AuthPalette.light;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_palette.dart';
import 'studio_colors.dart';
import 'studio_metrics.dart';
import 'studio_type.dart';

/// Pre-redesign slate palette. Still read by screens not yet rebuilt; each screen moves to
/// `context.studio` (`studio_colors.dart`) when it is rebuilt, and this goes in Phase 11.
class AppColors {
  AppColors._();
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F8F8);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color black = Color(0xFF000000);
}

/// Pre-redesign sizes. New code uses `StudioSpace` / `StudioRadius` / `StudioSize`.
class AppDims {
  AppDims._();
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double pillInputHeight = 52;
  static const double primaryButtonHeight = 52;
}

/// Light and dark [ThemeData] built from the new-UI tokens (`StudioColors`, `StudioType`,
/// `StudioRadius`). Both register [StudioColors] and [AuthPalette] as extensions.
class AppTheme {
  /// Where to look for a glyph the app fonts don't have — emoji, above all. Flutter only
  /// resolves a glyph outside the primary font if it is told where to look; without this,
  /// emoji in a chat message, caption or bio render blank on iOS.
  static const List<String> emojiFallback = [
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
  ];

  AppTheme._();

  static ThemeData get light => _build(StudioColors.light, Brightness.light, AuthPalette.light);

  static ThemeData get dark => _build(StudioColors.dark, Brightness.dark, AuthPalette.dark);

  static ThemeData _build(StudioColors c, Brightness brightness, AuthPalette auth) {
    final isDark = brightness == Brightness.dark;

    final overlay = (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: c.background,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.buttonFill,
      onPrimary: c.buttonText,
      secondary: c.textSecondary,
      onSecondary: c.background,
      error: c.alert,
      onError: StudioColors.galleryWhite,
      surface: c.background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surface,
      outline: c.lineStrong,
      outlineVariant: c.line,
      shadow: StudioColors.ink,
      scrim: c.scrim,
      inverseSurface: c.tooltipFill,
      onInverseSurface: c.tooltipText,
      surfaceTint: Colors.transparent,
    );

    // Material roles mapped onto the HandoffRules type scale (titles 24–32, headers 17–20,
    // body 14–16, labels 13, captions 12; Mono for facts).
    final textTheme = TextTheme(
      displayLarge: StudioType.title32(color: c.textPrimary),
      displayMedium: StudioType.title30(color: c.textPrimary),
      displaySmall: StudioType.title26(color: c.textPrimary),
      headlineLarge: StudioType.title32(color: c.textPrimary),
      headlineMedium: StudioType.title30(color: c.textPrimary),
      headlineSmall: StudioType.title26(color: c.textPrimary),
      titleLarge: StudioType.title22(color: c.textPrimary),
      titleMedium: StudioType.header17(color: c.textPrimary),
      titleSmall: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
      bodyLarge: StudioType.body16(color: c.textPrimary),
      bodyMedium: StudioType.body14(color: c.textPrimary),
      bodySmall: StudioType.caption12(color: c.textSecondary),
      labelLarge: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
      labelMedium: StudioType.label13(color: c.textSecondary),
      labelSmall: StudioType.mono11(color: c.textSecondary),
    ).apply(fontFamilyFallback: emojiFallback);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadius.button),
    );
    final primaryStyle = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(buttonShape),
      minimumSize: const WidgetStatePropertyAll(Size(0, StudioSize.buttonPrimary)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
      textStyle: WidgetStatePropertyAll(StudioType.sans(15, weight: StudioType.medium)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.buttonDisabledFill : c.buttonFill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.buttonDisabledText : c.buttonText,
      ),
      overlayColor: WidgetStatePropertyAll(c.buttonText.withValues(alpha: 0.08)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: StudioType.geist,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: c.textPrimary, size: 22),
        titleTextStyle: StudioType.header17(color: c.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, StudioSize.buttonInline),
          shape: buttonShape,
          side: BorderSide(color: c.lineStrong),
          textStyle: StudioType.body14(weight: StudioType.medium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, StudioSize.tapTarget),
          textStyle: StudioType.body14(weight: StudioType.medium),
        ),
      ),
      // Fields: label above, value on a single underline; focused underline is Ink.
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.only(bottom: 8, top: 6),
        labelStyle: StudioType.label13(color: c.textSecondary),
        floatingLabelStyle: StudioType.label13(color: c.textSecondary),
        hintStyle: StudioType.sans(17, color: c.textPlaceholder),
        helperStyle: StudioType.caption12(height: 1.45, color: c.textTertiary),
        errorStyle: StudioType.caption12(height: 1.45, color: c.textPrimary),
        border: UnderlineInputBorder(borderSide: BorderSide(color: c.lineStrong)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.lineStrong)),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.textPrimary, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.textPrimary)),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.textPrimary, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.textPrimary,
        selectionColor: c.textPrimary.withValues(alpha: 0.18),
        selectionHandleColor: c.textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.switchKnobOn : c.switchKnob,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.switchOn : c.switchOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        modalBackgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: c.lineStrong,
        dragHandleSize: const Size(40, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudioRadius.panel)),
        titleTextStyle: StudioType.title22(color: c.textPrimary),
        contentTextStyle: StudioType.body15(color: c.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.tooltipFill,
        contentTextStyle: StudioType.body14(weight: StudioType.medium, color: c.tooltipText),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudioRadius.button)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.textPrimary,
        linearTrackColor: c.line,
        circularTrackColor: Colors.transparent,
      ),
      extensions: [c, auth],
    );
  }
}

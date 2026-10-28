import 'package:flutter/material.dart';

/// New-UI color tokens (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 3).
///
/// Light values are the canvas's own (`HandoffRules` "Color" + the boards); dark values come
/// from the canvas's dark surfaces (`SignInFirstDark`, dark edit screens, Ink cards) where they
/// exist, and are marked *(proposed)* in the plan where the canvas draws none (decision D5).
///
/// Screens read these through the theme — `context.studio.textPrimary` — never as constants,
/// so every screen follows the light/dark switch (plan section 1, rule 6).
@immutable
class StudioColors extends ThemeExtension<StudioColors> {
  const StudioColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.line,
    required this.lineStrong,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
    required this.buttonFill,
    required this.buttonText,
    required this.buttonDisabledFill,
    required this.buttonDisabledText,
    required this.navFill,
    required this.navBorder,
    required this.navActive,
    required this.navIconActive,
    required this.navIconInactive,
    required this.signInBackground,
    required this.available,
    required this.positive,
    required this.positiveBg,
    required this.alert,
    required this.alertBg,
    required this.scrim,
    required this.switchOn,
    required this.switchOff,
    required this.switchKnob,
    required this.switchKnobOn,
    required this.tooltipFill,
    required this.tooltipText,
  });

  /// Gallery White in light: the app background (nearly neutral so art reads true).
  final Color background;

  /// Paper: search bar, insights card, summary boxes, field fills.
  final Color surface;

  /// White cards and chips that sit on [background] (e.g. Explore medium chips).
  final Color card;

  /// Dividers and light outlines.
  final Color line;

  /// Button outlines, empty-field underline, disabled primary fill in light.
  final Color lineStrong;

  final Color textPrimary;
  final Color textBody;
  final Color textSecondary;
  final Color textTertiary;
  final Color textPlaceholder;

  final Color buttonFill;
  final Color buttonText;
  final Color buttonDisabledFill;
  final Color buttonDisabledText;

  final Color navFill;

  /// Hairline around the floating nav in dark, where an Ink pill would vanish on Ink.
  final Color navBorder;
  final Color navActive;
  final Color navIconActive;
  final Color navIconInactive;

  /// Base color under the sign-in haze.
  final Color signInBackground;

  /// Status colors — the only exceptions to monochrome, always paired with words or an icon.
  final Color available;
  final Color positive;
  final Color positiveBg;
  final Color alert;
  final Color alertBg;

  final Color scrim;

  /// Switch (44 × 26, `NotifSettings`): track on/off, knob off/on.
  final Color switchOn;
  final Color switchOff;
  final Color switchKnob;
  final Color switchKnobOn;
  final Color tooltipFill;
  final Color tooltipText;

  // ---- Fixed values used the same in both themes --------------------------------------

  /// Ink / Gallery White for surfaces that are dark or light in BOTH themes (dark edit
  /// screens, white icons over images, the iridescent chip's text).
  static const Color ink = Color(0xFF111111);
  static const Color galleryWhite = Color(0xFFFAFAF8);

  /// Over-image scrim behind white top icons on hero images (`BuyPiece`).
  static const Color topIconGradientStart = Color(0x61111111); // rgba(17,17,17,0.38)

  /// Series card caption bar on images (`Main`).
  static const Color imageCaptionBar = Color(0x73141414); // rgba(20,20,20,0.45)

  /// Secondary text on Ink cards (event card, dark edit screens).
  static const Color onDarkSecondary = Color(0xFFA8A8A8);

  /// Tertiary text and marks on the dark edit screens (`SceneTrim` "/ 1:00", the crop ticks).
  static const Color onDarkTertiary = Color(0xFF6A6A6A);

  /// The dark photo editor (`ScenePhotoEdit`, `ScenePhotoEditSize`): unselected tabs, and the
  /// text of an unselected chip.
  static const Color onDarkOff = Color(0xFF8A8A8A);
  static const Color onDarkChipText = Color(0xFFC8C8C8);

  /// Iridescent gradient (115°), used ONLY for the Collected chip, the collect
  /// confirmation and — blurred — the sign-in haze (`HandoffRules`).
  static const List<Color> iridescentStops = [
    Color(0xFFF3D6FF),
    Color(0xFFCDE8FF),
    Color(0xFFD2FBEA),
    Color(0xFFFFF3C9),
    Color(0xFFFFD3E6),
    Color(0xFFE4D8FF),
  ];
  static const List<double> iridescentPositions = [0, 0.22, 0.42, 0.62, 0.82, 1];

  // ---- Themes ---------------------------------------------------------------------------

  static const StudioColors light = StudioColors(
    background: Color(0xFFFAFAF8),
    surface: Color(0xFFF0F0EE),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE3E3E0),
    lineStrong: Color(0xFFD4D4D0),
    textPrimary: Color(0xFF111111),
    textBody: Color(0xFF333333),
    textSecondary: Color(0xFF6B6B6B),
    textTertiary: Color(0xFF6D6D6D), // darkened from the boards' #8E8E8E to reach 4.5:1 (19.1, 2026-10-28)
    textPlaceholder: Color(0xFFA3A3A3),
    buttonFill: Color(0xFF111111),
    buttonText: Color(0xFFFAFAF8),
    buttonDisabledFill: Color(0xFFD4D4D0),
    buttonDisabledText: Color(0xFFFAFAF8),
    navFill: Color(0xFF111111),
    navBorder: Color(0x00000000),
    navActive: Color(0xFF2A2A2A),
    navIconActive: Color(0xFFFAFAF8),
    navIconInactive: Color(0xFF8E8E8E),
    signInBackground: Color(0xFFFAFAF8),
    available: Color(0xFF2E8B57),
    positive: Color(0xFF1E6B3C),
    positiveBg: Color(0xFFE7F2EA),
    alert: Color(0xFFB3261E),
    alertBg: Color(0xFFFBEAE8),
    scrim: Color(0x80111111), // rgba(17,17,17,0.5)
    switchOn: Color(0xFF111111),
    switchOff: Color(0xFFE3E3E0),
    switchKnob: Color(0xFFFFFFFF),
    switchKnobOn: Color(0xFFFFFFFF),
    tooltipFill: Color(0xFF111111),
    tooltipText: Color(0xFFFAFAF8),
  );

  /// Dark theme. Values from `SignInFirstDark`, the dark edit screens and Ink cards where
  /// the canvas has them; the rest are the plan's *(proposed)* values pending Abott (D5).
  static const StudioColors dark = StudioColors(
    background: Color(0xFF111111),
    surface: Color(0xFF1C1C1C), // proposed
    card: Color(0xFF1C1C1C), // proposed
    line: Color(0xFF2A2A2A),
    lineStrong: Color(0xFF3A3A3A), // proposed
    textPrimary: Color(0xFFFAFAF8),
    textBody: Color(0xFFD9D9D6), // proposed
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF8E8E8E),
    textPlaceholder: Color(0xFF6B6B6B), // proposed
    buttonFill: Color(0xFFFAFAF8),
    buttonText: Color(0xFF111111),
    buttonDisabledFill: Color(0x29FAFAF8), // rgba(250,250,248,0.16) — SignInFirstDark
    buttonDisabledText: Color(0x8CFAFAF8), // rgba(250,250,248,0.55) — SignInFirstDark
    // Same ink bar in both themes. The floating nav does not recolor in dark mode.
    navFill: Color(0xFF111111),
    navBorder: Color(0x00000000),
    navActive: Color(0xFF2A2A2A),
    navIconActive: Color(0xFFFAFAF8),
    navIconInactive: Color(0xFF8E8E8E),
    signInBackground: Color(0xFF0B0B10),
    available: Color(0xFF2E8B57),
    positive: Color(0xFF4CAF7A), // proposed
    positiveBg: Color(0xFF16301F), // proposed
    alert: Color(0xFFF2665C), // proposed
    alertBg: Color(0xFF3A1714), // proposed
    scrim: Color(0x99000000), // proposed
    switchOn: Color(0xFFFAFAF8), // proposed: an Ink track would vanish on Ink
    switchOff: Color(0xFF3A3A3A), // the dark sign-in board's off track
    switchKnob: Color(0xFFFAFAF8),
    switchKnobOn: Color(0xFF111111), // proposed
    tooltipFill: Color(0xFFFAFAF8), // proposed: inverse of the light tooltip
    tooltipText: Color(0xFF111111),
  );

  @override
  StudioColors copyWith() => this;

  @override
  StudioColors lerp(ThemeExtension<StudioColors>? other, double t) {
    if (other is! StudioColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StudioColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      card: l(card, other.card),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textBody: l(textBody, other.textBody),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textPlaceholder: l(textPlaceholder, other.textPlaceholder),
      buttonFill: l(buttonFill, other.buttonFill),
      buttonText: l(buttonText, other.buttonText),
      buttonDisabledFill: l(buttonDisabledFill, other.buttonDisabledFill),
      buttonDisabledText: l(buttonDisabledText, other.buttonDisabledText),
      navFill: l(navFill, other.navFill),
      navBorder: l(navBorder, other.navBorder),
      navActive: l(navActive, other.navActive),
      navIconActive: l(navIconActive, other.navIconActive),
      navIconInactive: l(navIconInactive, other.navIconInactive),
      signInBackground: l(signInBackground, other.signInBackground),
      available: l(available, other.available),
      positive: l(positive, other.positive),
      positiveBg: l(positiveBg, other.positiveBg),
      alert: l(alert, other.alert),
      alertBg: l(alertBg, other.alertBg),
      scrim: l(scrim, other.scrim),
      switchOn: l(switchOn, other.switchOn),
      switchOff: l(switchOff, other.switchOff),
      switchKnob: l(switchKnob, other.switchKnob),
      switchKnobOn: l(switchKnobOn, other.switchKnobOn),
      tooltipFill: l(tooltipFill, other.tooltipFill),
      tooltipText: l(tooltipText, other.tooltipText),
    );
  }
}

/// `context.studio` — the current theme's new-UI colors.
extension StudioColorsContext on BuildContext {
  StudioColors get studio => Theme.of(this).extension<StudioColors>() ?? StudioColors.light;
}

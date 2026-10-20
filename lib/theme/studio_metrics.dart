/// New-UI spacing, corner radii and fixed sizes (docs/new-ui/NEW_UI_EXECUTION_PLAN.md,
/// section 3; `HandoffRules` "Spacing" / "Corners", `HandoffSizes`). Units are logical
/// pixels, which equal the boards' CSS px (the boards are 390 wide, like the phone).
abstract final class StudioSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;

  /// Side margins: feeds and Explore.
  static const double marginFeed = 16;

  /// Side margins: profiles and piece pages.
  static const double marginPage = 20;

  /// Side margins: posting and sign-in (24 to 28; boards use 24 for forms, 28 on some).
  static const double marginForm = 24;

  /// Between full-bleed feed pieces.
  static const double feedGap = 20;

  /// Around inset feed sections (series rows, event cards).
  static const double feedInset = 48;
}

abstract final class StudioRadius {
  /// Small buttons (Follow), small thumbnails.
  static const double small = 8;

  /// Buttons, inputs.
  static const double button = 12;

  /// Grid and shelf cards.
  static const double card = 10;

  /// Event cards, bottom bars, provenance card (14 to 18).
  static const double panel = 14;

  /// Sheet top corners.
  static const double sheet = 24;

  /// Chips, tags, filters, avatars, switch, floating nav — and nothing else.
  static const double round = 999;
}

abstract final class StudioSize {
  /// The phone template every board is drawn on.
  static const double templateWidth = 390;
  static const double templateHeight = 844;

  /// Primary button (52 to 54; 54 on posting and pinned sign-in buttons).
  static const double buttonPrimary = 52;
  static const double buttonPrimaryTall = 54;

  /// Inline button (Message / Follow on profiles).
  static const double buttonInline = 44;

  /// Small Follow.
  static const double buttonSmall = 34;

  /// Minimum tap target.
  static const double tapTarget = 44;

  /// Floating nav: height, side inset, gap above the bottom safe area.
  static const double navHeight = 64;
  static const double navSideInset = 16;
  static const double navBottomGap = 28;

  /// Sheets never exceed this share of the screen height.
  static const double sheetMaxHeightFactor = 0.9;

  /// iPhone SE has no bottom inset; pinned content adds this instead.
  static const double noInsetBottomPadding = 16;
}

/// Motion (`HandoffRules`: short and quiet, about 0.2 to 0.3 s; reduced motion respected).
abstract final class StudioMotion {
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration iridescentLoop = Duration(seconds: 6);
  static const Duration hazeLoop = Duration(seconds: 18);
}

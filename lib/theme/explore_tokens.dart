import 'package:flutter/material.dart';

/// Explore page design tokens (Figma 2426-1678).
///
/// Pre-redesign values, kept unchanged so screens not yet rebuilt don't shift mid-migration.
/// Rebuilt screens read `context.studio` (`studio_colors.dart`), `StudioType` and
/// `StudioRadius` / `StudioSpace` instead; this file is deleted in Phase 11 of
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md once nothing imports it.
abstract final class ExploreTokens {
  static const Color background = Color(0xFFFAFAF7);
  static const Color textPrimary = Color(0xFF231F1B);
  static const Color textSecondary = Color(0xFF8C8880);
  static const Color textInverse = Color(0xFFFAFAF7);
  static const Color searchFill = Color(0x338C8880);
  static const Color chipActiveFill = Color(0xFF231F1B);
  static const Color chipBorder = Color(0xFF231F1B);

  /// Skeleton-loading placeholder fill/highlight. Solid colors with real
  /// contrast against [background] instead of dissolving into it.
  static const Color skeleton = Color(0xFFE2DED6);
  static const Color skeletonHighlight = Color(0xFFF3F0EA);

  static const double sideMargin = 10;
  static const double gutter = 8;
  static const double blockGap = 8;
  static const double searchRadius = 10;
  static const double chipRadius = 35;
  static const double heroRadius = 10;
  static const double tileRadius = 8;
  static const double heroHeight = 208;
  static const double searchHeight = 48;
  static const double chipHeight = 32;

  /// Sticky search + chips header (top/bottom padding included).
  static const double stickyHeaderTopPadding = 8;
  static const double stickyHeaderBottomPadding = 12;
  static const double stickyHeaderSectionGap = 12;
  static const double stickyHeaderHeight =
      stickyHeaderTopPadding +
      searchHeight +
      stickyHeaderSectionGap +
      chipHeight +
      stickyHeaderBottomPadding;

  static const double portraitAspect = 3 / 4;
  static const double squareAspect = 1;
  static const double landscapeAspect = 16 / 9;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: textPrimary.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}

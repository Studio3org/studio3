import 'package:flutter/material.dart';

/// Home feed design tokens (Studio 3 For You).
///
/// Pre-redesign values, kept unchanged so screens not yet rebuilt don't shift mid-migration.
/// Rebuilt screens read `context.studio` (`studio_colors.dart`), `StudioType` and
/// `StudioRadius` / `StudioSpace` instead; this file is deleted in Phase 11 of
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md once nothing imports it.
abstract final class HomeFeedTokens {
  static const Color background = Color(0xFFFAFAF7);
  static const Color detailBackground = Color(0xFFF5F2EE);
  static const Color textPrimary = Color(0xFF231F1B);
  static const Color textSecondary = Color(0xFF8C8880);
  static const Color textInverse = Color(0xFFFAFAF7);
  static const Color neutral800 = Color(0xFF352F2A);
  static const Color sky600 = Color(0xFF4A92BE);

  /// Skeleton-loading placeholder fill. Solid (not alpha-derived from
  /// [textPrimary]) so it keeps real contrast against [background] instead
  /// of dissolving into it.
  static const Color skeletonBase = Color(0xFFE2DED6);
  static const Color skeletonHighlight = Color(0xFFF3F0EA);

  static const double cardRadius = 10;
  static const double sideMargin = 10;
  static const double rowGap = 10;

  static const double dotSize = 6;
  static const double dotInset = 8;
  static const double avatarSize = 28;
  static const double artistTextWidth = 262;
}

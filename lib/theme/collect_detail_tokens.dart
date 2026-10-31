export '../utils/money_format.dart';
import 'package:flutter/material.dart';

/// Design tokens from Figma node 2302-1554 (Piece detail / collect).
///
/// Pre-redesign values, kept unchanged so screens not yet rebuilt don't shift mid-migration.
/// Rebuilt screens read `context.studio` (`studio_colors.dart`), `StudioType` and
/// `StudioRadius` / `StudioSpace` instead; this file is deleted in Phase 11 of
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md once nothing imports it.
abstract final class CollectDetailTokens {
  static const Color statusError = Color(0xFFC03030);
  static const double pagePadding = 10;
  static const Color hairline = Color(0xFFC4C4C4);
  static const Color titleHairline = Color(0xFFC8C5BC);
  static const double collectCtaRadius = 8;
  static const Color background = Color(0xFFF5F2EE);
  static const Color textPrimary = Color(0xFF231F1B);
  static const Color textSecondary = Color(0xFF8C8880);
  static const Color textInverse = Color(0xFFFAFAF7);
  static const Color ctaFill = Color(0xFF352F2A);
  static const Color divider = Color(0xFFE8E5DF);
  static const Color storyCardFill = Color(0xFFFFFFFF);
  static const Color link = Color(0xFF4A92BE);
  static const Color brand = Color(0xFF6BAED6);
  static const Color followBorder = Color(0xFF352F2A);
  static const Color sheetBackground = Color(0xFFFAFAF7);
  static const Color sheetCardFill = Color(0x33C8C5BC);
  static const Color textDisabled = Color(0xFFC8C5BC);

  static const double frameWidth = 390;
  static const double heroHeight = 844;
  static const double heroAspectRatio = frameWidth / heroHeight;

  static const double horizontalPadding = 16;
  static const double sectionGap = 16;

  static const double titleSize = 24;
  static const double titleLineHeight = 31.2;

  static const double metaSize = 14;
  static const double metaLineHeight = 16.94;

  static const double linkSize = 12;

  static const double storySize = 16;
  static const double storyLineHeight = 20.8;

  static const double sectionHeaderSize = 14;

  static const double barPriceSize = 20;
  static const double barPriceLineHeight = 26;
  static const double collectButtonHeight = 40;
  static const double collectButtonRadius = 10;
  static const double collectLabelSize = 16;
  static const double collectBarContentHeight = 97;
}


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

/// Figma 2650:1892 — Artist Profile (viewer, non-seller).
const Color kProfilePageBackground = HomeFeedTokens.detailBackground; // #F5F2EE
const Color kProfileTextMuted = HomeFeedTokens.textSecondary; // #8C8880
const Color kProfileStatDivider = Color(0xFFC4C4C4);
const Color kProfileTabRule = Color(0xFFC8C5BC);
const Color kProfileTextDisabled = Color(0xFFC8C5BC);
const Color kProfileCollectMenuFill = Color(0xCC231F1B); // rgba(35,31,27,0.8)

const double kProfileGutter = 8;
const double kProfileHorizontalPad = 10;
const double kProfileIdentityPad = 28;
const double kProfileCoverHeight = 280;
const double kProfileAvatarSize = 84;
const double kProfileAvatarBorder = 3;
const double kProfileAvatarTop = 238;
const double kProfileHeroHeight = kProfileAvatarTop + kProfileAvatarSize; // 322
const double kProfileButtonHeight = 28;
const double kProfileButtonRadius = 4;
const double kProfileButtonMaxWidth = 180;
const double kProfileCardRadius = 6;
const double kProfileGridTopGap = 32;

/// Figma 2650:1892 masonry rhythm (390pt column ≈ 181).
/// Portrait ≈ 181×270, square 1:1, wide 181×113.
const List<double> kProfileMasonryHeightRatios = [
  270 / 181,
  1,
  113 / 181,
  180 / 181,
  271 / 181,
  180 / 181,
  113 / 181,
  269 / 181,
  269 / 181,
];

TextStyle kProfileGeist({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color color = HomeFeedTokens.textPrimary,
  double? height,
}) {
  return GoogleFonts.geist(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );
}

import 'package:flutter/material.dart';

import 'collect_detail_tokens.dart';
import 'app_fonts.dart';

/// Line boxes from Figma 2707:3548 (text node height ÷ font size).
abstract final class PieceDetailType {
  static TextStyle geist({
    required double size,
    required double line,
    FontWeight weight = FontWeight.w400,
    required Color color,
  }) {
    return AppFonts.geist(
      fontSize: size,
      fontWeight: weight,
      height: line / size,
      color: color,
    );
  }

  static StrutStyle strut(double size, double line) {
    return StrutStyle(
      fontSize: size,
      height: line / size,
      leading: 0,
      forceStrutHeight: true,
    );
  }

  static final title = geist(
    size: 24,
    line: 31,
    weight: FontWeight.w500,
    color: CollectDetailTokens.textPrimary,
  );
  static const titleStrut = StrutStyle(
    fontSize: 24,
    height: 31 / 24,
    leading: 0,
    forceStrutHeight: true,
  );

  static final meta = geist(
    size: 13,
    line: 17,
    color: CollectDetailTokens.textSecondary,
  );
  static const metaStrut = StrutStyle(
    fontSize: 13,
    height: 17 / 13,
    leading: 0,
    forceStrutHeight: true,
  );

  static final dimensions = geist(
    size: 13,
    line: 17,
    color: CollectDetailTokens.textPrimary,
  );

  static final materials = geist(
    size: 12,
    line: 16,
    color: CollectDetailTokens.brand,
  );
  static const materialsStrut = StrutStyle(
    fontSize: 12,
    height: 16 / 12,
    leading: 0,
    forceStrutHeight: true,
  );

  static final artistName = geist(
    size: 12,
    line: 16,
    color: CollectDetailTokens.textPrimary,
  );
  static final artistHandle = geist(
    size: 11,
    line: 14,
    color: Color(0x998C8880),
  );
  static const artistNameStrut = StrutStyle(
    fontSize: 12,
    height: 16 / 12,
    leading: 0,
    forceStrutHeight: true,
  );
  static const artistHandleStrut = StrutStyle(
    fontSize: 11,
    height: 14 / 11,
    leading: 0,
    forceStrutHeight: true,
  );

  static final detailsHeader = geist(
    size: 13,
    line: 17,
    color: CollectDetailTokens.textPrimary,
  );
  static const detailsHeaderStrut = StrutStyle(
    fontSize: 13,
    height: 17 / 13,
    leading: 0,
    forceStrutHeight: true,
  );

  static final detailsLabel = geist(
    size: 12,
    line: 16,
    color: CollectDetailTokens.textSecondary,
  );
  static final detailsValue = geist(
    size: 12,
    line: 16,
    color: CollectDetailTokens.textPrimary,
  );
  static const detailsRowStrut = StrutStyle(
    fontSize: 12,
    height: 16 / 12,
    leading: 0,
    forceStrutHeight: true,
  );

  static final story = geist(
    size: 16,
    line: 20,
    color: CollectDetailTokens.textPrimary,
  );
  static const storyStrut = StrutStyle(
    fontSize: 16,
    height: 20 / 16,
    leading: 0,
    forceStrutHeight: true,
  );

  static final storyHeader = geist(
    size: 13,
    line: 17,
    weight: FontWeight.w500,
    color: CollectDetailTokens.textSecondary,
  );
  static const storyHeaderStrut = StrutStyle(
    fontSize: 13,
    height: 17 / 13,
    leading: 0,
    forceStrutHeight: true,
  );

  static final price = geist(
    size: 20,
    line: 24,
    color: CollectDetailTokens.textPrimary,
  );
  static const priceStrut = StrutStyle(
    fontSize: 20,
    height: 24 / 20,
    leading: 0,
    forceStrutHeight: true,
  );

  static final collect = geist(
    size: 16,
    line: 16,
    color: CollectDetailTokens.textInverse,
  );

  static final seriesName = geist(
    size: 12,
    line: 16,
    weight: FontWeight.w500,
    color: CollectDetailTokens.textPrimary,
  );
  static final seriesCount = geist(
    size: 11,
    line: 14,
    color: CollectDetailTokens.textSecondary,
  );
}

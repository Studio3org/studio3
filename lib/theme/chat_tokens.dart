import 'package:flutter/material.dart';

/// Direct-message thread design tokens (Instagram-inspired light chat).
///
/// Pre-redesign values, kept unchanged so screens not yet rebuilt don't shift mid-migration.
/// Rebuilt screens read `context.studio` (`studio_colors.dart`), `StudioType` and
/// `StudioRadius` / `StudioSpace` instead; this file is deleted in Phase 11 of
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md once nothing imports it.
abstract final class ChatTokens {
  /// Soft gray canvas — distinct from home feed cream `#FAFAF7`.
  static const Color background = Color(0xFFEEEEEE);
  static const Color headerBackground = Color(0xFFFAFAFA);
  static const Color timestamp = Color(0xFF8E8E8E);
  static const Color username = Color(0xFF8E8E8E);
  static const Color emptyStats = Color(0xFF8E8E8E);
}

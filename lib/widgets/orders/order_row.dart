import 'package:flutter/material.dart';

import '../studio/studio.dart';

/// `pending_payment` → `Pending payment`.
String orderStatusLabel(String status) {
  final words = status.replaceAll('_', ' ').trim();
  if (words.isEmpty) return '';
  return words[0].toUpperCase() + words.substring(1);
}

/// The status word's colour: Completed in the positive green, Cancelled grey, the rest
/// Graphite. Status is the one place colour is allowed (`HandoffRules`).
/// [neutral] for the rest (Graphite by default).
Color orderStatusColor(StudioColors c, String status, {Color? neutral}) => switch (status) {
  'completed' => c.positive,
  'cancelled' || 'refunded' => c.textTertiary,
  _ => neutral ?? c.textSecondary,
};

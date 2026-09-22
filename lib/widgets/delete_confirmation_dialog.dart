import 'package:flutter/material.dart';

import '../theme/home_feed_tokens.dart';
import '../theme/app_fonts.dart';

/// Returns `true` if the user confirmed deletion, `false`/`null` otherwise.
Future<bool?> showDeleteConfirmationDialog(
  BuildContext context, {
  required String itemLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        'Delete $itemLabel?',
        style: AppFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HomeFeedTokens.textInverse,
        ),
      ),
      content: Text(
        'This can\'t be undone. Your $itemLabel will be permanently removed.',
        style: AppFonts.inter(
          fontSize: 14,
          color: HomeFeedTokens.textInverse.withValues(alpha: 0.75),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: AppFonts.inter(color: HomeFeedTokens.textInverse.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: AppFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE05252),
            ),
          ),
        ),
      ],
    ),
  );
}

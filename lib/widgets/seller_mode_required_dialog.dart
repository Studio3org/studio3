import 'package:flutter/material.dart';

import '../theme/home_feed_tokens.dart';
import '../theme/app_fonts.dart';

/// Returns `true` if user chose Switch to Seller, `false`/`null` for Cancel.
Future<bool?> showSellerModeRequiredDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        'Seller profile required',
        style: AppFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HomeFeedTokens.textInverse,
        ),
      ),
      content: Text(
        'To list a piece for sale, switch to a seller profile in Settings.',
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
            'Switch to Seller',
            style: AppFonts.inter(
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textInverse,
            ),
          ),
        ),
      ],
    ),
  );
}

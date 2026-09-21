import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// A floating, rounded, icon-led toast — the app-styled replacement for the
/// plain default `SnackBar(content: Text(...))` used for transient errors
/// and confirmations (event save/RSVP failures, form validation nudges,
/// etc.). For a failure big enough to stop a whole flow (e.g. an event
/// failing to publish), prefer a full-screen result overlay instead — this
/// is for messages that shouldn't interrupt what's already on screen.
abstract final class StudioMessage {
  static void show(
    BuildContext context,
    String message, {
    bool isError = true,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HomeFeedTokens.neutral800,
          elevation: 0,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: HomeFeedTokens.textInverse,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textInverse,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

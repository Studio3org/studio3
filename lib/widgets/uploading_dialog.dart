import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import 'studio_loading.dart';

/// Shows a centered, non-dismissible "Uploading…" card that blocks the
/// screen until [hideUploadingDialog] is called. Callers must always pair
/// this with a `finally` block that hides it, on success or error alike.
Future<void> showUploadingDialog(
  BuildContext context, {
  String message = 'Uploading…',
}) async {
  // A still-focused text field's IME composing underline can bleed through a
  // translucent card (yellow line under the message). Clear focus and wait a
  // frame before presenting an opaque dialog.
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return;

  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: HomeFeedTokens.background,
          elevation: 8,
          borderRadius: BorderRadius.circular(AppDims.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StudioBubbleLoader(width: 88),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Dismisses a dialog previously shown by [showUploadingDialog].
void hideUploadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

import 'package:flutter/material.dart';

import '../../theme/home_feed_tokens.dart';
import '../../theme/app_fonts.dart';

Future<bool> showEventRelistDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: HomeFeedTokens.textPrimary.withValues(alpha: 0.45),
    builder: (context) {
      return Dialog(
        backgroundColor: HomeFeedTokens.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppFonts.geist(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              _DialogButton(
                label: 'Continue',
                filled: true,
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              _DialogButton(
                label: 'Cancel',
                filled: false,
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed == true;
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: HomeFeedTokens.neutral800,
                foregroundColor: HomeFeedTokens.textInverse,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                label,
                style: AppFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textInverse,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeFeedTokens.textPrimary,
                side: const BorderSide(color: HomeFeedTokens.textPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                label,
                style: AppFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
    );
  }
}

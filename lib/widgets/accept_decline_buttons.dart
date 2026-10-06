import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Shared Accept/Decline button pair for follow-requests and inquiry
/// message-requests rows.
class AcceptDeclineButtons extends StatelessWidget {
  const AcceptDeclineButtons({
    super.key,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final textStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: onDecline,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.25),
            ),
          ),
          child: Text('Decline',
              style: textStyle.copyWith(color: HomeFeedTokens.textPrimary)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onAccept,
          style: FilledButton.styleFrom(
            backgroundColor: HomeFeedTokens.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Accept',
              style: textStyle.copyWith(color: HomeFeedTokens.textInverse)),
        ),
      ],
    );
  }
}

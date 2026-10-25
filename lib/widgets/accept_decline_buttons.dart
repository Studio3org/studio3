import 'package:flutter/material.dart';

import 'studio/studio.dart';

/// Shared Decline / Accept pair for follow requests and message requests: small Studio
/// buttons, Decline outlined and Accept in Ink (34 tall, radius 8, 13/500).
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
      return SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.studio.textPrimary,
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioButton(
          label: 'Decline',
          variant: StudioButtonVariant.small,
          onPressed: onDecline,
        ),
        const SizedBox(width: 8),
        StudioButton(
          label: 'Accept',
          variant: StudioButtonVariant.small,
          filled: true,
          onPressed: onAccept,
        ),
      ],
    );
  }
}

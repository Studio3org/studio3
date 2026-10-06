import 'package:flutter/material.dart';

import '../../models/bid.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/app_fonts.dart';

/// "You're the highest bidder" confirmation — Figma "Piece detail - bid" flow, screen 3.
class PlaceBidConfirmationSheet extends StatelessWidget {
  const PlaceBidConfirmationSheet({super.key, required this.bid});

  final Bid bid;

  static Future<void> show(BuildContext context, {required Bid bid}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => PlaceBidConfirmationSheet(bid: bid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: CollectDetailTokens.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                bid.isLeading ? Icons.check_circle : Icons.info_outline,
                color: bid.isLeading
                    ? const Color(0xFF2E8B57)
                    : CollectDetailTokens.statusError,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                // Read from the response rather than assumed. A bid is validated against the
                // minimum at the moment it commits, so it is normally in front — but someone
                // can bid again in the time it takes this sheet to open, and telling them
                // they lead when they do not is how a collector stops watching an auction
                // they are losing.
                bid.isLeading ? "You're the highest bidder" : "You've already been outbid",
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bid.isLeading
                    ? 'Your bid of ${formatMoney(bid.amountCents)} is now leading. '
                        'Nothing is charged unless you win.'
                    : 'Your bid of ${formatMoney(bid.amountCents)} was placed, but someone '
                        'has since bid higher. Your hold still stands — raise your bid to '
                        'get back in front.',
                style: AppFonts.inter(
                  fontSize: 13,
                  color: CollectDetailTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: CollectDetailTokens.collectButtonHeight,
                width: double.infinity,
                child: Material(
                  color: CollectDetailTokens.ctaFill,
                  borderRadius: BorderRadius.circular(
                    CollectDetailTokens.collectButtonRadius,
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(
                      CollectDetailTokens.collectButtonRadius,
                    ),
                    child: Center(
                      child: Text(
                        'Back to piece',
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textInverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

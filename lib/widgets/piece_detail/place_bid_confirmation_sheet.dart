import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bid.dart';
import '../../theme/collect_detail_tokens.dart';

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
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2E8B57),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                "You're the highest bidder",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your bid of ${formatMoney(bid.amountCents)} is now leading',
                style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
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

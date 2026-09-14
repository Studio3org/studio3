import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';
import '../../utils/auction_time.dart';

/// Current-bid / time-remaining bar shown instead of [AvailableCollectBar] when a
/// piece is listed as an auction (Figma 2707:3728, "Piece detail - bid").
class AuctionBidBar extends StatelessWidget {
  const AuctionBidBar({
    super.key,
    required this.bidDisplay,
    required this.bidCount,
    this.auctionEndsAt,
    this.onPlaceBid,
    this.statusLabel,
    this.onMessage,
  });

  final String bidDisplay;
  final int bidCount;
  final DateTime? auctionEndsAt;
  final VoidCallback? onPlaceBid;
  final String? statusLabel;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final timeRemaining = formatTimeRemaining(auctionEndsAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bidCount > 0 ? 'Current bid · $bidCount bids' : 'Starting bid',
                      style: PieceDetailType.meta,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bidDisplay,
                      style: PieceDetailType.price,
                      strutStyle: PieceDetailType.priceStrut,
                    ),
                  ],
                ),
              ),
              if (timeRemaining != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Time remaining', style: PieceDetailType.meta),
                    const SizedBox(height: 4),
                    Text(
                      timeRemaining,
                      style: PieceDetailType.price.copyWith(
                        color: CollectDetailTokens.statusError,
                      ),
                      strutStyle: PieceDetailType.priceStrut,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Material(
                    color: onPlaceBid == null
                        ? CollectDetailTokens.ctaFill.withValues(alpha: 0.5)
                        : CollectDetailTokens.ctaFill,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onPlaceBid,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          statusLabel ?? 'Place a bid',
                          style: PieceDetailType.collect,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onMessage,
                child: SvgPicture.asset(
                  'assets/piece/message_btn.svg',
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

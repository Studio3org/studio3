import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../utils/auction_time.dart';
import '../../theme/app_fonts.dart';

/// What the artist sees on their own for-sale piece, before the buy/bid bar: how it's
/// listed, what it's currently at if it's an auction, and whether it can still be had.
///
/// Distinct from the bar below it on purpose. [AuctionBidBar] mixes the live numbers with
/// whatever action the viewer can take right now ("Manage auction", "Update card", …) — an
/// owner reading that bar has to infer the piece's actual state from a button's label. This
/// states it plainly instead, in the same three words the profile grid already uses for a
/// listing's status, just picked for an owner rather than a browser: **Available**,
/// **Under bidding**, **Collected**.
class OwnerListingSummary extends StatelessWidget {
  const OwnerListingSummary({
    super.key,
    required this.item,
    this.fallbackStatusLabel,
  });

  final FeedPreviewItem item;

  /// What to show when the piece is in a state the three headline words don't cover —
  /// reserved, delisted, an auction that closed with no bids, a cancelled auction. Passed in
  /// rather than recomputed here so there is exactly one place (the detail page's own
  /// `_statusLabel`/`_auctionEndedLabel`) that knows those edge cases.
  final String? fallbackStatusLabel;

  bool get _isAuction => item.isAuction;

  int? get _currentBidCents =>
      item.auction?.highestBidCents ?? item.highestBidCents ?? item.startingBidCents;

  String? get _timeRemaining => formatTimeRemaining(item.auctionEndsAt);

  _Status get _status {
    final auction = item.auction;
    final collected = item.status == 'sold' ||
        item.status == 'auction_won' ||
        (auction != null && auction.isClosed && auction.winningBidCents != null);
    if (collected) return _Status.collected;
    if (_isAuction) {
      final open = item.isLive && (auction?.isOpenForBidding ?? true);
      return open ? _Status.underBidding : _Status.other;
    }
    return item.isLive ? _Status.available : _Status.other;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CollectDetailTokens.sheetCardFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isAuction ? Icons.gavel : Icons.sell_outlined,
                    size: 16,
                    color: CollectDetailTokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAuction ? 'Auction listing' : 'Fixed price listing',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CollectDetailTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              if (_isAuction && status == _Status.underBidding) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.bidCount > 0 ? 'Current bid' : 'Starting bid',
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: CollectDetailTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCollectPrice(_currentBidCents),
                            style: AppFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CollectDetailTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_timeRemaining != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Closes in',
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: CollectDetailTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _timeRemaining!,
                            style: AppFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CollectDetailTokens.statusError,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _StatusPill(status: status, fallbackLabel: fallbackStatusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Status { available, underBidding, collected, other }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.fallbackLabel});

  final _Status status;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _Status.available => ('Available', const Color(0xFF2E8B57)),
      _Status.underBidding => ('Under bidding', const Color(0xFFB3541E)),
      _Status.collected => ('Collected', CollectDetailTokens.textSecondary),
      _Status.other => (
          fallbackLabel ?? 'Unavailable',
          CollectDetailTokens.textSecondary,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

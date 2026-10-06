import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/auction_summary.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';
import '../../utils/auction_time.dart';
import '../../theme/app_fonts.dart';

/// The auction bar on piece detail (Figma 2707:3728, "Piece detail - bid").
///
/// An auction has more states after it closes than while it is running, and the ones that
/// follow the close are the ones that cost somebody money if they are not shown:
///
/// * **Bidding open** — current bid, time left, and whether this viewer is in front.
/// * **You won, payment failed** — the loudest state in the widget. The viewer's card was
///   declined at close and they have a deadline before the piece passes to the next bidder,
///   counted down to the second because for an event auction that deadline is ten minutes.
/// * **You won** — the money is already taken; what is left is shipping and delivery details.
/// * **Ended** — for everyone else.
///
/// The winner is read from [AuctionSummary.isWinner], never from `isHighestBidder`. The
/// latter means "leads the live bidding" and is necessarily false once the auction closes,
/// and it cannot describe a cascade — after the top bidder's card fails the winner is
/// somebody further down the list.
class AuctionBidBar extends StatefulWidget {
  const AuctionBidBar({
    super.key,
    required this.bidDisplay,
    required this.bidCount,
    this.auction,
    this.auctionEndsAt,
    this.onPlaceBid,
    this.onCompletePurchase,
    this.onFixPayment,
    this.statusLabel,
    this.onMessage,
  });

  final String bidDisplay;
  final int bidCount;

  /// Null for a piece whose auction the viewer cannot see, in which case this falls back to
  /// the plain current-bid presentation.
  final AuctionSummary? auction;

  final DateTime? auctionEndsAt;
  final VoidCallback? onPlaceBid;

  /// The winner settling shipping and tax, once their payment has gone through.
  final VoidCallback? onCompletePurchase;

  /// The winner supplying a different card after theirs was declined.
  final VoidCallback? onFixPayment;

  final String? statusLabel;
  final VoidCallback? onMessage;

  @override
  State<AuctionBidBar> createState() => _AuctionBidBarState();
}

class _AuctionBidBarState extends State<AuctionBidBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AuctionBidBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  /// A one-second repaint, and only while a live deadline is on screen.
  ///
  /// Scoped this tightly on purpose: a ten-minute window shown as "9:42" is misleading the
  /// moment it stops moving, and running a timer for the rest of the time would repaint the
  /// bar once a second on every auction in the app for no reason.
  void _syncTicker() {
    final needsTicker = widget.auction?.needsPaymentFix == true &&
        widget.auction?.winnerDeadlineAt != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auction = widget.auction;
    final timeRemaining = formatTimeRemaining(widget.auctionEndsAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (auction?.needsPaymentFix == true) ...[
            _PaymentFailedBanner(deadline: auction!.winnerDeadlineAt),
            const SizedBox(height: 16),
          ] else if (auction?.needsCheckout == true) ...[
            _WonBanner(amountCents: auction!.winningBidCents),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _priceCaption(auction),
                            style: PieceDetailType.meta,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (auction?.isOpenForBidding == true &&
                            auction?.isHighestBidder == true) ...[
                          const SizedBox(width: 8),
                          const _LeadingPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.bidDisplay,
                      style: PieceDetailType.price,
                      strutStyle: PieceDetailType.priceStrut,
                    ),
                  ],
                ),
              ),
              if (timeRemaining != null && auction?.isClosed != true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      auction?.isClosingSoon == true ? 'Closing' : 'Time remaining',
                      style: PieceDetailType.meta,
                    ),
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
          if (auction?.hasReserve == true && auction?.isOpenForBidding == true) ...[
            const SizedBox(height: 8),
            Text(
              // Met or not met, never the number — that is the point of a hidden reserve.
              auction!.reserveMet
                  ? 'Reserve met'
                  : 'Reserve not yet met — the piece only sells above it',
              style: AppFonts.inter(
                fontSize: 12,
                color: auction.reserveMet
                    ? CollectDetailTokens.textSecondary
                    : CollectDetailTokens.statusError,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _primaryAction()),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onMessage,
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

  String _priceCaption(AuctionSummary? auction) {
    if (auction?.isClosed == true) {
      return auction?.winningBidCents != null ? 'Winning bid' : 'Final bid';
    }
    return widget.bidCount > 0 ? 'Current bid · ${widget.bidCount} bids' : 'Starting bid';
  }

  Widget _primaryAction() {
    final auction = widget.auction;

    if (auction?.needsPaymentFix == true) {
      return _BidCta(
        label: 'Update card',
        onTap: widget.onFixPayment,
        emphasis: _CtaEmphasis.urgent,
      );
    }
    if (auction?.needsCheckout == true) {
      return _BidCta(label: 'Complete purchase', onTap: widget.onCompletePurchase);
    }
    return _BidCta(
      label: widget.statusLabel ?? 'Place a bid',
      onTap: widget.onPlaceBid,
    );
  }
}

/// The winner's card was declined. Deliberately the most prominent thing on the screen: if
/// this is missed, they lose a piece they have already won.
class _PaymentFailedBanner extends StatelessWidget {
  const _PaymentFailedBanner({this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final countdown = formatDeadlineCountdown(deadline);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CollectDetailTokens.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CollectDetailTokens.statusError.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: CollectDetailTokens.statusError,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You won — but your card was declined',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CollectDetailTokens.statusError,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countdown == null
                      ? 'Add another card now to keep this piece.'
                      : 'Add another card within $countdown or this piece goes to the '
                          'next bidder.',
                  style: AppFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WonBanner extends StatelessWidget {
  const _WonBanner({this.amountCents});

  final int? amountCents;

  @override
  Widget build(BuildContext context) {
    final paid = amountCents == null
        ? 'Your payment has gone through.'
        : '\$${(amountCents! / 100).toStringAsFixed(2)} has been paid.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You won this piece',
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CollectDetailTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // Says what is left rather than restating the total, because the hammer price is
            // already collected and quoting it again reads as a second charge.
            '$paid Add your delivery details to settle shipping and tax.',
            style: AppFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: CollectDetailTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadingPill extends StatelessWidget {
  const _LeadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CollectDetailTokens.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "You're winning",
        style: AppFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: CollectDetailTokens.textInverse,
        ),
      ),
    );
  }
}

enum _CtaEmphasis { normal, urgent }

class _BidCta extends StatelessWidget {
  const _BidCta({
    required this.label,
    this.onTap,
    this.emphasis = _CtaEmphasis.normal,
  });

  final String label;
  final VoidCallback? onTap;
  final _CtaEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final base = emphasis == _CtaEmphasis.urgent
        ? CollectDetailTokens.statusError
        : CollectDetailTokens.ctaFill;
    return SizedBox(
      height: 40,
      child: Material(
        color: onTap == null ? base.withValues(alpha: 0.5) : base,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(child: Text(label, style: PieceDetailType.collect)),
        ),
      ),
    );
  }
}

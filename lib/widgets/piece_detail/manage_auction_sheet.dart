import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/auction_summary.dart';
import '../../services/api_exception.dart';
import '../../services/bid_service.dart';
import '../../theme/collect_detail_tokens.dart';

/// What a seller can do to their own running or finished auction.
///
/// The three actions differ enormously in consequence, and the sheet is built to make that
/// difference visible rather than presenting them as a row of equivalent buttons:
///
/// * **Extend** is nearly free — the auction runs longer and every bid and hold survives.
/// * **Cancel** releases real money. Everybody bidding is refunded and told the seller
///   withdrew it, so the confirmation says how many people that is.
/// * **Relist** only applies once an auction has ended without a sale, and starts a fresh
///   run rather than reopening the old one.
///
/// Returns true if anything changed, so the caller knows to reload.
class ManageAuctionSheet extends StatefulWidget {
  const ManageAuctionSheet({
    super.key,
    required this.pieceId,
    required this.auction,
  });

  final String pieceId;
  final AuctionSummary auction;

  static Future<bool> show(
    BuildContext context, {
    required String pieceId,
    required AuctionSummary auction,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => ManageAuctionSheet(pieceId: pieceId, auction: auction),
    );
    return changed ?? false;
  }

  @override
  State<ManageAuctionSheet> createState() => _ManageAuctionSheetState();
}

class _ManageAuctionSheetState extends State<ManageAuctionSheet> {
  bool _busy = false;
  String? _error;

  AuctionSummary get auction => widget.auction;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server's wording is the useful one here — it explains *why* an extension or a
      // relist was refused, which a generic message cannot.
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _extend() async {
    final days = await _askExtraDays();
    if (days == null) return;
    await _run(() => BidService.instance.extend(widget.pieceId, extraDays: days));
  }

  Future<int?> _askExtraDays() {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Extend by', style: GoogleFonts.inter(fontSize: 16)),
        children: [
          for (final days in [1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, days),
              child: Text(
                days == 1 ? '1 day' : '$days days',
                style: GoogleFonts.inter(fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel this auction?', style: GoogleFonts.inter(fontSize: 17)),
        content: Text(
          auction.bidCount == 0
              ? 'The piece will be delisted. You can list it again at any time.'
              : 'Every one of the ${auction.bidCount} bids will be cancelled and those '
                  'bidders refunded. They will be told you withdrew the piece.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it running'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancel auction',
              style: TextStyle(color: CollectDetailTokens.statusError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => BidService.instance.cancel(widget.pieceId));
  }

  Future<void> _relist() async {
    await _run(
      () => BidService.instance.relist(widget.pieceId, durationDays: 7),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canExtend = auction.isOpenForBidding;
    final canCancel = auction.isOpenForBidding;
    final canRelist = auction.needsSellerDecision;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: CollectDetailTokens.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage auction',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusLine(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: CollectDetailTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              if (canExtend)
                _ActionRow(
                  label: 'Extend the auction',
                  detail: auction.bidCount > 0
                      ? 'Adds up to 3 days. Every bid and hold stays exactly as it is.'
                      : 'Adds up to 3 days. Once only, and not in the last 3 days.',
                  enabled: !_busy,
                  onTap: _extend,
                ),
              if (canRelist)
                _ActionRow(
                  label: 'Run it again',
                  detail: 'Starts a fresh 7-day auction on the same terms. The previous '
                      'auction is kept as a record of what happened.',
                  enabled: !_busy,
                  onTap: _relist,
                ),
              if (canCancel)
                _ActionRow(
                  label: 'Cancel the auction',
                  detail: auction.bidCount > 0
                      ? '${auction.bidCount} bidders are refunded and told you withdrew it.'
                      : 'The piece is delisted. Nobody has bid, so nobody is affected.',
                  destructive: true,
                  enabled: !_busy,
                  onTap: _cancel,
                ),
              if (!canExtend && !canCancel && !canRelist)
                Text(
                  'There is nothing to change on this auction.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CollectDetailTokens.textSecondary,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: CollectDetailTokens.statusError,
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine() {
    if (auction.needsSellerDecision) {
      return auction.bidCount > 0 || auction.highestBidCents != null
          ? 'This auction ended without a sale. Nothing was charged to anyone.'
          : 'This auction ended with no bids.';
    }
    if (auction.needsPaymentFix) {
      return "The winner's payment was declined. They have a short window to fix it before "
          'the piece passes to the next bidder.';
    }
    if (auction.isClosed) return 'This auction has finished.';
    final bids = auction.bidCount;
    return bids == 0
        ? 'Live, with no bids yet.'
        : 'Live, with $bids ${bids == 1 ? 'bid' : 'bids'}.';
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.detail,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String detail;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? CollectDetailTokens.statusError
        : CollectDetailTokens.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? color : color.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: CollectDetailTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

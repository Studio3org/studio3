import 'package:flutter/material.dart';

import '../../models/auction_summary.dart';
import '../../services/api_exception.dart';
import '../../services/auction_service.dart';
import '../studio/studio.dart';

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
///
/// No board: a Studio sheet ("Manage auction" 22, the status 14 Graphite) with plain action
/// rows (15/500 over a 12 Graphite line, a chevron, a Line under); every action Ink, Cancel
/// included (`HandoffRules`), its weight carried by the confirmation instead.
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
    final changed = await showStudioSheet<bool>(
      context: context,
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
    await _run(() => AuctionService.instance.extend(widget.pieceId, extraDays: days));
  }

  Future<int?> _askExtraDays() {
    return showStudioSheet<int>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 0,
        children: [
          const SizedBox(height: 12),
          Text('Extend by', style: StudioType.title22(color: sheetContext.studio.textPrimary)),
          const SizedBox(height: 8),
          for (final days in [1, 2, 3])
            StudioSelectRow(
              title: days == 1 ? '1 day' : '$days days',
              selected: false,
              titleSize: 17,
              titleLetterSpacing: 0,
              verticalPadding: 14,
              ruleInset: 12,
              divider: days != 3,
              onTap: () => Navigator.pop(sheetContext, days),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Cancel this auction?',
      message: auction.bidCount == 0
          ? 'The piece will be delisted. You can list it again at any time.'
          : 'Every one of the ${auction.bidCount} bids will be cancelled and those '
                'bidders refunded. They will be told you withdrew the piece.',
      confirmLabel: 'Cancel auction',
      cancelLabel: 'Keep it running',
    );
    if (!confirmed) return;
    await _run(() => AuctionService.instance.cancel(widget.pieceId));
  }

  Future<void> _relist() async {
    await _run(
      () => AuctionService.instance.relist(widget.pieceId, durationDays: 7),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final canExtend = auction.isOpenForBidding;
    final canCancel = auction.isOpenForBidding;
    final canRelist = auction.canRelist;

    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      children: [
        const SizedBox(height: 12),
        Text('Manage auction', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 6),
        Text(_statusLine(), style: StudioType.body14(color: c.textSecondary)),
        const SizedBox(height: 10),
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
            detail:
                'Starts a fresh 7-day auction on the same terms. The previous '
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
            enabled: !_busy,
            onTap: _cancel,
          ),
        if (!canExtend && !canCancel && !canRelist)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'There is nothing to change on this auction.',
              style: StudioType.body14(color: c.textSecondary),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: StudioType.label13(color: c.alert)),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  String _statusLine() {
    if (auction.status == 'closed_no_bids') {
      return 'This auction ended with no bids.';
    }
    if (auction.needsSellerDecision || auction.status == 'closed_reserve_not_met') {
      return 'This auction ended without a sale. Nothing was charged to anyone.';
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
  });

  final String label;
  final String detail;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: StudioType.sans(
                        15,
                        weight: StudioType.medium,
                        color: enabled ? c.textPrimary : c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(detail, style: StudioType.caption12(height: 1.45, color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

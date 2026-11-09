import 'package:flutter/material.dart';

import '../../models/auction.dart';
import '../../models/feed_preview_item.dart';
import '../create_flow/post_availability_step.dart' show formatUsd;
import '../studio/studio.dart';

/// What the artist sees on their own auction (`ArtistAuctionLive`, `ArtistAuctionEnd`,
/// `ArtistAuctionPayment`, `ArtistAuctionUnsold`; `HandoffBidding` "Last four screens").
enum ArtistAuctionView {
  /// Bidding is open: YOUR AUCTION, the bids, Share auction and End auction early.
  live,

  /// It ended with a winner who is still paying (confirming shipping). Not on the boards: the
  /// payment-failed page without the red card.
  settling,

  /// The winner's card was declined: the red card with their deadline.
  paymentFailed,

  /// It ended without a sale (no bids, or under the reserve): relist, fixed price, or keep.
  unsold,
}

/// The artist's view of [item], or null when it isn't their auction or there is nothing to
/// say (sold: the collected page; cancelled: a plain not-for-sale piece).
ArtistAuctionView? artistAuctionView(FeedPreviewItem item, {required bool isOwner}) {
  if (!isOwner || !item.isAuction || item.status == 'sold') return null;
  final auction = item.auction;
  if (auction != null) {
    if (auction.isOpen) return ArtistAuctionView.live;
    if (auction.status == 'awaiting_payment') return ArtistAuctionView.paymentFailed;
    if (auction.status == 'awaiting_winner') return ArtistAuctionView.settling;
    return null;
  }
  final last = item.lastAuction;
  if (last != null && last.unsold && item.status != 'live') return ArtistAuctionView.unsold;
  return null;
}

/// "4 bidders", "1 bidder".
String _bidders(int n) => n == 1 ? '1 bidder' : '$n bidders';

/// "9:40 AM CST tomorrow" (`ArtistAuctionPayment`): the time, the zone when the phone names
/// one, then today / tomorrow, or the date further out.
String winnerDeadlinePhrase(DateTime deadline, DateTime now) {
  final t = deadline.toLocal();
  final n = now.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time = '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  final zone = t.timeZoneName;
  final named = RegExp(r'^[A-Z]{2,5}$').hasMatch(zone) ? '$time $zone' : time;
  final days = DateTime(t.year, t.month, t.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (days <= 0) return '$named today';
  if (days == 1) return '$named tomorrow';
  return '${auctionDateTime(t).split(' · ').first} at $named';
}

/// `ArtistAuctionUnsold`'s line: why it didn't sell, then the interest it had.
String unsoldLine(EndedAuction last, {int? saves}) {
  final why = last.underReserve
      ? (last.topBidCents != null
            ? 'Top bid ${formatUsd(last.topBidCents!)}, under your reserve.'
            : 'Bids stayed under your reserve.')
      : 'No one bid this time.';
  final interest = <String>[
    if (last.bidderCount > 0) _bidders(last.bidderCount),
    if ((saves ?? 0) > 0) saves == 1 ? '1 save' : '$saves saves',
  ];
  if (interest.isEmpty) return why;
  return '$why ${interest.join(' and ')}.';
}

/// The block under the title on the artist's own auction. Mono 11 tag, then:
///
/// * live: Current bid 36/500 and Ends in (Mono 20, red under 24 hours); "6 bids · Reserve
///   met · Started at $400"; Bids 17/500 with a row per bid (Bidder N, amount, Mono age),
///   and "Bidders stay anonymous until the winner pays."
/// * payment failed: Winning bid, and a white card with the red ! and the winner's deadline.
/// * unsold: "It didn't sell this time" 24/500 and why.
class ArtistAuctionSection extends StatelessWidget {
  const ArtistAuctionSection({
    super.key,
    required this.view,
    required this.item,
    this.history,
    this.now,
  });

  final ArtistAuctionView view;
  final FeedPreviewItem item;

  /// The bids (BACKEND_CHANGES B38); null while loading or when the server has none.
  final AuctionBidHistory? history;

  @visibleForTesting
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final at = now ?? DateTime.now();
    final a = item.auction;
    final children = <Widget>[];
    Widget tag(String text) =>
        Text(text, style: StudioType.mono(11, color: c.textTertiary).copyWith(letterSpacing: 0.5));
    Widget label(String text) => Text(text, style: StudioType.sans(13, color: c.textSecondary));
    Widget big(String text) => Text(
      text,
      style: StudioType.sans(36, weight: StudioType.medium, letterSpacing: -1, color: c.textPrimary)
          .copyWith(height: 1),
    );

    switch (view) {
      case ArtistAuctionView.live:
        if (a == null) return const SizedBox.shrink();
        final soon = auctionEndingSoon(a.endsAt, at);
        final dot = Text('  ·  ', style: StudioType.sans(13, color: c.lineStrong));
        children.addAll([
          tag('YOUR AUCTION'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label(a.bidCount == 0 ? 'Starting bid' : 'Current bid'),
                    const SizedBox(height: 2),
                    big(formatUsd(a.currentCents)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  label('Ends in'),
                  const SizedBox(height: 2),
                  Text(
                    auctionTimeLeft(a.endsAt, at),
                    style: StudioType.mono(20, color: soon ? c.alert : c.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                a.bidCount == 1 ? '1 bid' : '${a.bidCount} bids',
                style: StudioType.mono(13, color: c.textPrimary),
              ),
              if (a.hasReserve) ...[
                dot,
                Text(
                  a.reserveMet ? 'Reserve met' : 'Below reserve',
                  style: StudioType.sans(13, color: a.reserveMet ? c.positive : c.textSecondary),
                ),
              ],
              dot,
              Text(
                'Started at ${formatUsd(a.startingBidCents)}',
                style: StudioType.sans(13, color: c.textSecondary),
              ),
            ],
          ),
          if (history != null && history!.items.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('Bids', style: StudioType.header17(color: c.textPrimary)),
            const SizedBox(height: 4),
            for (final row in history!.items) _BidRow(row: row, now: at),
            const SizedBox(height: 12),
            Text(
              'Bidders stay anonymous until the winner pays.',
              style: StudioType.caption12(height: 1.5, color: c.textTertiary),
            ),
          ],
        ]);
      case ArtistAuctionView.paymentFailed:
      case ArtistAuctionView.settling:
        if (a == null) return const SizedBox.shrink();
        final deadline = a.winnerDeadlineAt;
        final next = history?.nextBidCents;
        children.addAll([
          tag('AUCTION ENDED'),
          const SizedBox(height: 8),
          label('Winning bid'),
          const SizedBox(height: 2),
          big(formatUsd(a.winningBidCents ?? a.currentCents)),
          if (view == ArtistAuctionView.paymentFailed) ...[
            const SizedBox(height: 18),
            Container(
              key: const Key('artist-auction-payment-card'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.alert, width: 1.5),
                    ),
                    child: Text(
                      '!',
                      style: StudioType.sans(12, weight: FontWeight.w600, color: c.alert),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Payment didn't go through",
                          style: StudioType.sans(15, weight: StudioType.medium, color: c.alert),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (deadline != null) ...[
                                const TextSpan(text: 'The winner has until '),
                                TextSpan(
                                  text: winnerDeadlinePhrase(deadline, at),
                                  style: StudioType.mono(13, color: c.textBody),
                                ),
                                const TextSpan(text: ' to update their card. '),
                              ] else
                                const TextSpan(text: 'The winner has a little time to update their card. '),
                              TextSpan(
                                text: next != null
                                    ? 'If not, it goes to the next bidder at ${formatUsd(next)}.'
                                    : 'If not, it goes to the next bidder.',
                              ),
                            ],
                          ),
                          style: StudioType.sans(13, height: 1.5, color: c.textBody),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Nothing to do. We'll tell you when it's paid.",
              style: StudioType.sans(13, height: 1.5, color: c.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              "The winner is confirming shipping. Nothing to do. We'll tell you when it's paid.",
              style: StudioType.sans(13, height: 1.5, color: c.textSecondary),
            ),
          ],
        ]);
      case ArtistAuctionView.unsold:
        final last = item.lastAuction;
        if (last == null) return const SizedBox.shrink();
        children.addAll([
          tag('AUCTION ENDED'),
          const SizedBox(height: 8),
          Text(
            "It didn't sell this time",
            style: StudioType.sans(24, weight: StudioType.medium, letterSpacing: -0.4, color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            unsoldLine(last, saves: item.savesCount),
            style: StudioType.body15(height: 1.5, color: c.textSecondary),
          ),
        ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// "Bidder 3" (500 for the top bidder), the amount 14, and a Mono 12 age 52 wide; 11 above
/// and below, a Line under.
class _BidRow extends StatelessWidget {
  const _BidRow({required this.row, required this.now});

  final AuctionBidRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Bidder ${row.bidder}',
              style: StudioType.sans(
                14,
                weight: row.isTop ? StudioType.medium : StudioType.regular,
                color: row.isTop ? c.textPrimary : c.textBody,
              ),
            ),
          ),
          Text(formatUsd(row.amountCents), style: StudioType.sans(14, color: c.textPrimary)),
          const SizedBox(width: 14),
          SizedBox(
            width: 52,
            child: Text(
              auctionBidAge(row.createdAt, now),
              textAlign: TextAlign.right,
              style: StudioType.mono(12, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The artist's bottom bar: a stack of buttons 4 apart over the page fade. Live: Share
/// auction, then End auction early (grey) once someone bid; payment failed: Message Studio 3
/// support; unsold: Relist as an auction, Sell at a fixed price (outlined), Keep it as not for
/// sale (grey).
class ArtistAuctionBar extends StatelessWidget {
  const ArtistAuctionBar({
    super.key,
    required this.view,
    required this.bidCount,
    this.onShare,
    this.onEndEarly,
    this.onSupport,
    this.onRelist,
    this.onFixedPrice,
    this.onKeep,
  });

  final ArtistAuctionView view;
  final int bidCount;
  final VoidCallback? onShare;
  final VoidCallback? onEndEarly;
  final VoidCallback? onSupport;
  final VoidCallback? onRelist;
  final VoidCallback? onFixedPrice;
  final VoidCallback? onKeep;

  static const _primary = StudioSize.buttonPrimary;
  static const _link = 40.0;
  static const _gap = 4.0;

  static double _buttons(ArtistAuctionView view, int bidCount) => switch (view) {
    ArtistAuctionView.live => bidCount > 0 ? _primary + _gap + _link : _primary,
    ArtistAuctionView.paymentFailed || ArtistAuctionView.settling => _link,
    ArtistAuctionView.unsold => _primary * 2 + _link + _gap * 2,
  };

  /// The bar's full height, for the page's bottom padding.
  static double totalHeight(BuildContext context, ArtistAuctionView view, int bidCount) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return 28 + _buttons(view, bidCount) + (safe > 0 ? safe : StudioSize.noInsetBottomPadding);
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, VoidCallback? onTap) => StudioButton(
      label: label,
      variant: StudioButtonVariant.text,
      height: _link,
      onPressed: onTap,
    );
    final buttons = switch (view) {
      ArtistAuctionView.live => [
        StudioButton(label: 'Share auction', onPressed: onShare),
        if (bidCount > 0) link('End auction early', onEndEarly),
      ],
      ArtistAuctionView.paymentFailed || ArtistAuctionView.settling => [
        link('Message Studio 3 support', onSupport),
      ],
      ArtistAuctionView.unsold => [
        StudioButton(label: 'Relist as an auction', onPressed: onRelist),
        StudioButton(
          label: 'Sell at a fixed price',
          variant: StudioButtonVariant.outline,
          height: _primary,
          fontSize: 15,
          onPressed: onFixedPrice,
        ),
        link('Keep it as not for sale', onKeep),
      ],
    };
    return StudioBottomBar(
      button: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

/// "End this auction?" (`ArtistAuctionEnd`): ending early cancels it. 22/500, what happens 15
/// Graphite, End and cancel auction, Keep auction running. True when they end it.
Future<bool> confirmEndAuction(BuildContext context, {int? bidderCount}) async {
  final told = switch (bidderCount) {
    null => 'every bidder is told',
    1 => 'the bidder is told',
    _ => 'all $bidderCount bidders are told',
  };
  final ended = await showStudioSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.studio;
      return StudioSheet(
        horizontalPadding: 24,
        gap: 10,
        children: [
          Text('End this auction?', style: StudioType.title22(color: c.textPrimary)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "No one wins or is charged, and $told. This can't be undone.",
              style: StudioType.body15(height: 1.5, color: c.textSecondary),
            ),
          ),
          StudioButton(
            label: 'End and cancel auction',
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          StudioButton(
            label: 'Keep auction running',
            variant: StudioButtonVariant.text,
            height: 40,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      );
    },
  );
  return ended == true;
}

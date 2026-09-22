import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/studio_event.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/auction_time.dart';
import '../home_feed/home_feed_widgets.dart';

/// The works on the bill, and what they are at right now.
///
/// This is the screen somebody looks at while standing in the room, so it is built around
/// two facts that change under them:
///
/// * **What each work is at.** Live bids, not the starting price — a lineup that only showed
///   the asking figure would be the least current thing in the room the moment anyone bid.
/// * **How long is left.** Every auction at an event closes at the same moment, thirty
///   minutes before the event ends, and it is a hard stop with no soft close. A countdown is
///   the whole difference between "there is time" and "there was".
///
/// It refreshes on a timer while bidding is open and stops when it is not. Polling an event
/// whose auctions closed hours ago would burn battery to learn nothing.
class EventLineupSection extends StatefulWidget {
  const EventLineupSection({
    super.key,
    required this.event,
    required this.onRefresh,
    this.onTapPiece,
  });

  final StudioEvent event;

  /// Re-fetches the event. Called on the poll tick, and awaited so a slow request cannot
  /// stack up behind itself.
  final Future<void> Function() onRefresh;

  final void Function(EventLineupItem item)? onTapPiece;

  @override
  State<EventLineupSection> createState() => _EventLineupSectionState();
}

class _EventLineupSectionState extends State<EventLineupSection> {
  Timer? _poll;
  bool _refreshing = false;

  /// Often enough that a bid placed across the room shows up while you are still looking at
  /// it, rare enough not to hammer the server for a whole gallery at once.
  static const _pollInterval = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _syncPolling();
  }

  @override
  void didUpdateWidget(EventLineupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Poll only while something on the bill is actually live.
  void _syncPolling() {
    final wanted = widget.event.lineup.any((item) => item.isBiddingOpen);
    if (wanted && _poll == null) {
      _poll = Timer.periodic(_pollInterval, (_) => _tick());
    } else if (!wanted) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _tick() async {
    // Skip rather than queue: a request slower than the interval would otherwise pile up.
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      await widget.onRefresh();
    } catch (_) {
      // A dropped poll is not worth surfacing — the next tick tries again, and an error
      // banner over a live auction would be more alarming than useful.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineup = widget.event.lineup;
    if (lineup.isEmpty) return const SizedBox.shrink();

    // Every event auction shares the event's clock, so one countdown serves the whole
    // section rather than repeating on each row.
    final closesAt = lineup
        .map((i) => i.auction?.endsAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final anyOpen = lineup.any((item) => item.isBiddingOpen);
    final remaining = anyOpen ? formatDeadlineCountdown(closesAt) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: DecoratedBox(
        // A tinted card, not just another row in the plain scroll — this is the one section
        // on the page with real money moving on a clock, and it used to look exactly like
        // the static "Pieces at this event" strip below it.
        decoration: BoxDecoration(
          color: const Color(0xFFFBEFE8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEBD3C2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, size: 16, color: Color(0xFFB3261E)),
                  const SizedBox(width: 6),
                  Text(
                    anyOpen ? 'On the block' : 'In this event',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (remaining != null)
                    Text(
                      // Said once, for the room: everything closes together.
                      'Closes in $remaining',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB3261E),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in lineup)
                _LineupRow(item: item, onTap: () => widget.onTapPiece?.call(item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  const _LineupRow({required this.item, this.onTap});

  final EventLineupItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final live = item.auction;
    final leading = live?.isHighestBidder ?? false;
    final won = live?.isWinner ?? false;
    final open = item.isBiddingOpen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: FeedPicsumImage(url: item.mediaUrl ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (open) ...[
                        const _BiddingOpenTag(),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title ?? 'Untitled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (leading || won) ...[
                            const SizedBox(width: 6),
                            _Pill(label: won ? 'You won' : "You're winning"),
                          ],
                        ],
                      ),
                      if (item.artistName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.artistName!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        item.statusLine,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _money(item.currentCents),
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _money(int? cents) {
    if (cents == null) return '—';
    final amount = cents / 100;
    return amount == amount.roundToDouble()
        ? '\$${amount.toStringAsFixed(0)}'
        : '\$${amount.toStringAsFixed(2)}';
  }
}

/// The one-glance flag that this specific work can be bid on right now — distinct from
/// [_Pill], which says where *this viewer* stands rather than whether bidding is open at all.
class _BiddingOpenTag extends StatelessWidget {
  const _BiddingOpenTag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF2E8B57),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'Bidding open',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E8B57),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: HomeFeedTokens.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: HomeFeedTokens.textInverse,
        ),
      ),
    );
  }
}

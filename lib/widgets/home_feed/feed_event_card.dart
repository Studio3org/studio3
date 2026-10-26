import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../utils/money_format.dart';
import '../events/event_detail_widgets.dart' show EventCover;
import '../events/event_tickets_sheet.dart' show eventStartLabel;
import '../studio/studio.dart';

/// The one event the home feed shows per load (`NoteMain`, `HandoffBrowse`): an event in the
/// next two weeks, not cancelled or over — one from someone the viewer follows first, then the
/// soonest. Null when there is none.
StudioEvent? pickFeedEvent(EventBrowse browse, DateTime now) {
  final until = now.add(const Duration(days: 14));
  bool fits(StudioEvent e) => !e.isCancelled && e.endsAt.isAfter(now) && e.startsAt.isBefore(until);
  int soonest(StudioEvent a, StudioEvent b) => a.startsAt.compareTo(b.startsAt);
  final followed = browse.following.where(fits).toList()..sort(soonest);
  if (followed.isNotEmpty) return followed.first;
  final seen = <String>{};
  final rest = [
    for (final e in [...browse.today, ...browse.upcoming])
      if (fits(e) && seen.add(e.id)) e,
  ]..sort(soonest);
  return rest.isEmpty ? null : rest.first;
}

/// Where the event card goes in a feed of [rows] (true = a series row): after the third row,
/// moved down until neither neighbour is a series row (`NoteMain`). -1 for an empty feed or no
/// such place.
int feedEventSlot(List<bool> rows) {
  if (rows.isEmpty) return -1;
  bool series(int i) => i >= 0 && i < rows.length && rows[i];
  var at = rows.length < 3 ? rows.length : 3;
  while (at <= rows.length && (series(at - 1) || series(at))) {
    at++;
  }
  return at > rows.length ? -1 : at;
}

/// An event card in the home feed (`Main` event card; `EventNoArtists` without a lineup): an Ink
/// card at radius 18, 16 from the sides. Top: the 76 flyer at radius 10, the EVENT tag (white
/// pill, Mono 11/500 — the feed keeps EVENT so it stands out among the art) with the Mono 12
/// date, the name 19/500 and one line 13. Bottom, under a #2A2A2A line: "Showing work" with up
/// to three artists (44 avatars) and "+N More" when there is a lineup; Price and Where when
/// there is none; Get tickets (white, 44, radius 10) either way. Ink in both themes, with a
/// line around it in dark so it doesn't melt into the page.
class FeedEventCard extends StatelessWidget {
  const FeedEventCard({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onGetTickets,
    required this.onArtist,
  });

  final StudioEvent event;
  final VoidCallback onOpen;
  final VoidCallback onGetTickets;
  final void Function(EventPerson artist) onArtist;

  static const _secondary = StudioColors.onDarkSecondary;
  static const _rule = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = event.details.trim().split('\n').first.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(
        container: true,
        label: 'Event at ${event.venue.isEmpty ? event.title : event.venue}',
        child: GestureDetector(
          onTap: onOpen,
          behavior: HitTestBehavior.opaque,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: StudioColors.ink,
              borderRadius: BorderRadius.circular(18),
              border: dark ? Border.all(color: _rule) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StudioRadius.card),
                        child: SizedBox.square(dimension: 76, child: EventCover(url: event.imageUrl)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'EVENT',
                                    style: StudioType.mono(11, weight: StudioType.medium, color: StudioColors.ink),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    eventStartLabel(event),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: StudioType.mono(12, color: _secondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: StudioType.sans(19, weight: StudioType.medium, height: 1.2, color: white),
                            ),
                            if (line.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.label13(color: _secondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: _rule))),
                  child: event.artists.isEmpty ? _priceWhere() : _showingWork(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getTickets() {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onGetTickets,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StudioColors.galleryWhite,
            borderRadius: BorderRadius.circular(StudioRadius.card),
          ),
          child: Text(
            'Get tickets',
            style: StudioType.body14(weight: StudioType.medium, color: StudioColors.ink),
          ),
        ),
      ),
    );
  }

  /// `EventNoArtists`: Price and Where (12 Graphite over 15/500), 24 apart.
  Widget _priceWhere() {
    final lowest = event.ticketOptions.map((t) => t.priceCents).reduce((a, b) => a < b ? a : b);
    Widget fact(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: StudioType.caption12(color: _secondary)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StudioType.sans(15, weight: StudioType.medium, color: StudioColors.galleryWhite),
        ),
      ],
    );
    return Row(
      children: [
        fact('Price', lowest == 0 ? 'Free' : formatMoney(lowest)),
        if (event.venue.isNotEmpty) ...[
          const SizedBox(width: 24),
          Flexible(child: fact('Where', event.venue)),
        ],
        const Spacer(),
        const SizedBox(width: 12),
        _getTickets(),
      ],
    );
  }

  /// `Main` event card: "Showing work" 13/500, up to three artists (44 avatar, name 12) and
  /// "+N More", 14 apart.
  Widget _showingWork() {
    final shown = event.artists.take(3).toList();
    final more = event.artists.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Showing work', style: StudioType.label13(weight: StudioType.medium, color: _secondary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => onArtist(shown[i]),
                        child: _Person(
                          label: shown[i].displayName.split(' ').first,
                          child: StudioAvatar(url: shown[i].avatarUrl, size: 44, semanticLabel: shown[i].displayName),
                        ),
                      ),
                    ],
                    if (more > 0) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onOpen,
                        child: _Person(
                          label: 'More',
                          labelColor: _secondary,
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: _rule, shape: BoxShape.circle),
                            child: Text(
                              '+$more',
                              style: StudioType.label13(
                                weight: StudioType.medium,
                                color: StudioColors.galleryWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _getTickets(),
          ],
        ),
      ],
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.label, required this.child, this.labelColor = StudioColors.galleryWhite});

  final String label;
  final Widget child;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        Text(label, maxLines: 1, style: StudioType.caption12(color: labelColor)),
      ],
    );
  }
}

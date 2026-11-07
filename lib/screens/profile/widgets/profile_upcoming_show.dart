import 'package:flutter/material.dart';

import '../../../models/studio_event.dart';
import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../../../widgets/events/event_detail_widgets.dart' show EventCover, eventDayLabel;

/// The venue and date under the show's name: `[Venue] · [Date]`, or the date alone.
String profileShowLine(StudioEvent event) {
  final venue = (event.venueName ?? '').trim();
  return [if (venue.isNotEmpty) venue, eventDayLabel(event)].join(' · ');
}

/// The profile's Upcoming show (`ProfileSeller`, `ProfileOwn`): an Ink card at radius 14 with
/// 10 inside. The 56 flyer at radius 9; the UPCOMING SHOW tag (Mono 10/500, Gallery White
/// pill), the name 15/500 on one line and `[Venue] · [Date]` in Mono 11; Tickets (36, radius
/// 10, Gallery White, 13/500) on the right in a 44 target. Ink in both themes, with a line
/// around it in dark, as the feed's event card. The card opens the event; Tickets opens it
/// with Choose tickets.
class ProfileUpcomingShow extends StatelessWidget {
  const ProfileUpcomingShow({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onTickets,
  });

  final StudioEvent event;
  final VoidCallback onOpen;
  final VoidCallback onTickets;

  static const _rule = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.ink,
        borderRadius: BorderRadius.circular(14),
        border: dark ? Border.all(color: _rule) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Upcoming show, ${event.title}, ${profileShowLine(event)}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox.square(dimension: 56, child: EventCover(url: event.imageUrl)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'UPCOMING SHOW',
                              style: StudioType.mono(10, weight: StudioType.medium, color: StudioColors.ink),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(15, weight: StudioType.medium, color: white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profileShowLine(event),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.mono(11, color: StudioColors.onDarkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Tickets',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTickets,
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Center(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tickets',
                      style: StudioType.label13(weight: StudioType.medium, color: StudioColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

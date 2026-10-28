import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/post_picker_options.dart';
import '../../models/studio_event.dart';
import '../studio/studio.dart';

/// The Events tab (`EvTab`; plan section 17.1): its parts, its date lines and its filters.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _time(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _zone(StudioEvent e) => e.zoneLabel.isEmpty ? '' : ' ${e.zoneLabel}';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// More than one calendar day (an exhibition): its card says when it runs, not a time.
bool eventSpansDays(StudioEvent e) => !_sameDay(e.startsAt, e.endsAt);

/// The Mono date line on cards: "Today · 6:00 PM CST", "Sat · 6:00 PM CST" this week,
/// "Nov 21 · 6:00 PM CST" later; "Through Dec 12" / "Opens Nov 28" for a run of days.
String eventCardWhen(StudioEvent e, DateTime now) {
  if (eventSpansDays(e)) {
    final end = e.endsAt;
    final start = e.startsAt;
    return start.isAfter(now)
        ? 'Opens ${_months[start.month - 1]} ${start.day}'
        : 'Through ${_months[end.month - 1]} ${end.day}';
  }
  final s = e.startsAt;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(s.year, s.month, s.day);
  final days = day.difference(today).inDays;
  final when = days == 0
      ? 'Today'
      : days > 0 && days < 7
      ? _weekdays[s.weekday - 1]
      : '${_months[s.month - 1]} ${s.day}';
  return '$when · ${_time(s)}${_zone(e)}';
}

/// The featured card's line: "Sat, Nov 21 · 8:00 PM CST".
String eventFeaturedWhen(StudioEvent e) {
  final s = e.startsAt;
  return '${_weekdays[s.weekday - 1]}, ${_months[s.month - 1]} ${s.day} · ${_time(s)}${_zone(e)}';
}

/// "Cedars Union · Free": venue and price. Prices are full prices, no buyer fees.
String eventVenuePrice(StudioEvent e) =>
    [e.venue, e.isFree ? 'Free' : e.priceLabel].where((p) => p.isNotEmpty).join(' · ');

/// Today, This week, This month (`EvTab`): they filter everything below.
enum EventRange { today, week, month }

extension EventRangeLabel on EventRange {
  String get label => switch (this) {
    EventRange.today => 'Today',
    EventRange.week => 'This week',
    EventRange.month => 'This month',
  };

  /// Whether [e] happens at some point in this range from [now].
  bool includes(StudioEvent e, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final end = switch (this) {
      EventRange.today => today.add(const Duration(days: 1)),
      EventRange.week => today.add(const Duration(days: 7)),
      EventRange.month => DateTime(now.year, now.month + 1),
    };
    return e.startsAt.isBefore(end) && e.endsAt.isAfter(now);
  }
}

/// The filters sheet's choices (`EvTab`: "price, free only, category"; every event is free
/// on the server today, so there is no price range).
class EventFilters {
  const EventFilters({this.freeOnly = false, this.category});

  final bool freeOnly;
  final String? category;

  bool get isActive => freeOnly || category != null;

  bool matches(StudioEvent e) =>
      (!freeOnly || e.isFree) && (category == null || e.category == category);
}

/// "+" (host an event), "Near me ▾" (the place), and the ticket for Your events: 10 above,
/// 8 sides, 44 targets.
class EventsTabHeader extends StatelessWidget {
  const EventsTabHeader({
    super.key,
    required this.place,
    required this.onHost,
    required this.onPlace,
    required this.onYourEvents,
  });

  final String place;
  final VoidCallback onHost;
  final VoidCallback onPlace;
  final VoidCallback onYourEvents;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget icon(String asset, String label, VoidCallback onTap, double size) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: StudioSize.tapTarget,
          child: Center(child: StudioIcon(asset, size: size, color: c.textPrimary)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          icon(StudioIcons.plus, 'Host an event', onHost, 24),
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                label: '$place, change place',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onPlace,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: StudioSize.tapTarget,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          place,
                          style: StudioType.sans(
                            16,
                            weight: StudioType.medium,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        StudioIcon(StudioIcons.chevronDown, size: 18, color: c.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          icon(StudioIcons.ticket, 'Your events', onYourEvents, 22),
        ],
      ),
    );
  }
}

/// The filters icon (with a dot while a filter is on), then Today / This week / This month
/// at 14 (the chosen one 500 Ink over a 2 px Ink line, the others 400 Tertiary); 18 apart.
class EventRangeTabs extends StatelessWidget {
  const EventRangeTabs({
    super.key,
    required this.range,
    required this.onRange,
    required this.onFilters,
    this.filtersActive = false,
  });

  final EventRange range;
  final ValueChanged<EventRange> onRange;
  final VoidCallback onFilters;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          StudioTapArea(child: Semantics(
            button: true,
            label: 'Filters',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onFilters,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 20,
                height: 31,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    StudioIcon(StudioIcons.sliders, size: 20, color: c.textPrimary),
                    if (filtersActive)
                      Positioned(
                        top: 4,
                        right: -3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )),
          for (final r in EventRange.values) ...[
            const SizedBox(width: 18),
            StudioTapArea(child: Semantics(
              button: true,
              selected: r == range,
              child: GestureDetector(
                onTap: () => onRange(r),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: r == range ? c.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    r.label,
                    style: StudioType.sans(
                      14,
                      weight: r == range ? StudioType.medium : StudioType.regular,
                      color: r == range ? c.textPrimary : c.textTertiary,
                    ),
                  ),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _Flyer extends StatelessWidget {
  const _Flyer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.studio.surface);
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// Featured (`EvTab`): the flyer full width at 390 × 470, darkening from 45 % down to 0.7
/// Ink; "Featured" 12 white at the top; at the bottom the category in Mono 11 caps, the name
/// 26/500, the venue 14 and the Mono 12 date.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({super.key, required this.event, required this.onTap});

  final StudioEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    const shadow = [Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1))];
    return Semantics(
      button: true,
      label: 'Featured: ${event.title}',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 390 / 470,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Flyer(url: event.imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Color(0x00111111), Color(0xB3111111)],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 16,
                child: Text(
                  'Featured',
                  style: StudioType.sans(12, color: Colors.white).copyWith(shadows: shadow),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.kicker,
                      style: StudioType.mono(11, color: white).copyWith(letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(
                        26,
                        weight: StudioType.medium,
                        letterSpacing: -0.4,
                        height: 1.25,
                        color: white,
                      ),
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.venue, style: StudioType.sans(14, color: white)),
                    ],
                    const SizedBox(height: 4),
                    Text(eventFeaturedWhen(event), style: StudioType.mono(12, color: white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section title (`EvTab`): 17/500 with "See all →" 13 Graphite; 26 above, 12 below.
class EventSectionTitle extends StatelessWidget {
  const EventSectionTitle({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: StudioType.header17(weight: StudioType.medium, color: c.textPrimary),
            ),
          ),
          if (onSeeAll != null)
            Semantics(
              button: true,
              label: 'See all $title',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onSeeAll,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all', style: StudioType.label13(color: c.textSecondary)),
                    const SizedBox(width: 4),
                    StudioIcon(StudioIcons.arrowRight, size: 14, color: c.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bookmark on a card: outline Tertiary, filled Ink when saved.
class EventBookmark extends StatelessWidget {
  const EventBookmark({super.key, required this.saved, required this.onTap, this.size = 18});

  final bool saved;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      toggled: saved,
      label: saved ? 'Saved' : 'Save',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: StudioIcon(
            saved ? StudioIcons.saved : StudioIcons.save,
            size: size,
            color: saved ? c.textPrimary : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// A list row (`EvTab` Today): 76 × 101 flyer (radius 8), 14 gap, the name 15/500, venue and
/// price 13 Graphite and the Mono 11 date, 4 apart; the bookmark on the right.
class EventListRow extends StatelessWidget {
  const EventListRow({
    super.key,
    required this.event,
    required this.saved,
    required this.onTap,
    required this.onSave,
    required this.now,
  });

  final StudioEvent event;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(StudioRadius.small),
                child: SizedBox(width: 76, height: 101, child: _Flyer(url: event.imageUrl)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eventVenuePrice(event),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(eventCardWhen(event, now), style: StudioType.mono(11, color: c.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EventBookmark(saved: saved, onTap: onSave),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card in a sideways row (`EvTab`): 150 × 200 flyer (radius 10); then the name 14/500
/// with the bookmark, venue and price 12 Graphite, and the Mono 11 date, 4 apart.
class EventPosterCard extends StatelessWidget {
  const EventPosterCard({
    super.key,
    required this.event,
    required this.saved,
    required this.onTap,
    required this.onSave,
    required this.now,
  });

  static const double width = 150;

  final StudioEvent event;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(StudioRadius.card),
                child: SizedBox(height: 200, child: _Flyer(url: event.imageUrl)),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(14, weight: StudioType.medium, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Transform.translate(
                    offset: const Offset(4, -3),
                    child: EventBookmark(saved: saved, onTap: onSave, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                eventVenuePrice(event),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.caption12(color: c.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(eventCardWhen(event, now), style: StudioType.mono(11, color: c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sideways row of cards, 12 apart, 16 from the edges.
class EventCardRow extends StatelessWidget {
  const EventCardRow({super.key, required this.children, this.bottom = 0});

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A category (`EvTab` Browse by category): 160 × 200, radius 12, darkening from half way;
/// the name 16/500 white and "6 upcoming" in Mono 11, 12 from the bottom left.
class EventCategoryCard extends StatelessWidget {
  const EventCategoryCard({super.key, required this.category, required this.onTap});

  final EventCategoryCount category;
  final VoidCallback onTap;

  /// "Studio visits": the app's own category names, else the server's id made readable.
  static String nameOf(String id) {
    final option = EventCategoryOptions.byId(id);
    if (option != null) return option.name;
    final words = id.split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return id;
    return [words.first[0].toUpperCase() + words.first.substring(1), ...words.skip(1)].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    return Semantics(
      button: true,
      label: '${nameOf(category.id)}, ${category.upcomingCount} upcoming',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudioRadius.button),
          child: SizedBox(
            width: 160,
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Flyer(url: category.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.5, 1],
                      colors: [Color(0x00111111), Color(0x99111111)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nameOf(category.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.sans(16, weight: StudioType.medium, color: white),
                      ),
                      Text(
                        '${category.upcomingCount} upcoming',
                        style: StudioType.mono(11, color: white),
                      ),
                    ],
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

/// The filters sheet (the slider icon on `EvTab`): Free only, then the category; Done
/// applies, Clear resets. Returns the new filters, or null when dismissed.
class EventFiltersSheet extends StatefulWidget {
  const EventFiltersSheet({super.key, required this.initial});

  final EventFilters initial;

  static Future<EventFilters?> show(BuildContext context, EventFilters initial) {
    return showStudioSheet<EventFilters>(
      context: context,
      useRootNavigator: true,
      builder: (_) => EventFiltersSheet(initial: initial),
    );
  }

  @override
  State<EventFiltersSheet> createState() => _EventFiltersSheetState();
}

class _EventFiltersSheetState extends State<EventFiltersSheet> {
  late bool _freeOnly = widget.initial.freeOnly;
  late String? _category = widget.initial.category;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final options = [null, ...EventCategoryOptions.all.map((o) => o.id)];
    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      scrollable: true,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Filters', style: StudioType.title22(color: c.textPrimary))),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => setState(() {
                  _freeOnly = false;
                  _category = null;
                }),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Clear',
                    style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Free only',
                  style: StudioType.sans(16, color: c.textPrimary),
                ),
              ),
              StudioSwitch(
                value: _freeOnly,
                onChanged: (v) => setState(() => _freeOnly = v),
                semanticLabel: 'Free only',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 2),
          child: Text(
            'CATEGORY',
            style: StudioType.mono(11, weight: StudioType.medium, color: c.textTertiary)
                .copyWith(letterSpacing: 0.5),
          ),
        ),
        for (var i = 0; i < options.length; i++)
          StudioListRow(
            title: options[i] == null ? 'All categories' : EventCategoryCard.nameOf(options[i]!),
            selected: _category == options[i],
            divider: i < options.length - 1,
            onTap: () => setState(() => _category = options[i]),
          ),
        const SizedBox(height: 18),
        StudioButton(
          label: 'Show events',
          onPressed: () => Navigator.pop(
            context,
            EventFilters(freeOnly: _freeOnly, category: _category),
          ),
        ),
      ],
    );
  }
}

/// "Near me ▾": Near me, then the cities of the events already loaded.
Future<String?> showEventPlaceSheet(
  BuildContext context, {
  required String current,
  required List<String> cities,
}) {
  final options = ['Near me', ...cities];
  return showStudioSheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final c = sheetContext.studio;
      return StudioSheet(
        horizontalPadding: 24,
        gap: 0,
        scrollable: true,
        children: [
          const SizedBox(height: 8),
          Text('Where', style: StudioType.title22(color: c.textPrimary)),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            StudioListRow(
              title: options[i],
              selected: options[i] == current,
              divider: i < options.length - 1,
              onTap: () => Navigator.pop(sheetContext, options[i]),
            ),
        ],
      );
    },
  );
}

/// The city in an address: "1 Main St, Dallas, TX 75201" → "Dallas"; null when unclear.
String? eventCity(StudioEvent e) {
  final parts = (e.address ?? '').split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.length < 2) return null;
  final city = list[list.length - 2];
  return RegExp(r'\d').hasMatch(city) ? null : city;
}

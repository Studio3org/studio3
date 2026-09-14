import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/event_dummy_data.dart';
import '../../theme/home_feed_tokens.dart';
import '../home_feed/home_feed_widgets.dart';

abstract final class EventAssets {
  static const back = 'assets/event/back.svg';
  static const nearChevron = 'assets/event/near_chevron.svg';
  static const headerBookmark = 'assets/event/header_bookmark.svg';
  static const search = 'assets/event/search.svg';
  static const calendar = 'assets/event/calendar.svg';
  static const bookmark = 'assets/event/bookmark.svg';
  static const bookmarkFill = 'assets/event/bookmark_fill.svg';
}

abstract final class EventTokens {
  static const Color pageBg = HomeFeedTokens.detailBackground;
  static const Color primary = HomeFeedTokens.textPrimary;
  static const Color secondary = HomeFeedTokens.textSecondary;
  static const Color inverse = HomeFeedTokens.textInverse;
  static const Color time = Color(0xFFC4541E);
  static const Color hairline = Color(0xFFC8C5BC);
}

TextStyle _geist({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = EventTokens.primary,
  double? height,
}) {
  return GoogleFonts.geist(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

class EventHeaderBar extends StatelessWidget {
  const EventHeaderBar({
    super.key,
    required this.locationLabel,
    required this.onLocationTap,
    this.onLeadingTap,
    this.onSavedTap,
  });

  final String locationLabel;
  final VoidCallback onLocationTap;
  final VoidCallback? onLeadingTap;
  final VoidCallback? onSavedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            GestureDetector(
              onTap: onLeadingTap,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                EventAssets.back,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  EventTokens.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onLocationTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      locationLabel,
                      style: _geist(size: 20, weight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    SvgPicture.asset(
                      EventAssets.nearChevron,
                      width: 8,
                      height: 4,
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onSavedTap,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                EventAssets.headerBookmark,
                width: 14,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  EventTokens.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventSearchField extends StatelessWidget {
  const EventSearchField({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EventTokens.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Row(
          children: [
            SvgPicture.asset(EventAssets.search, width: 18, height: 19),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: EventTokens.primary,
                style: _geist(size: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search events...',
                  hintStyle: _geist(size: 14, color: EventTokens.secondary),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventTimeFilters extends StatelessWidget {
  const EventTimeFilters({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labels = ['Today', 'This week', 'This month'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Row(
        children: [
          SvgPicture.asset(EventAssets.calendar, width: 17, height: 15),
          const SizedBox(width: 12),
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            GestureDetector(
              onTap: () => onSelected(i),
              child: Text(
                _labels[i],
                style: _geist(
                  size: 14,
                  weight: i == selectedIndex
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: i == selectedIndex
                      ? EventTokens.primary
                      : EventTokens.secondary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Text('|', style: _geist(size: 14, color: EventTokens.secondary)),
        ],
      ),
    );
  }
}

class EventHeroCard extends StatelessWidget {
  const EventHeroCard({super.key, required this.event, this.onTap});

  final DummyEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width * (519 / 390);
    const scrim = Color(0xCC231F1B);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FeedPicsumImage(url: event.imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [scrim, Color(0x00000000)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [scrim, Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: EventTokens.primary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Featured',
                  style: _geist(size: 11, color: EventTokens.inverse),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.kicker,
                  style: _geist(size: 10, color: EventTokens.inverse),
                ),
                Text(
                  event.title,
                  style: _geist(
                    size: 24,
                    weight: FontWeight.w700,
                    color: EventTokens.inverse,
                  ),
                ),
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    event.venue,
                    style: _geist(size: 13, color: EventTokens.inverse),
                  ),
                ),
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    event.scheduleLine,
                    style: _geist(size: 13, color: EventTokens.inverse),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class EventSectionHeader extends StatelessWidget {
  const EventSectionHeader({
    super.key,
    required this.title,
    this.showSeeAll = true,
    this.onSeeAll,
  });

  final String title;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: _geist(size: 14, weight: FontWeight.w500),
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'see all →',
                style: _geist(size: 13, color: EventTokens.secondary),
              ),
            ),
        ],
      ),
    );
  }
}

class EventBookmarkButton extends StatelessWidget {
  const EventBookmarkButton({
    super.key,
    required this.saved,
    required this.onTap,
    this.filled = false,
  });

  final bool saved;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final useFill = saved || filled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 2),
        child: SvgPicture.asset(
          useFill ? EventAssets.bookmarkFill : EventAssets.bookmark,
          width: useFill ? 12 : 11,
          height: useFill ? 16 : 14,
        ),
      ),
    );
  }
}

class EventCompactCard extends StatelessWidget {
  const EventCompactCard({
    super.key,
    required this.event,
    required this.saved,
    required this.onBookmark,
    this.onTap,
  });

  final DummyEvent event;
  final bool saved;
  final VoidCallback onBookmark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
      width: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 88,
              height: 111,
              child: FeedPicsumImage(url: event.imageUrl),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: _geist(size: 14, weight: FontWeight.w500),
                      ),
                    ),
                    EventBookmarkButton(saved: saved, onTap: onBookmark),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.venueLine,
                  style: _geist(size: 11, color: EventTokens.secondary),
                ),
                const SizedBox(height: 2),
                Text(event.whenLabel, style: _geist(size: 11, color: EventTokens.time)),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class EventPortraitCard extends StatelessWidget {
  const EventPortraitCard({
    super.key,
    required this.event,
    required this.saved,
    required this.onBookmark,
    this.onTap,
  });

  final DummyEvent event;
  final bool saved;
  final VoidCallback onBookmark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 180,
              height: 228,
              child: FeedPicsumImage(url: event.imageUrl),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: _geist(size: 14, weight: FontWeight.w500),
                ),
              ),
              EventBookmarkButton(saved: saved, onTap: onBookmark),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            event.venueLine,
            style: _geist(size: 11, color: EventTokens.secondary),
          ),
          const SizedBox(height: 2),
          Text(event.whenLabel, style: _geist(size: 11, color: EventTokens.time)),
        ],
      ),
    ),
    );
  }
}

class EventCategoryTile extends StatelessWidget {
  const EventCategoryTile({super.key, required this.category});

  final DummyEventCategory category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FeedPicsumImage(url: category.imageUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0xCC231F1B), Color(0x00000000)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 17,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: _geist(
                      size: 16,
                      weight: FontWeight.w700,
                      color: EventTokens.inverse,
                    ),
                  ),
                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      category.upcomingLabel,
                      style: _geist(size: 11, color: EventTokens.inverse),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventHScroll extends StatelessWidget {
  const EventHScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

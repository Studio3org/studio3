import 'package:flutter/material.dart';

import '../data/event_dummy_data.dart';
import '../screens/event_detail_page.dart';
import '../screens/event_post_page.dart';
import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../widgets/events/event_feed_widgets.dart';

/// Events tab — Figma `2783:12462`. Dummy content until events API ships.
class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage>
    with ScrollsToTopOnDoubleTap<EventPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _store = SavedContentStore.instance;
  String _location = 'Near me';
  int _rangeIndex = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void scrollToTopAndRefresh() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  List<DummyEvent> _filter(List<DummyEvent> source) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.venue.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _pickLocation() async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: EventTokens.pageBg,
      builder: (context) {
        const options = ['Near me', 'Dallas', 'Fort Worth', 'Austin'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  title: Text(option),
                  trailing: option == _location
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (next != null && mounted) setState(() => _location = next);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;
    final today = _filter(EventDummyData.today);
    final following = _filter(EventDummyData.following);
    final workshops = _filter(EventDummyData.workshops);
    final exhibitions = _filter(EventDummyData.exhibitions);

    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            EventHeaderBar(
              locationLabel: _location,
              onLocationTap: _pickLocation,
              onLeadingTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const EventPostPage(),
                ),
              ),
              onSavedTap: () => Navigator.pushNamed(context, '/saved'),
            ),
            EventSearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
            EventTimeFilters(
              selectedIndex: _rangeIndex,
              onSelected: (i) => setState(() => _rangeIndex = i),
            ),
            EventHeroCard(
              event: EventDummyData.featured,
              onTap: () => openEventDetail(context, EventDummyData.featured),
            ),
            const SizedBox(height: 24),
            const EventSectionHeader(title: 'Today'),
            EventHScroll(
              children: [
                for (final e in today)
                  EventCompactCard(
                    event: e,
                    saved: _store.isSaved(e.id),
                    onBookmark: () => _store.toggleEvent(e),
                    onTap: () => openEventDetail(context, e),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const EventSectionHeader(title: 'From artists you follow'),
            EventHScroll(
              children: [
                for (final e in following)
                  EventPortraitCard(
                    event: e,
                    saved: _store.isSaved(e.id),
                    onBookmark: () => _store.toggleEvent(e),
                    onTap: () => openEventDetail(context, e),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const EventSectionHeader(title: 'Workshops & Classes'),
            EventHScroll(
              children: [
                for (final e in workshops)
                  EventPortraitCard(
                    event: e,
                    saved: _store.isSaved(e.id),
                    onBookmark: () => _store.toggleEvent(e),
                    onTap: () => openEventDetail(context, e),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const EventSectionHeader(title: 'Exhibitions'),
            EventHScroll(
              children: [
                for (final e in exhibitions)
                  EventPortraitCard(
                    event: e,
                    saved: _store.isSaved(e.id),
                    onBookmark: () => _store.toggleEvent(e),
                    onTap: () => openEventDetail(context, e),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const EventSectionHeader(
              title: 'Browse by category',
              showSeeAll: false,
            ),
            EventHScroll(
              children: [
                for (final c in EventDummyData.categories)
                  EventCategoryTile(category: c),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../screens/event_detail_page.dart';
import '../screens/scan_qr_page.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../screens/event_post_page.dart';
import '../screens/my_events_page.dart';
import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../widgets/events/event_feed_widgets.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/studio_message.dart';

/// Events tab — Figma `2783:12462`.
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

  EventBrowse? _browse;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    // Whatever was browsed last time paints on the first frame; `_load`
    // revalidates behind it instead of blanking the sections.
    _browse = EventService.instance.peekBrowseCached();
    _load();
  }

  Future<void> _load() async {
    try {
      final browse = await EventService.instance.browseCached(
        onBackgroundUpdate: (fresh) {
          if (!mounted) return;
          setState(() => _browse = fresh);
        },
      );
      if (!mounted) return;
      setState(() {
        _browse = browse;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load events. Pull to refresh.';
      });
    }
  }

  /// Save on the server first, then mirror into the local store.
  ///
  /// The server is the source of truth — a save has to survive reinstalling the app — and
  /// the local store exists so the Saved tab updates without a round trip. Writing the
  /// local copy only after the server call succeeds keeps the two from disagreeing when the
  /// request fails.
  Future<void> _toggleSaved(StudioEvent event) async {
    final wasSaved = _store.isSaved(event.id);
    try {
      await EventService.instance.setSaved(event.id, saved: !wasSaved);
      if (!mounted) return;
      _store.toggleEvent(event);
    } on ApiException catch (e) {
      if (!mounted) return;
      StudioMessage.show(context, e.message);
    } catch (_) {
      if (!mounted) return;
      StudioMessage.show(context, 'Could not save that event.');
    }
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

  List<StudioEvent> _filter(List<StudioEvent> source) {
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
    final browse = _browse;
    final today = _filter(browse?.today ?? const []);
    final following = _filter(browse?.following ?? const []);
    final upcoming = _filter(browse?.upcoming ?? const []);
    // The two named sections are slices of what is coming up, not separate endpoints — the
    // server returns one upcoming list and the tab groups it.
    final workshops = upcoming.where((e) => e.category == 'workshop').toList();
    final exhibitions = upcoming.where((e) => e.category == 'exhibition').toList();
    final categories = (browse?.categories ?? const <EventCategoryCount>[])
        .where((c) => c.upcomingCount > 0)
        .toList();
    // Whatever is soonest leads the page. Today first, because an event happening in hours
    // is a better headline than one three weeks out.
    final featured = today.isNotEmpty
        ? today.first
        : (upcoming.isNotEmpty ? upcoming.first : null);

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
              onMyEventsTap: () => MyEventsPage.open(context),
              onScanTap: () => ScanQrPage.open(context),
            ),
            EventSearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
            EventTimeFilters(
              selectedIndex: _rangeIndex,
              onSelected: (i) => setState(() => _rangeIndex = i),
            ),
            // Header bar, search field and time filters above are static
            // and already interactive. Only the event data placeholds, and
            // only while nothing has been loaded or cached yet.
            if (_loading && browse == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: HeroBlockSkeleton(),
              )
            else if (_error != null && browse == null)
              _EventsMessage(text: _error!, onRetry: _load)
            else if (featured == null)
              const _EventsMessage(
                text: "No events on just yet. When someone near you hosts one, it'll "
                    'show up here.',
              )
            else
              EventHeroCard(
                event: featured,
                onTap: () => openEventDetail(context, featured),
              ),
            // Each section below is hidden outright — header included — when
            // it has nothing to show, rather than leaving an empty row under
            // a heading with nothing under it.
            if (today.isNotEmpty) ...[
              const SizedBox(height: 24),
              const EventSectionHeader(title: 'Today'),
              EventHScroll(
                children: [
                  for (final e in today)
                    EventCompactCard(
                      event: e,
                      saved: _store.isSaved(e.id),
                      onBookmark: () => _toggleSaved(e),
                      onTap: () => openEventDetail(context, e),
                    ),
                ],
              ),
            ],
            if (following.isNotEmpty) ...[
              const SizedBox(height: 24),
              const EventSectionHeader(title: 'From artists you follow'),
              EventHScroll(
                children: [
                  for (final e in following)
                    EventPortraitCard(
                      event: e,
                      saved: _store.isSaved(e.id),
                      onBookmark: () => _toggleSaved(e),
                      onTap: () => openEventDetail(context, e),
                    ),
                ],
              ),
            ],
            if (workshops.isNotEmpty) ...[
              const SizedBox(height: 24),
              const EventSectionHeader(title: 'Workshops & Classes'),
              EventHScroll(
                children: [
                  for (final e in workshops)
                    EventPortraitCard(
                      event: e,
                      saved: _store.isSaved(e.id),
                      onBookmark: () => _toggleSaved(e),
                      onTap: () => openEventDetail(context, e),
                    ),
                ],
              ),
            ],
            if (exhibitions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const EventSectionHeader(title: 'Exhibitions'),
              EventHScroll(
                children: [
                  for (final e in exhibitions)
                    EventPortraitCard(
                      event: e,
                      saved: _store.isSaved(e.id),
                      onBookmark: () => _toggleSaved(e),
                      onTap: () => openEventDetail(context, e),
                    ),
                ],
              ),
            ],
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 24),
              const EventSectionHeader(
                title: 'Browse by category',
                showSeeAll: false,
              ),
              EventHScroll(
                children: [
                  for (final c in categories) EventCategoryTile(category: c),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// An empty or failed events tab. Says what happened, and offers a way back when there is
/// one — a blank screen with no explanation reads as a broken app.
class _EventsMessage extends StatelessWidget {
  const _EventsMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

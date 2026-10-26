import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../services/saved_content_store.dart';
import '../utils/require_login.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../widgets/events/event_tab_widgets.dart';
import '../widgets/post_picker_search_field.dart';
import '../widgets/studio/studio.dart';
import 'event_detail_page.dart';
import 'event_list_page.dart';
import 'host/host_event_page.dart';
import 'my_events_page.dart';

/// The Events tab (`EvTab`): + to host, "Near me ▾", the ticket for Your events; search;
/// the filters icon with Today / This week / This month (they filter everything below);
/// Featured; the range's list; From artists you follow, Workshops and classes, Exhibitions
/// as sideways rows; Browse by category.
///
/// The server has no featured pick, place filter or event search yet (BACKEND_CHANGES B23):
/// Featured is the soonest event in range that starts today or later, and the place, search and filters narrow what
/// `GET /api/events/browse` returned.
class EventPage extends StatefulWidget {
  const EventPage({super.key, this.debugBrowse, this.debugNow});

  /// For tests: the browse response and the clock.
  @visibleForTesting
  final EventBrowse? debugBrowse;
  @visibleForTesting
  final DateTime? debugNow;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with ScrollsToTopOnDoubleTap<EventPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _store = SavedContentStore.instance;

  EventBrowse? _browse;
  bool _loading = true;
  String? _error;
  EventRange _range = EventRange.today;
  EventFilters _filters = const EventFilters();
  String _place = 'Near me';

  DateTime get _now => widget.debugNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    final given = widget.debugBrowse;
    if (given != null) {
      _browse = given;
      _loading = false;
      return;
    }
    _browse = EventService.instance.peekBrowseCached();
    _load();
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

  Future<void> _load({bool fresh = false}) async {
    if (widget.debugBrowse != null) return;
    try {
      final browse = fresh
          ? await EventService.instance.browse()
          : await EventService.instance.browseCached(
              onBackgroundUpdate: (next) {
                if (mounted) setState(() => _browse = next);
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
        _error = 'Could not load events.';
      });
    }
  }

  @override
  void scrollToTopAndRefresh() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: StudioMotion.quick, curve: Curves.easeOut);
    }
    _load(fresh: true);
  }

  Future<void> _toggleSaved(StudioEvent event) async {
    if (!await requireLogin(
      context,
      title: 'Sign in to save events',
      message: 'Log in or create a free account to save events.',
    )) {
      return;
    }
    final wasSaved = _store.isSaved(event.id);
    try {
      await EventService.instance.setSaved(event.id, saved: !wasSaved);
      if (!mounted) return;
      _store.toggleEvent(event);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save that event.', icon: null);
    }
  }

  Future<void> _host() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to host an event',
      message: 'Log in or create a free account to host events.',
    )) {
      return;
    }
    if (!mounted) return;
    await HostEventPage.open(context);
    // A newly published event belongs on the tab straight away.
    if (mounted) _load(fresh: true);
  }

  Future<void> _yourEvents() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to see your events',
      message: 'Log in to see the events you host, save and go to.',
    )) {
      return;
    }
    if (mounted) MyEventsPage.open(context);
  }

  List<StudioEvent> get _all {
    final browse = _browse;
    if (browse == null) return const [];
    final seen = <String>{};
    return [
      for (final e in [...browse.today, ...browse.upcoming, ...browse.following])
        if (seen.add(e.id)) e,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<String> get _cities {
    final cities = <String>{};
    for (final e in _all) {
      final city = eventCity(e);
      if (city != null) cities.add(city);
    }
    return cities.toList()..sort();
  }

  /// The range, place, search and filters, in that order.
  bool _shows(StudioEvent e) {
    if (e.isCancelled || !_range.includes(e, _now)) return false;
    if (_place != 'Near me' && eventCity(e) != _place) return false;
    if (!_filters.matches(e)) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [e.title, e.venue, e.hostName ?? '', e.hostUsername ?? '', e.kicker]
        .any((field) => field.toLowerCase().contains(q));
  }

  Future<void> _pickPlace() async {
    final next = await showEventPlaceSheet(context, current: _place, cities: _cities);
    if (next != null && mounted) setState(() => _place = next);
  }

  Future<void> _openFilters() async {
    final next = await EventFiltersSheet.show(context, _filters);
    if (next != null && mounted) setState(() => _filters = next);
  }

  void _seeAll(String title, Future<List<StudioEvent>> Function() load) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => EventListPage(title: title, load: load)),
    );
  }

  Widget _poster(StudioEvent e) => EventPosterCard(
    event: e,
    saved: _store.isSaved(e.id),
    onTap: () => openEventDetail(context, e),
    onSave: () => _toggleSaved(e),
    now: _now,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final browse = _browse;
    final shown = _all.where(_shows).toList();
    // The soonest event that starts from today on (a run that is already open is not
    // "featured" news); any event in range otherwise.
    final dayStart = DateTime(_now.year, _now.month, _now.day);
    final featured = shown.isEmpty
        ? null
        : shown.firstWhere((e) => !e.startsAt.isBefore(dayStart), orElse: () => shown.first);
    // Same rule for the range's list: what starts in range first, then runs already open.
    bool starts(StudioEvent e) => !e.startsAt.isBefore(dayStart);
    final listed = [
      ...shown.where((e) => e != featured && starts(e)),
      ...shown.where((e) => e != featured && !starts(e)),
    ].take(3).toList();
    final following = (browse?.following ?? const <StudioEvent>[]).where(_shows).toList();
    final workshops = shown.where((e) => e.category == 'workshop').toList();
    final exhibitions = shown.where((e) => e.category == 'exhibition').toList();
    final categories = (browse?.categories ?? const <EventCategoryCount>[])
        .where((cat) => cat.upcomingCount > 0)
        .toList();
    final filtering =
        _search.text.trim().isNotEmpty || _filters.isActive || _place != 'Near me';

    final service = EventService.instance;
    final body = <Widget>[];
    if (_loading && browse == null) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AspectRatio(aspectRatio: 390 / 470, child: ColoredBox(color: c.surface)),
        ),
      );
    } else if (_error != null && browse == null) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: StudioEmptyState(
            title: "Events didn't load",
            message: _error,
            actionLabel: 'Try again',
            onAction: () => _load(fresh: true),
          ),
        ),
      );
    } else if (_all.isEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: StudioEmptyState(
            title: 'No events yet',
            message: 'When someone near you hosts an event, it shows up here.',
            actionLabel: 'Host an event',
            onAction: _host,
          ),
        ),
      );
    } else {
      if (featured != null) {
        body.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FeaturedEventCard(
              event: featured,
              onTap: () => openEventDetail(context, featured),
            ),
          ),
        );
      } else {
        body.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 8),
            child: Text(
              filtering
                  ? 'No events match. Try another place, search or filter.'
                  : 'Nothing on ${_range == EventRange.today ? 'today' : _range.label.toLowerCase()}. '
                        'Try a longer range.',
              textAlign: TextAlign.center,
              style: StudioType.body15(height: 1.5, color: c.textSecondary),
            ),
          ),
        );
      }
      if (listed.isNotEmpty) {
        body.add(
          EventSectionTitle(
            title: _range.label,
            onSeeAll: () => _seeAll(
              _range.label,
              () async => _range == EventRange.today
                  ? await service.list(scope: 'today')
                  : (await service.list()).where((e) => _range.includes(e, _now)).toList(),
            ),
          ),
        );
        for (var i = 0; i < listed.length; i++) {
          if (i > 0) body.add(const SizedBox(height: 14));
          final e = listed[i];
          body.add(
            EventListRow(
              event: e,
              saved: _store.isSaved(e.id),
              onTap: () => openEventDetail(context, e),
              onSave: () => _toggleSaved(e),
              now: _now,
            ),
          );
        }
      }
      void row(String title, List<StudioEvent> events, Future<List<StudioEvent>> Function() load) {
        if (events.isEmpty) return;
        body.add(EventSectionTitle(title: title, onSeeAll: () => _seeAll(title, load)));
        body.add(EventCardRow(children: [for (final e in events.take(10)) _poster(e)]));
      }

      row('From artists you follow', following, () => service.list(scope: 'following'));
      row('Workshops and classes', workshops, () => service.list(category: 'workshop'));
      row('Exhibitions', exhibitions, () => service.list(category: 'exhibition'));
      if (categories.isNotEmpty) {
        body.add(const EventSectionTitle(title: 'Browse by category'));
        body.add(
          EventCardRow(
            bottom: 40,
            children: [
              for (final cat in categories)
                EventCategoryCard(
                  category: cat,
                  onTap: () => _seeAll(
                    EventCategoryCard.nameOf(cat.id),
                    () => service.list(category: cat.id),
                  ),
                ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.textPrimary,
          onRefresh: () => _load(fresh: true),
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 100),
            children: [
              EventsTabHeader(
                place: _place,
                onHost: _host,
                onPlace: _pickPlace,
                onYourEvents: _yourEvents,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: PostPickerSearchField(
                  controller: _search,
                  hintText: 'Search events',
                  height: 44,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              EventRangeTabs(
                range: _range,
                onRange: (r) => setState(() => _range = r),
                onFilters: _openFilters,
                filtersActive: _filters.isActive,
              ),
              ...body,
            ],
          ),
        ),
      ),
    );
  }
}

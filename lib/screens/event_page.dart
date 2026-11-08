import 'dart:async';

import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../services/saved_content_store.dart';
import '../utils/require_login.dart';
import '../utils/scrolls_to_top_on_double_tap.dart';
import '../widgets/save_flow.dart';
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
/// The range, place and search go to the server (BACKEND_CHANGES B23): browse comes back
/// narrowed, with the team's Featured pick, and Near me lists the server's cities. The same
/// rules also run here over what came back, so the cached tab paints right before the
/// narrowed one arrives; with no Featured pick in range, the soonest event that starts today
/// or later stands in.
class EventPage extends StatefulWidget {
  const EventPage({super.key, this.debugBrowse, this.debugNow, this.debugRefine, this.debugCities});

  /// For tests: the browse response and the clock.
  @visibleForTesting
  final EventBrowse? debugBrowse;
  @visibleForTesting
  final DateTime? debugNow;

  /// For tests: the narrowed browse for a range, place and search, and the cities.
  @visibleForTesting
  final Future<EventBrowse> Function(DateTime from, DateTime to, String? city, String? q)? debugRefine;
  @visibleForTesting
  final Future<List<String>> Function()? debugCities;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with ScrollsToTopOnDoubleTap<EventPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _store = SavedContentStore.instance;

  EventBrowse? _browse;

  /// Browse narrowed on the server to the range, place and search shown (B23).
  EventBrowse? _refined;
  Timer? _searchDebounce;
  int _refineCalls = 0;
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
      _refine();
      return;
    }
    _browse = EventService.instance.peekBrowseCached();
    _load();
    _refine();
  }

  /// Ask the server for the range, place and search shown (B23). A later call wins; a
  /// failure keeps what is on screen, which the same rules already narrow here.
  Future<void> _refine() async {
    final refine = widget.debugRefine ??
        (widget.debugBrowse != null
            ? null
            : (DateTime from, DateTime to, String? city, String? q) =>
                EventService.instance.browse(from: from, to: to, city: city, q: q, limit: 50));
    if (refine == null) return;
    final call = ++_refineCalls;
    final q = _search.text.trim();
    try {
      final next = await refine(
        _now,
        _range.endFrom(_now),
        _place == 'Near me' ? null : _place,
        q.isEmpty ? null : q,
      );
      if (mounted && call == _refineCalls) setState(() => _refined = next);
    } catch (_) {
      // Keep the cached tab.
    }
  }

  void _onSearch(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _refine);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _searchDebounce?.cancel();
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
      if (fresh) _refine();
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
      announceEventSave(context, event, saved: !wasSaved);
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
    final browse = _refined ?? _browse;
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

  /// Near me: the server's cities with something coming up (B23), else the ones found here.
  Future<void> _pickPlace() async {
    var cities = _cities;
    final load = widget.debugCities ??
        (widget.debugBrowse != null ? null : EventService.instance.cities);
    try {
      final fromServer = load == null ? const <String>[] : await load();
      if (fromServer.isNotEmpty) cities = fromServer;
    } catch (_) {
      // The cities found in what browse returned.
    }
    if (!mounted) return;
    final next = await showEventPlaceSheet(context, current: _place, cities: cities);
    if (next != null && next != _place && mounted) {
      setState(() => _place = next);
      _refine();
    }
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
    final browse = _refined ?? _browse;
    final shown = _all.where(_shows).toList();
    // The team's pick in this range and place (B23); else the soonest event that starts from
    // today on (a run that is already open is not "featured" news), or any event in range.
    final dayStart = DateTime(_now.year, _now.month, _now.day);
    final picked = _refined?.featured;
    final featured = picked != null && _shows(picked)
        ? picked
        : shown.isEmpty
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
    } else if ((_browse?.isEmpty ?? true) && _all.isEmpty) {
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
              () async => (await service.list(
                scope: _range == EventRange.today ? 'today' : 'upcoming',
                from: _now,
                to: _range.endFrom(_now),
                city: _place == 'Near me' ? null : _place,
                q: _search.text,
                limit: 50,
              )).where((e) => _range.includes(e, _now)).toList(),
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
                  onChanged: _onSearch,
                ),
              ),
              EventRangeTabs(
                range: _range,
                onRange: (r) {
                  setState(() => _range = r);
                  _refine();
                },
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

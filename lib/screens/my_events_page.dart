import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/events/your_events_widgets.dart';
import '../widgets/studio/studio.dart';
import 'event_detail_page.dart';
import 'event_list_page.dart';
import 'host/host_event_page.dart';
import 'host/host_manage_page.dart';
import 'event_ticket_page.dart';
import 'scan_qr_page.dart';

/// Your events (`EvMyTickets`), from the ticket icon on the Events tab: one page that scrolls.
/// Upcoming (the next event as a large card, the rest as rows), Saved (a sideways row of
/// flyers), then rows for the events the viewer hosts and for past events. Nothing at all:
/// the empty state with the grey logo mark.
///
/// With tickets (BACKEND_CHANGES B22) the card shows the count and Show tickets opens them
/// (`EvTicket`); an RSVP has neither, so its button says View event and opens the event. Scanning a piece's code at an event sits in the
/// header's right slot; hosting moved to "Events you host".
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key, this.debugGoing, this.debugSaved, this.debugHosting, this.debugNow});

  /// For tests: the three lists and the clock.
  @visibleForTesting
  final List<StudioEvent>? debugGoing;
  @visibleForTesting
  final List<StudioEvent>? debugSaved;
  @visibleForTesting
  final List<StudioEvent>? debugHosting;
  @visibleForTesting
  final DateTime? debugNow;

  static void open(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const MyEventsPage()));
  }

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  List<StudioEvent>? _going;
  List<StudioEvent> _saved = const [];
  List<StudioEvent> _hosting = const [];
  bool _failed = false;

  bool get _debug => widget.debugGoing != null;
  DateTime get _now => widget.debugNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    if (_debug) {
      _going = widget.debugGoing;
      _saved = widget.debugSaved ?? const [];
      _hosting = widget.debugHosting ?? const [];
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (_debug) return;
    final service = EventService.instance;
    // Saved and hosting failing should not hide the events the viewer is going to.
    Future<List<StudioEvent>> orEmpty(Future<List<StudioEvent>> f) => f.catchError((_) => <StudioEvent>[]);
    try {
      final results = await Future.wait([
        service.list(scope: 'going'),
        orEmpty(service.list(scope: 'saved')),
        orEmpty(service.list(scope: 'hosting')),
      ]);
      if (!mounted) return;
      setState(() {
        _going = results[0];
        _saved = results[1];
        _hosting = results[2];
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(StudioEvent event) async {
    await openEventDetail(context, event);
    _load();
  }

  /// An event with tickets opens them (`EvTicket`); an RSVP opens the event.
  Future<void> _openGoing(StudioEvent event) async {
    if (event.ticketCount > 0) {
      await EventTicketPage.open(context, event);
    } else {
      await _open(event);
    }
  }

  static String? _ticketCount(StudioEvent e) =>
      e.ticketCount <= 0 ? null : (e.ticketCount == 1 ? '1 ticket' : '${e.ticketCount} tickets');

  void _openPast(List<StudioEvent> past) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventListPage(
          title: 'Past events',
          newestFirst: true,
          debugNow: widget.debugNow,
          load: () async => _debug
              ? past
              : (await EventService.instance.list(scope: 'going')).where((e) => e.isOver).toList(),
        ),
      ),
    );
  }

  Future<void> _openHosting() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => HostedEventsPage(debugEvents: _debug ? _hosting : null)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final going = _going;
    final now = _now;
    Widget body;
    if (going == null) {
      body = _failed
          ? Center(
              child: StudioEmptyState(
                title: "Your events didn't load",
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          : Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
              ),
            );
    } else {
      bool ahead(StudioEvent e) => !e.isOver && !e.isCancelled;
      final upcoming = going.where(ahead).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final past = going.where((e) => e.isOver).toList();
      final goingIds = {for (final e in going) e.id};
      // Saved: bookmarked but not going; gone once it ends.
      final saved = _saved.where((e) => ahead(e) && !goingIds.contains(e.id)).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (upcoming.isEmpty && saved.isEmpty && past.isEmpty && _hosting.isEmpty) {
        body = Center(
          child: StudioEmptyState(
            title: 'No events yet',
            message: 'Events you get tickets for or save show up here.',
            actionLabel: 'Browse events',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        );
      } else {
        final children = <Widget>[];
        if (upcoming.isNotEmpty) {
          children.add(const YourEventsLabel('Upcoming'));
          children.add(
            NextEventCard(
              event: upcoming.first,
              now: now,
              detail: _ticketCount(upcoming.first),
              buttonLabel: upcoming.first.ticketCount > 0 ? 'Show tickets' : 'View event',
              onTap: () => _openGoing(upcoming.first),
            ),
          );
          for (var i = 1; i < upcoming.length; i++) {
            if (i == 1) children.add(const SizedBox(height: 14));
            final e = upcoming[i];
            children.add(
              YourEventRow(
                event: e,
                line: [e.venue, ?_ticketCount(e)].where((p) => p.isNotEmpty).join(' · '),
                first: i == 1,
                onTap: () => _openGoing(e),
              ),
            );
          }
        }
        if (saved.isNotEmpty) {
          children.add(const YourEventsLabel('Saved'));
          children.add(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < saved.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SavedEventCard(event: saved[i], onTap: () => _open(saved[i])),
                  ],
                ],
              ),
            ),
          );
        }
        if (_hosting.isNotEmpty) {
          children.add(const SizedBox(height: 30));
          children.add(
            YourEventsLinkRow(label: 'Events you host', detail: '${_hosting.length}', onTap: _openHosting),
          );
        }
        if (past.isNotEmpty) {
          children.add(SizedBox(height: _hosting.isNotEmpty ? 0 : 30));
          children.add(YourEventsLinkRow(label: 'Past events', onTap: () => _openPast(past)));
        }
        body = RefreshIndicator(
          color: c.textPrimary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 8, 24, 40 + MediaQuery.paddingOf(context).bottom),
            children: children,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Your events',
        actions: [
          // Scanning the code beside a piece at an event (the Events tab header leaves it out).
          IconButton(
            onPressed: () => ScanQrPage.open(context),
            tooltip: 'Scan a code',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: StudioIcon(StudioIcons.scan, size: 22, color: c.textPrimary),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Events you host (no board; `EvMyTickets` row style): drafts, published and cancelled, newest
/// first, each with its state or headcount; + hosts another; ··· deletes.
class HostedEventsPage extends StatefulWidget {
  const HostedEventsPage({super.key, this.debugEvents});

  @visibleForTesting
  final List<StudioEvent>? debugEvents;

  @override
  State<HostedEventsPage> createState() => _HostedEventsPageState();
}

class _HostedEventsPageState extends State<HostedEventsPage> {
  List<StudioEvent>? _events;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _events = widget.debugEvents;
    if (_events == null) _load();
  }

  Future<void> _load() async {
    if (widget.debugEvents != null) return;
    try {
      final events = await EventService.instance.list(scope: 'hosting');
      if (!mounted) return;
      setState(() {
        _events = events;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _host() async {
    await HostEventPage.open(context);
    _load();
  }

  /// A draft goes back into the hosting steps; anything else opens Manage event.
  Future<void> _open(StudioEvent event) async {
    if (event.isDraft) {
      await HostEventPage.open(context, editing: event);
    } else {
      await HostManagePage.open(context, event);
    }
    _load();
  }

  Future<void> _delete(StudioEvent event) async {
    final confirmed = await showDeleteConfirmationDialog(context, itemLabel: 'event');
    if (confirmed != true || !mounted) return;
    final previous = _events;
    setState(() => _events = _events?.where((e) => e.id != event.id).toList());
    try {
      await EventService.instance.delete(event.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _events = previous);
      showStudioToast(context, e is ApiException ? e.message : 'Could not delete the event.', icon: null);
    }
  }

  void _menu(StudioEvent event) {
    showStudioSheet<void>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          StudioActionRow(
            icon: StudioIcons.deleteFolder,
            title: 'Delete event',
            subtitle: event.isDraft ? null : 'Guests are told it is off',
            onTap: () {
              Navigator.pop(sheetContext);
              _delete(event);
            },
          ),
        ],
      ),
    );
  }

  String _line(StudioEvent e) {
    if (e.isDraft) return 'Draft';
    if (e.isCancelled) return 'Cancelled';
    final going = e.rsvpCount == 1 ? '1 going' : '${e.rsvpCount} going';
    return [e.venue, going].where((p) => p.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final events = _events;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Events you host',
        actions: [
          IconButton(
            onPressed: _host,
            tooltip: 'Host an event',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: StudioIcon(StudioIcons.plus, size: 22, color: c.textPrimary),
          ),
        ],
      ),
      body: events == null
          ? Center(
              child: _failed
                  ? StudioEmptyState(title: "Your events didn't load", actionLabel: 'Try again', onAction: _load)
                  : SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                    ),
            )
          : events.isEmpty
          ? Center(
              child: StudioEmptyState(
                title: "You haven't hosted an event yet",
                actionLabel: 'Host an event',
                onAction: _host,
              ),
            )
          : RefreshIndicator(
              color: c.textPrimary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  for (var i = 0; i < events.length; i++)
                    YourEventRow(
                      event: events[i],
                      line: _line(events[i]),
                      first: i == 0,
                      onTap: () => _open(events[i]),
                      trailing: Semantics(
                        button: true,
                        label: 'More',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => _menu(events[i]),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox.square(
                            dimension: 44,
                            child: Center(child: StudioIcon(StudioIcons.more, size: 20, color: c.textTertiary)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import 'event_detail_page.dart';
import 'event_post_page.dart';

/// The viewer's own relationship to events — what they host, and what they've registered
/// for — as opposed to the Events tab's browse, or Saved's bookmarks of other people's.
///
/// Two tabs rather than two screens: a host is very often also a guest at somebody else's
/// event, and switching between "mine" and "I'm going to" is a tab flick, not a navigation.
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MyEventsPage()),
    );
  }

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _hostingKey = GlobalKey<_EventScopeListState>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _hostEvent() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const EventPostPage()),
    );
    // Publishing (or saving a draft) happens on that flow's own screens, well after this
    // future resolves on the first pop — reload regardless of what actually happened rather
    // than trying to thread a "something changed" signal back through several screens.
    _hostingKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: HomeFeedTokens.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'My events',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: HomeFeedTokens.textPrimary),
                    tooltip: 'Host an event',
                    onPressed: _hostEvent,
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: HomeFeedTokens.textPrimary,
              unselectedLabelColor: HomeFeedTokens.textSecondary,
              indicatorColor: HomeFeedTokens.textPrimary,
              labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
              tabs: const [
                Tab(text: 'My events'),
                Tab(text: 'Registered'),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFE5E1D8)),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _EventScopeList(key: _hostingKey, scope: 'hosting'),
                  const _EventScopeList(scope: 'going'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventScopeList extends StatefulWidget {
  const _EventScopeList({super.key, required this.scope});

  /// `hosting` or `going` — the two scopes [EventService.list] understands for this page.
  final String scope;

  @override
  State<_EventScopeList> createState() => _EventScopeListState();
}

class _EventScopeListState extends State<_EventScopeList>
    with AutomaticKeepAliveClientMixin {
  List<StudioEvent>? _events;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _error = null);
    try {
      final events = await EventService.instance.list(scope: widget.scope);
      if (!mounted) return;
      setState(() => _events = events);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load your events.");
    }
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
      final message = e is ApiException ? e.message : 'Failed to delete event';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final events = _events;

    if (events == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && events == null) {
      return _EmptyState(
        message: _error!,
        actionLabel: 'Retry',
        onAction: reload,
      );
    }
    if (events!.isEmpty) {
      return _EmptyState(
        message: widget.scope == 'hosting'
            ? "You haven't hosted an event yet"
            : "You haven't registered for an event yet",
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventRow(
            event: event,
            showParticipantCount: widget.scope == 'hosting',
            // Awaited so a cancelled RSVP or a deleted event on the detail page is reflected
            // here the moment the viewer is back, rather than on this list's next visit.
            onTap: () async {
              await openEventDetail(context, event);
              if (mounted) reload();
            },
            onDelete: widget.scope == 'hosting' ? () => _delete(event) : null,
          );
        },
      ),
    );
  }
}

/// One event, one row: cover on the left, everything else to its right — the same shape as
/// every other list in the app (Saved, a profile grid's list mode), rather than the card
/// grids the Events tab itself uses.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.showParticipantCount,
    required this.onTap,
    this.onDelete,
  });

  final StudioEvent event;

  /// True on "My events" — the number the host actually opened this list to see. False on
  /// "Registered", where the viewer is one of that number, not the person counting it.
  final bool showParticipantCount;

  final VoidCallback onTap;
  final VoidCallback? onDelete;

  void _showActions(BuildContext context) {
    final delete = onDelete;
    if (delete == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE05252)),
              title: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFE05252),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E1D8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: event.imageUrl.isNotEmpty
                      ? FeedPicsumImage(url: event.imageUrl)
                      : ColoredBox(
                          color: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
                          child: const Icon(
                            Icons.event_outlined,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (event.isDraft) ...[
                          const _Tag(label: 'Draft', color: Color(0xFF8A6D00)),
                          const SizedBox(width: 6),
                        ] else if (event.status == 'cancelled') ...[
                          const _Tag(label: 'Cancelled', color: Color(0xFFB3261E)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.venue.isEmpty
                          ? event.whenLabel
                          : '${event.venue} · ${event.whenLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showParticipantCount)
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: HomeFeedTokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.rsvpCount == 1
                                ? '1 registered'
                                : '${event.rsvpCount} registered',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                        ],
                      )
                    else if (event.viewerIsGoing)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF2E8B57),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "You're going",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E8B57),
                            ),
                          ),
                          // Ticket download belongs here once paid entry exists — [isFree]
                          // is always true today, so there is never a ticket to fetch yet.
                        ],
                      ),
                  ],
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: () => _showActions(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                    child: Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

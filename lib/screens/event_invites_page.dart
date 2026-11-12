import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/offline_state.dart';
import '../widgets/studio/studio.dart';
import 'event_detail_page.dart';
import 'event_piece_request_page.dart';

/// Event invites (Phase 5, decision D4), opened from the row at the top of Activity, laid out
/// like Follow requests: invites to co-host or be a featured artist, each with Decline / Accept
/// and opening the event; then Piece requests, hosts asking to show, sell or auction the
/// viewer's work, each opening the request.
class EventInvitesPage extends StatefulWidget {
  const EventInvitesPage({super.key, this.debugInvites, this.debugRequests});

  /// For tests: the lists instead of loading them.
  @visibleForTesting
  final List<EventInviteRequest>? debugInvites;
  @visibleForTesting
  final List<EventPieceRequest>? debugRequests;

  @override
  State<EventInvitesPage> createState() => _EventInvitesPageState();
}

class _EventInvitesPageState extends State<EventInvitesPage> {
  List<EventInviteRequest> _invites = [];
  List<EventPieceRequest> _requests = [];
  bool _loading = true;
  bool _offline = false;
  final Set<String> _busy = {};

  bool get _debug => widget.debugInvites != null || widget.debugRequests != null;

  @override
  void initState() {
    super.initState();
    if (_debug) {
      _invites = List.of(widget.debugInvites ?? const []);
      _requests = List.of(widget.debugRequests ?? const []);
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (_debug) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        EventService.instance.myEventInvites(),
        EventService.instance.myPieceRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _invites = results[0] as List<EventInviteRequest>;
        _requests = results[1] as List<EventPieceRequest>;
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = _invites.isEmpty && _requests.isEmpty;
      });
    }
  }

  String _key(EventInviteRequest i) => '${i.event.id}:${i.role}';

  Future<void> _answer(EventInviteRequest invite, {required bool accept}) async {
    final key = _key(invite);
    setState(() => _busy.add(key));
    try {
      if (accept) {
        await EventService.instance.acceptInvite(invite.event.id, role: invite.role);
      } else {
        await EventService.instance.declineInvite(invite.event.id, role: invite.role);
      }
      if (!mounted) return;
      if (accept) showStudioToast(context, "You're on ${invite.event.title}");
      setState(() => _invites.removeWhere((i) => _key(i) == key));
    } on ApiException catch (e) {
      if (!mounted) return;
      showStudioToast(context, e.message, icon: null);
      if (e.statusCode == 404) setState(() => _invites.removeWhere((i) => _key(i) == key));
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not answer the invite. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _openEvent(StudioEvent event) async {
    await openEventDetail(context, event);
    await _load();
  }

  Future<void> _openRequest(EventPieceRequest request) async {
    final answered = await EventPieceRequestPage.open(context, request);
    if (!mounted) return;
    if (answered) {
      setState(() => _requests.removeWhere((r) => r.item.id == request.item.id));
    }
    await _load();
  }

  static String _mode(String mode) => switch (mode) {
    'sale' => 'For sale',
    'bid' => 'Auction',
    _ => 'On show',
  };

  Widget _label(StudioColors c, String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: StudioType.mono(11, weight: StudioType.medium, color: c.textTertiary).copyWith(letterSpacing: 0.5),
    ),
  );

  Widget _row(
    StudioColors c, {
    required String? imageUrl,
    required String title,
    required String line,
    required VoidCallback onTap,
    required Widget trailing,
  }) {
    final url = imageUrl ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 53,
                        child: url.isEmpty
                            ? ColoredBox(color: c.surface)
                            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: c.surface)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.caption12(color: c.textSecondary),
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
          trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final empty = _invites.isEmpty && _requests.isEmpty;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Event invites'),
      body: _offline
          ? OfflineState(onRetry: _load)
          : _loading && empty
          ? const FlatListRowSkeleton()
          : RefreshIndicator(
              color: c.textPrimary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, empty ? 200 : 0, 20, 24),
                children: [
                  if (empty)
                    const StudioEmptyState(
                      title: 'No invites',
                      message: 'When a host asks you onto an event or wants to show your work, it shows up here.',
                    ),
                  if (_invites.isNotEmpty) ...[
                    _label(c, 'Invites'),
                    for (final invite in _invites)
                      _row(
                        c,
                        imageUrl: invite.event.coverMediaUrl,
                        title: invite.event.title,
                        line: '${invite.roleLabel} · ${invite.event.whenLabel}',
                        onTap: () => _openEvent(invite.event),
                        trailing: AcceptDeclineButtons(
                          busy: _busy.contains(_key(invite)),
                          onAccept: () => _answer(invite, accept: true),
                          onDecline: () => _answer(invite, accept: false),
                        ),
                      ),
                  ],
                  if (_requests.isNotEmpty) ...[
                    _label(c, 'Piece requests'),
                    for (final request in _requests)
                      _row(
                        c,
                        imageUrl: request.item.mediaUrl,
                        title: request.item.title ?? 'Untitled',
                        line: '${_mode(request.item.mode)} at ${request.event.title}',
                        onTap: () => _openRequest(request),
                        trailing: StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

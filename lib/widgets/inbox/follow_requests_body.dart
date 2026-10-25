import 'package:flutter/material.dart';

import '../../models/follow_request.dart';
import '../../services/social_service.dart';
import '../../utils/profile_navigation.dart';
import '../accept_decline_buttons.dart';
import '../feed_skeleton.dart';
import '../offline_state.dart';
import '../studio/studio.dart';
import 'notifications_body.dart' show activityTime;

/// The Inbox "Requests" tab: people asking to follow a private profile. No board of its
/// own: rows like Activity (40 avatar, name 15/500, "@handle · 4h" 12 Graphite, 12 above
/// and below, 1 px Line) with the small Decline / Accept pair; the `SavedEmpty` empty state.
class FollowRequestsBody extends StatefulWidget {
  const FollowRequestsBody({super.key, this.debugRequests});

  /// For tests: the requests instead of loading them.
  @visibleForTesting
  final List<FollowRequest>? debugRequests;

  @override
  State<FollowRequestsBody> createState() => FollowRequestsBodyState();
}

class FollowRequestsBodyState extends State<FollowRequestsBody> {
  List<FollowRequest> _requests = [];
  bool _loading = true;
  bool _showOfflineState = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    final debug = widget.debugRequests;
    if (debug != null) {
      _requests = List.of(debug);
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.debugRequests != null) return;
    setState(() => _loading = true);
    try {
      final requests = await SocialService.instance.listFollowRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
        _showOfflineState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _showOfflineState = _requests.isEmpty;
      });
    }
  }

  Future<void> _accept(FollowRequest request) async {
    setState(() => _busy.add(request.username));
    try {
      await SocialService.instance.acceptFollowRequest(request.username);
      if (!mounted) return;
      showStudioToast(context, '${request.name.isEmpty ? '@${request.username}' : request.name} can follow you now');
      setState(
        () => _requests.removeWhere((r) => r.username == request.username),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _requests.removeWhere((r) => r.username == request.username),
      );
      showStudioToast(context, 'This request is no longer available', icon: null);
    } finally {
      if (mounted) setState(() => _busy.remove(request.username));
    }
  }

  Future<void> _decline(FollowRequest request) async {
    setState(() => _busy.add(request.username));
    try {
      await SocialService.instance.declineFollowRequest(request.username);
    } catch (_) {
      // Treat as handled either way — remove locally.
    } finally {
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r.username == request.username);
          _busy.remove(request.username);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    if (_showOfflineState) {
      return OfflineState(onRetry: _load);
    }
    if (_loading && _requests.isEmpty) {
      return const FlatListRowSkeleton();
    }
    return RefreshIndicator(
      color: c.textPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, _requests.isEmpty ? 200 : 4, 20, 24),
        children: [
          if (_requests.isEmpty)
            const StudioEmptyState(
              title: 'No follow requests',
              message: 'When your profile is private, people who ask to follow you show up here.',
            ),
          for (final request in _requests)
            FollowRequestRow(
              request: request,
              busy: _busy.contains(request.username),
              onAccept: () => _accept(request),
              onDecline: () => _decline(request),
            ),
        ],
      ),
    );
  }
}

/// 40 avatar and name open the profile; Decline / Accept on the right.
class FollowRequestRow extends StatelessWidget {
  const FollowRequestRow({
    super.key,
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FollowRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final name = request.name.isEmpty ? request.username : request.name;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => openUserProfile(context, request.username),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    StudioAvatar(url: request.profilePhotoUrl, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(
                              15,
                              weight: StudioType.medium,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${request.username} · '
                            '${activityTime(request.requestedAt, DateTime.now())}',
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
          AcceptDeclineButtons(onAccept: onAccept, onDecline: onDecline, busy: busy),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/follow_request.dart';
import '../../services/social_service.dart';
import '../../utils/profile_navigation.dart';
import '../accept_decline_buttons.dart';
import '../feed_skeleton.dart';
import '../offline_state.dart';
import '../studio/studio.dart';
import '../../utils/app_clock.dart';
import 'notifications_body.dart' show activityTime;

/// The Inbox "Requests" tab: people asking to follow a private profile. No board of its
/// own: rows like Activity (40 avatar, name 15/500, "@handle · 4h" 12 Graphite, 12 above
/// and below, 1 px Line) with the small Decline / Accept pair; the `SavedEmpty` empty state.
///
/// With [settings], the Settings › Privacy › Follow requests page (`SettingsFollowRequests`):
/// 44 avatars, the age in Mono ("2h", "1d"), Approve then Decline, and under the rows "They
/// aren't told if you decline." Newest first either way.
class FollowRequestsBody extends StatefulWidget {
  const FollowRequestsBody({super.key, this.debugRequests, this.settings = false});

  /// The Settings page's look (`SettingsFollowRequests`).
  final bool settings;

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
      _requests = _newestFirst(debug);
      _loading = false;
      return;
    }
    _load();
  }

  static List<FollowRequest> _newestFirst(List<FollowRequest> requests) =>
      List.of(requests)..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

  Future<void> _load() async {
    if (widget.debugRequests != null) return;
    setState(() => _loading = true);
    try {
      final requests = await SocialService.instance.listFollowRequests();
      if (!mounted) return;
      setState(() {
        _requests = _newestFirst(requests);
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
              settings: widget.settings,
              onAccept: () => _accept(request),
              onDecline: () => _decline(request),
            ),
          if (widget.settings && _requests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                "They aren't told if you decline.",
                style: StudioType.caption12(color: c.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// 40 avatar and name open the profile; Decline / Accept on the right. With [settings]
/// (`SettingsFollowRequests`): a 44 avatar, the age in Mono, Approve then Decline.
class FollowRequestRow extends StatelessWidget {
  const FollowRequestRow({
    super.key,
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    this.settings = false,
  });

  final FollowRequest request;
  final bool busy;
  final bool settings;
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
                    StudioAvatar(url: request.profilePhotoUrl, size: settings ? 44 : 40),
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
                          if (settings)
                            Text.rich(
                              TextSpan(
                                text: '@${request.username} · ',
                                children: [
                                  TextSpan(
                                    text: requestAge(request.requestedAt, appNow()),
                                    style: StudioType.mono(12, color: c.textSecondary),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: StudioType.caption12(color: c.textSecondary),
                            )
                          else
                            Text(
                              '@${request.username} · '
                              '${activityTime(request.requestedAt, appNow())}',
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
          if (settings)
            _ApproveDecline(onApprove: onAccept, onDecline: onDecline, busy: busy)
          else
            AcceptDeclineButtons(onAccept: onAccept, onDecline: onDecline, busy: busy),
        ],
      ),
    );
  }
}

/// Approve (Ink) then Decline (outlined), small, 12 apart (`SettingsFollowRequests`). The
/// small buttons keep their 16 sides (the board has 14 and 12).
class _ApproveDecline extends StatelessWidget {
  const _ApproveDecline({required this.onApprove, required this.onDecline, required this.busy});

  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox.square(
        dimension: 34,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.studio.textPrimary),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioButton(label: 'Approve', variant: StudioButtonVariant.small, filled: true, onPressed: onApprove),
        const SizedBox(width: 12),
        StudioButton(label: 'Decline', variant: StudioButtonVariant.small, onPressed: onDecline),
      ],
    );
  }
}

/// How long ago a request came: "now", "12m", "2h", "1d", "3w".
String requestAge(DateTime at, DateTime now) {
  final diff = now.difference(at.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${diff.inDays ~/ 7}w';
}

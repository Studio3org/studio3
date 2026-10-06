import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/follow_request.dart';
import '../../services/social_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/profile_navigation.dart';
import '../accept_decline_buttons.dart';
import '../feed_skeleton.dart';
import '../glass_card.dart';
import '../home_feed/home_feed_widgets.dart';
import '../offline_state.dart';

/// Follow-requests list content for the Inbox page's "Requests" tab —
/// extracted from the former standalone FollowRequestsPage, minus its own
/// AppBar.
class FollowRequestsBody extends StatefulWidget {
  const FollowRequestsBody({super.key});

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
    _load();
  }

  Future<void> _load() async {
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
      setState(
        () => _requests.removeWhere((r) => r.username == request.username),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _requests.removeWhere((r) => r.username == request.username),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This request is no longer available')),
      );
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
    if (_showOfflineState) {
      return OfflineState(onRetry: _load);
    }
    if (_loading && _requests.isEmpty) {
      return const FlatListRowSkeleton();
    }
    if (_requests.isEmpty) {
      return Center(
        child: Text(
          'No pending requests',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FollowRequestRow(
              request: request,
              busy: _busy.contains(request.username),
              onAccept: () => _accept(request),
              onDecline: () => _decline(request),
            ),
          );
        },
      ),
    );
  }
}

class _FollowRequestRow extends StatelessWidget {
  const _FollowRequestRow({
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
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => openUserProfile(context, request.username),
            child: UserAvatar(
              url: request.profilePhotoUrl,
              name: request.name,
              size: 40,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${request.username} · requested ${_timeAgo(request.requestedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AcceptDeclineButtons(
            onAccept: onAccept,
            onDecline: onDecline,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

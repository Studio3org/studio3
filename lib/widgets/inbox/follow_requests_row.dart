import 'package:flutter/material.dart';

import '../../models/follow_request.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_icon.dart';

/// The first row of the Inbox's Activity when people are waiting to follow a private account
/// (the user's call, 2026-11-08, as on Instagram; there is no Requests tab): the newest
/// requester's photo (40) with a bubble counting everyone waiting, "Follow requests" (15/500)
/// over "@newest + N others" (13 grey), and a chevron. Tapping it opens the list
/// (`FollowRequestsPage`). Laid out like an Activity row: 12 above and below, a 1 px Line
/// under. [requests] is newest first and never empty (the caller leaves the row out).
class FollowRequestsRow extends StatelessWidget {
  const FollowRequestsRow({super.key, required this.requests, required this.onTap});

  final List<FollowRequest> requests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final newest = requests.first;
    final count = requests.length;
    final others = count - 1;
    final who = '@${newest.username}';
    final line = others == 0 ? who : '$who + $others ${others == 1 ? 'other' : 'others'}';
    return InboxCountRow(
      rowKey: const Key('inbox-follow-requests'),
      countKey: const Key('inbox-follow-requests-count'),
      title: 'Follow requests',
      line: line,
      imageUrl: newest.profilePhotoUrl,
      count: count,
      onTap: onTap,
    );
  }
}

/// The Follow requests row's look, shared with Event invites (Phase 5, decision D4): a 40 photo
/// with a count bubble, the title 15/500 over a 13 grey line, and a chevron.
class InboxCountRow extends StatelessWidget {
  const InboxCountRow({
    super.key,
    required this.title,
    required this.line,
    required this.count,
    required this.onTap,
    this.imageUrl,
    this.rowKey,
    this.countKey,
  });

  final String title;
  final String line;
  final int count;
  final String? imageUrl;
  final VoidCallback onTap;
  final Key? rowKey;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: '$title, $count',
      excludeSemantics: true,
      child: GestureDetector(
        key: rowKey,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: StudioAvatar(url: imageUrl, size: 40),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _CountBubble(count: count, bubbleKey: countKey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count over the photo: Ink with the page color's Mono figure, 18 tall, a 2 px page-colored
/// ring so it reads against the photo; "99+" past 99.
class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, this.bubbleKey});

  final int count;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      key: bubbleKey,
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: c.textPrimary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: StudioType.mono(11, weight: StudioType.medium, color: c.background),
      ),
    );
  }
}

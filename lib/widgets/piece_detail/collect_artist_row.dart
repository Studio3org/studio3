import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../services/auth_session.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';
import '../../utils/profile_navigation.dart';
import '../follow_button.dart';
import '../home_feed/home_feed_widgets.dart';

/// Artist row (Figma 2707:3557) — px 10, py 16, avatar 28, Follow 96×28.
class CollectArtistRow extends StatelessWidget {
  const CollectArtistRow({
    super.key,
    required this.item,
    required this.followState,
    this.followBusy = false,
    required this.onFollowToggle,
  });

  final FeedPreviewItem item;
  final FollowState followState;
  final bool followBusy;
  final VoidCallback onFollowToggle;

  @override
  Widget build(BuildContext context) {
    final viewer = AuthSession.instance.user?.username.toLowerCase();
    final handle = item.handle.startsWith('@')
        ? item.handle.substring(1).toLowerCase()
        : item.handle.toLowerCase();
    final showFollow = viewer == null || viewer != handle;
    final displayHandle = item.handle.startsWith('@')
        ? item.handle
        : '@${item.handle}';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CollectDetailTokens.hairline, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => openUserProfile(context, item.handle),
              behavior: HitTestBehavior.opaque,
              child: UserAvatar(
                url: item.displayAvatarUrl,
                name: item.displayName,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => openUserProfile(context, item.handle),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 16,
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PieceDetailType.artistName,
                          strutStyle: PieceDetailType.artistNameStrut,
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        height: 14,
                        child: Text(
                          displayHandle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PieceDetailType.artistHandle,
                          strutStyle: PieceDetailType.artistHandleStrut,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showFollow)
              FollowButton(
                state: followState,
                onPressed: onFollowToggle,
                figmaDetail: true,
                busy: followBusy,
              ),
          ],
        ),
      ),
    );
  }
}

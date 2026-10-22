import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../../utils/profile_navigation.dart';
import '../follow_button.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_button.dart';

/// Artist row under the piece image (`BuyPiece`): 36 avatar, 10 gap, name 14/500 over
/// handle 12, and the small Follow (34, radius 8) only; 12 20 padding and a 1 px Line
/// under the row. The board draws Follow as an outline; it keeps the app's follow
/// convention instead (filled Follow, outline Unfollow / Requested; section 0.3).
/// On your own piece, "Your piece" (13 Graphite) replaces Follow (`ListOwnerPiece`).
class CollectArtistRow extends StatelessWidget {
  const CollectArtistRow({
    super.key,
    required this.item,
    required this.followState,
    this.followBusy = false,
    required this.onFollowToggle,
    this.isOwner = false,
  });

  final FeedPreviewItem item;
  final FollowState followState;
  final bool followBusy;
  final VoidCallback onFollowToggle;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => openUserProfile(context, item.handle),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  StudioAvatar(
                    url: item.displayAvatarUrl,
                    size: 36,
                    semanticLabel: item.displayName,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                        ),
                        Text(
                          item.handle,
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
          const SizedBox(width: 12),
          if (isOwner)
            Text('Your piece', style: StudioType.label13(color: c.textSecondary))
          else
            StudioButton(
              label: followState.actionLabel,
              variant: StudioButtonVariant.small,
              filled: followState.filled,
              loading: followBusy,
              onPressed: followBusy ? null : onFollowToggle,
            ),
        ],
      ),
    );
  }
}

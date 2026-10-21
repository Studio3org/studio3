import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../../services/auth_session.dart';
import '../../services/social_service.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../follow_button.dart';
import '../profile_avatar.dart';
import '../studio/studio_icon.dart';

/// Instagram-style "expand caption" popup for a reel: full caption text plus
/// a persistent comment box, over a dark scrim matching the reel screen
/// itself (unlike [PieceCommentSheet]'s light theme).
class ReelDescriptionSheet extends StatefulWidget {
  const ReelDescriptionSheet({
    super.key,
    required this.item,
    required this.followState,
    this.followBusy = false,
    required this.onFollowToggle,
    required this.onCommentPosted,
    required this.scrollController,
  });

  final FeedItem item;
  final FollowState followState;
  final bool followBusy;
  final VoidCallback onFollowToggle;
  final VoidCallback onCommentPosted;
  final ScrollController scrollController;

  static Future<void> show(
    BuildContext context, {
    required FeedItem item,
    required FollowState followState,
    bool followBusy = false,
    required VoidCallback onFollowToggle,
    required VoidCallback onCommentPosted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StudioColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ReelDescriptionSheet(
          item: item,
          followState: followState,
          followBusy: followBusy,
          onFollowToggle: onFollowToggle,
          onCommentPosted: onCommentPosted,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<ReelDescriptionSheet> createState() => _ReelDescriptionSheetState();
}

class _ReelDescriptionSheetState extends State<ReelDescriptionSheet> {
  final _textController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final postId = widget.item.post?.id;
    final body = _textController.text.trim();
    if (postId == null || body.isEmpty || _sending) return;
    if (!await requireLogin(context)) return;
    setState(() => _sending = true);
    try {
      await SocialService.instance.commentOnPost(postId, body);
      if (!mounted) return;
      _textController.clear();
      widget.onCommentPosted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post comment: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final authorName = item.authorName ?? 'Artist';
    final authorUsername = item.authorUsername;
    final caption = item.post?.caption ?? item.title ?? '';

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: StudioColors.galleryWhite.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: authorUsername != null
                      ? () => openUserProfile(context, authorUsername)
                      : null,
                  behavior: authorUsername != null
                      ? HitTestBehavior.opaque
                      : HitTestBehavior.deferToChild,
                  child: ProfileAvatar(url: item.authorAvatarUrl, size: 36),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: authorUsername != null
                        ? () => openUserProfile(context, authorUsername)
                        : null,
                    behavior: authorUsername != null
                        ? HitTestBehavior.opaque
                        : HitTestBehavior.deferToChild,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.body14(
                            weight: StudioType.medium,
                            color: StudioColors.galleryWhite,
                          ),
                        ),
                        if (authorUsername != null &&
                            authorUsername.isNotEmpty)
                          Text(
                            '@$authorUsername',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.caption12(
                              color: StudioColors.galleryWhite.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (authorUsername != null && authorUsername.isNotEmpty)
                  FollowButton(
                    state: widget.followState,
                    onPressed: widget.onFollowToggle,
                    dense: true,
                    busy: widget.followBusy,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x3DFAFAF8)),
          Expanded(
            child: caption.trim().isEmpty
                ? Center(
                    child: Text(
                      'No description',
                      style: StudioType.label13(
                        color: StudioColors.onDarkSecondary,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Text(
                      caption,
                      style: StudioType.label13(
                        color: StudioColors.galleryWhite.withValues(alpha: 0.92),
                      ).copyWith(height: 1.4),
                    ),
                  ),
          ),
          const Divider(height: 1, color: Color(0x3DFAFAF8)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              // Guests can read the caption but tapping to comment asks them
              // to log in instead of opening the keyboard.
              readOnly: !AuthSession.instance.isLoggedIn,
              onTap: AuthSession.instance.isLoggedIn
                  ? null
                  : () => requireLogin(
                        context,
                        title: 'Sign in to comment',
                        message: 'Log in or create a free account to comment.',
                      ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: StudioType.body14(color: StudioColors.galleryWhite),
              cursorColor: StudioColors.galleryWhite,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: StudioType.body14(
                  color: StudioColors.galleryWhite.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: StudioColors.galleryWhite.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: StudioColors.galleryWhite,
                    ),
                  )
                : const StudioIcon(
                    StudioIcons.send,
                    size: 22,
                    color: StudioColors.galleryWhite,
                  ),
            color: StudioColors.galleryWhite,
          ),
        ],
      ),
    );
  }
}

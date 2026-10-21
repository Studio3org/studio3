import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../../services/engagement_store.dart';
import '../../services/saved_content_store.dart';
import '../../services/report_service.dart';
import '../../services/social_service.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../content_actions_sheet.dart';
import '../collection_saved_toast.dart';
import '../follow_button.dart';
import '../piece_detail/detail_follow_state.dart';
import '../profile_avatar.dart';
import '../save_to_collection_sheet.dart';
import '../studio/studio_icon.dart';
import 'reel_description_sheet.dart';
import 'scene_video_comment_sheet.dart';

class ReelOverlay extends StatefulWidget {
  const ReelOverlay({
    super.key,
    required this.item,
    this.bottomPadding = 96,
    required this.muted,
    required this.onToggleMute,
  });

  final FeedItem item;
  final double bottomPadding;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  State<ReelOverlay> createState() => ReelOverlayState();
}

class ReelOverlayState extends State<ReelOverlay>
    with DetailFollowState<ReelOverlay> {
  late bool _liked;
  late bool _saved;
  late int _likeCount;
  int _commentCount = 0;
  bool _likeBusy = false;
  bool _saveBusy = false;
  int _likeGeneration = 0;
  int _saveGeneration = 0;

  EngagementStore get _engagement => EngagementStore.instance;

  @override
  String get followUsername => widget.item.authorUsername ?? '';

  @override
  void initState() {
    super.initState();
    _syncFromItem();
    _engagement.addListener(_onEngagementChanged);
    SavedContentStore.instance.addListener(_onEngagementChanged);
  }

  @override
  void didUpdateWidget(covariant ReelOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _syncFromItem();
    }
  }

  @override
  void dispose() {
    _engagement.removeListener(_onEngagementChanged);
    SavedContentStore.instance.removeListener(_onEngagementChanged);
    super.dispose();
  }

  void _syncFromItem() {
    final post = widget.item.post;
    final postId = post?.id;
    _liked = postId != null
        ? _engagement.resolveLiked(postId, post?.isLiked ?? false)
        : false;
    _saved = postId != null
        ? _engagement.resolveSaved(
            postId,
            SavedContentStore.instance.isSaved(postId) ||
                (post?.isSaved ?? false),
          )
        : false;
    _likeCount = post?.likeCount ?? 0;
    _commentCount = 0;
    followState = widget.item.authorIsFollowing
        ? FollowState.following
        : FollowState.none;
  }

  void _onEngagementChanged() {
    if (!mounted || _likeBusy || _saveBusy) return;
    final postId = widget.item.post?.id;
    if (postId == null) return;
    final nextLiked = _engagement.resolveLiked(
      postId,
      widget.item.post?.isLiked ?? false,
    );
    final nextSaved = _engagement.resolveSaved(
      postId,
      SavedContentStore.instance.isSaved(postId) ||
          (widget.item.post?.isSaved ?? false),
    );
    if (nextLiked != _liked || nextSaved != _saved) {
      setState(() {
        if (nextLiked != _liked) {
          _likeCount += nextLiked ? 1 : -1;
          if (_likeCount < 0) _likeCount = 0;
          _liked = nextLiked;
        }
        _saved = nextSaved;
      });
    }
  }

  /// Double-tap like — no-op if already liked or a request is in flight.
  void likeIfNotAlready() {
    if (_liked || _likeBusy) return;
    _toggleLike();
  }

  Future<void> _toggleLike() async {
    final postId = widget.item.post?.id;
    if (postId == null || _likeBusy) return;
    if (!await requireLogin(
      context,
      title: 'Sign in to like',
      message: 'Log in or create a free account to like scenes.',
    )) {
      return;
    }
    if (!mounted) return;
    final nextLiked = !_liked;
    final generation = ++_likeGeneration;
    setState(() {
      _liked = nextLiked;
      _likeCount += nextLiked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    _engagement.setLiked(postId, nextLiked);
    _likeBusy = true;
    try {
      final result = nextLiked
          ? await SocialService.instance.likePost(postId)
          : await SocialService.instance.unlikePost(postId);
      if (!mounted || generation != _likeGeneration) return;
      if (result.likeCount != null) {
        setState(() => _likeCount = result.likeCount!);
        _engagement.setLiked(postId, nextLiked, likeCount: result.likeCount);
      }
    } catch (_) {
      if (!mounted || generation != _likeGeneration) return;
      setState(() {
        _liked = !nextLiked;
        _likeCount += nextLiked ? -1 : 1;
        if (_likeCount < 0) _likeCount = 0;
      });
      _engagement.setLiked(postId, !nextLiked, likeCount: _likeCount);
    } finally {
      if (generation == _likeGeneration) _likeBusy = false;
    }
  }

  Future<void> _openComments() async {
    final postId = widget.item.post?.id;
    if (postId == null) return;
    // The sheet is compose-only and autofocuses its field, so a guest is
    // asked to log in before it opens rather than after typing.
    if (!await requireLogin(
      context,
      title: 'Sign in to comment',
      message: 'Log in or create a free account to comment.',
    )) {
      return;
    }
    if (!mounted) return;
    final posted = await SceneVideoCommentSheet.show(
      context,
      postId: postId,
      authorName: widget.item.authorName ?? 'Artist',
    );
    if (!mounted || posted != true) return;
    setState(() => _commentCount += 1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Comment posted')));
  }

  Future<void> _openDescription() {
    return ReelDescriptionSheet.show(
      context,
      item: widget.item,
      followState: followState,
      followBusy: followBusy,
      onFollowToggle: toggleFollow,
      onCommentPosted: () => setState(() => _commentCount += 1),
    );
  }

  // Share hidden for now — see plan/task history to re-enable.
  // Future<void> _shareScene() async {
  //   final post = widget.item.post;
  //   final author = widget.item.authorName ?? 'an artist';
  //   final caption = post?.caption?.trim();
  //   final mediaUrl = widget.item.mediaUrl;
  //   final lines = <String>[
  //     'Scene by $author on Studio',
  //     if (caption != null && caption.isNotEmpty) caption,
  //     if (mediaUrl != null && mediaUrl.isNotEmpty) mediaUrl,
  //   ];
  //   await Clipboard.setData(ClipboardData(text: lines.join('\n\n')));
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text('Scene link copied')));
  // }

  Future<void> _toggleSave() async {
    final postId = widget.item.post?.id;
    if (postId == null || _saveBusy) return;
    if (!await requireLogin(
      context,
      title: 'Sign in to save',
      message: 'Log in or create a free account to save scenes.',
    )) {
      return;
    }
    if (!mounted) return;
    final nextSaved = !_saved;

    List<String> collectionIds = const [];
    final hadCollections = SavedContentStore.instance.hasCollections;
    if (nextSaved) {
      final resolution = await resolveSaveCollection(
        context,
        pieceTitle: widget.item.title,
        thumbnailUrl: widget.item.mediaUrl,
        forSale: widget.item.isForSale,
      );
      if (resolution.cancelled) return;
      collectionIds = resolution.collectionIds;
    }

    final generation = ++_saveGeneration;
    setState(() => _saved = nextSaved);
    _engagement.setSaved(postId, nextSaved);
    if (nextSaved) {
      SavedContentStore.instance.saveFeedItem(widget.item);
      for (final collectionId in collectionIds) {
        SavedContentStore.instance.addEntryToCollection(
          collectionId,
          postId,
          targetType: 'post',
        );
      }
    } else {
      SavedContentStore.instance.unsave(postId);
    }

    _saveBusy = true;
    try {
      if (nextSaved) {
        await SocialService.instance.savePost(postId);
      } else {
        await SocialService.instance.unsavePost(postId);
      }
      if (mounted &&
          nextSaved &&
          hadCollections &&
          generation == _saveGeneration) {
        showCollectionSavedToast(
          context,
          saved: true,
          thumbnailUrl: widget.item.mediaUrl,
        );
      }
    } catch (_) {
      // Roll back local state so client/server stay aligned.
      if (!mounted || generation != _saveGeneration) return;
      setState(() => _saved = !nextSaved);
      _engagement.setSaved(postId, !nextSaved);
      if (nextSaved) {
        SavedContentStore.instance.unsave(postId);
      } else {
        SavedContentStore.instance.saveFeedItem(widget.item);
      }
    } finally {
      if (generation == _saveGeneration) _saveBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.item.post;
    final authorName = widget.item.authorName ?? 'Artist';
    final authorUsername = widget.item.authorUsername;
    final caption = post?.caption ?? widget.item.title ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 12, widget.bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: authorUsername != null
                          ? () => openUserProfile(context, authorUsername)
                          : null,
                      behavior: authorUsername != null
                          ? HitTestBehavior.opaque
                          : HitTestBehavior.deferToChild,
                      child: ProfileAvatar(
                        url: widget.item.authorAvatarUrl,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                style: StudioType.sans(
                                  11,
                                  color: StudioColors.galleryWhite.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (authorUsername != null &&
                        authorUsername.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FollowButton(
                        state: followState,
                        onPressed: toggleFollow,
                        dense: true,
                        busy: followBusy,
                      ),
                    ],
                  ],
                ),
                if (caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openDescription,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.label13(
                        color: StudioColors.galleryWhite.withValues(alpha: 0.92),
                      ).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LikeActionButton(
                liked: _liked,
                label: _likeCount > 0 ? '$_likeCount' : 'Like',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: const StudioIcon(
                  StudioIcons.chat,
                  size: 28,
                  color: StudioColors.galleryWhite,
                ),
                label: _commentCount > 0 ? '$_commentCount' : 'Comment',
                onTap: _openComments,
              ),
              const SizedBox(height: 18),
              _SaveActionButton(saved: _saved, onTap: _toggleSave),
              const SizedBox(height: 18),
              _MuteActionButton(
                muted: widget.muted,
                onTap: widget.onToggleMute,
              ),
              if (widget.item.post?.id != null) ...[
                const SizedBox(height: 18),
                _ActionButton(
                  icon: const StudioIcon(
                    StudioIcons.more,
                    size: 28,
                    color: StudioColors.galleryWhite,
                  ),
                  label: 'More',
                  // Blocking removes this reel (and the rest of the
                  // author's) from ReelsPage via BlockedAuthorsStore.
                  onTap: () => showContentActionsSheet(
                    context,
                    target: ReportTarget.post(widget.item.post!.id),
                    authorUsername: widget.item.authorUsername,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LikeActionButton extends StatelessWidget {
  const _LikeActionButton({
    required this.liked,
    required this.label,
    required this.onTap,
  });

  final bool liked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? context.studio.alert : StudioColors.galleryWhite,
            size: 30,
            fill: liked ? 1 : 0,
          ),
          const SizedBox(height: 4),
          Text(label, style: _actionLabel),
        ],
      ),
    );
  }
}

TextStyle get _actionLabel => StudioType.sans(
  11,
  weight: StudioType.medium,
  color: StudioColors.galleryWhite,
);

class _SaveActionButton extends StatelessWidget {
  const _SaveActionButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          StudioIcon(
            saved ? StudioIcons.saved : StudioIcons.save,
            size: 30,
            color: StudioColors.galleryWhite,
          ),
          const SizedBox(height: 4),
          Text('Save', style: _actionLabel),
        ],
      ),
    );
  }
}

class _MuteActionButton extends StatelessWidget {
  const _MuteActionButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: StudioColors.galleryWhite,
        size: 28,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 4),
          Text(label, style: _actionLabel),
        ],
      ),
    );
  }
}

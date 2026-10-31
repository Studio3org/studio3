import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_link_config.dart';
import '../../models/feed_item.dart';
import '../../models/feed_preview_item.dart';
import '../../models/piece_summary.dart';
import '../../screens/edit_scene_page.dart';
import '../../services/api_exception.dart';
import '../../services/auth_session.dart';
import '../../services/engagement_store.dart';
import '../../services/piece_service.dart';
import '../../services/post_service.dart';
import '../../services/report_service.dart';
import '../../services/saved_content_store.dart';
import '../../services/social_service.dart';
import '../../utils/explore_detail_route.dart';
import '../../utils/money_format.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../collection_saved_toast.dart';
import '../content_actions_sheet.dart';
import '../follow_button.dart';
import '../piece_detail/detail_follow_state.dart';
import '../piece_detail/piece_comment_sheet.dart';
import '../save_to_collection_sheet.dart';
import '../studio/studio.dart';

/// The Scene viewer's controls (`SceneViewer`, `SceneViewerPhoto`), over the playing Scene.
///
/// Top: back, sound (videos only) and more (copy link, block, report; Edit for your own),
/// 44 targets 12 below the safe area, white with a soft shadow over a 130 dark fade.
/// Right, 10 in: Save and Comments (26 icons, Mono 11 counts) and Share, 18 apart. Bottom
/// left, 16 in and clear of the rail: the artist (32 photo with a white ring, 15/500 name,
/// a white Follow), the caption (14/1.45, two lines, tap for all of it) and the linked piece
/// as one plain line (26 × 35 thumbnail, title, softer price, arrow), or "2 linked pieces"
/// with the thumbnails overlapping, which opens [ScenePiecesSheet]. A 380 dark fade sits
/// behind it, and videos have a 2 white progress line 26 from the bottom. No likes.
class ReelOverlay extends StatefulWidget {
  const ReelOverlay({
    super.key,
    required this.item,
    this.bottomInset = 0,
    this.soundOn = false,
    this.onToggleSound,
    this.progress,
    this.onBack,
  });

  final FeedItem item;

  /// Space kept clear below the controls (the floating nav when it shows under them).
  final double bottomInset;

  /// Videos only: the sound button and the progress line.
  final bool soundOn;
  final VoidCallback? onToggleSound;

  /// 0–1 through the video; null for photos.
  final ValueListenable<double>? progress;

  /// Back; defaults to popping the viewer.
  final VoidCallback? onBack;

  @override
  State<ReelOverlay> createState() => ReelOverlayState();
}

class ReelOverlayState extends State<ReelOverlay> with DetailFollowState<ReelOverlay> {
  late bool _saved;
  int? _saveCount;
  int _commentCount = 0;
  bool _saveBusy = false;
  int _saveGeneration = 0;
  bool _captionOpen = false;
  List<PieceSummary> _linked = const [];

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
    if (oldWidget.item != widget.item) _syncFromItem();
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
    _saved = postId != null
        ? _engagement.resolveSaved(
            postId,
            SavedContentStore.instance.isSaved(postId) || (post?.isSaved ?? false),
          )
        : false;
    _saveCount = post?.saveCount;
    // The count the server sent (it used to start at 0).
    _commentCount = post?.commentCount ?? 0;
    followState = widget.item.authorIsFollowing ? FollowState.following : FollowState.none;
    _loadLinked();
  }

  List<String> get _linkedIds {
    final post = widget.item.post;
    if (post == null) return const [];
    if (post.linkedPieceIds.isNotEmpty) return post.linkedPieceIds;
    final single = post.pieceId;
    return single == null || single.isEmpty ? const [] : [single];
  }

  /// The feed sends the linked piece ids only; the pieces themselves come from the cache.
  Future<void> _loadLinked() async {
    final ids = _linkedIds;
    final known = widget.item.post?.linkedPiece;
    if (ids.isEmpty) {
      _linked = const [];
      return;
    }
    if (ids.length == 1 && known != null) {
      _linked = [known];
      return;
    }
    final itemAtStart = widget.item;
    final loaded = <PieceSummary>[];
    for (final id in ids) {
      try {
        loaded.add(
          known != null && known.id == id
              ? known
              : await PieceService.instance.getByIdCached(id),
        );
      } catch (_) {
        // A piece that has gone (deleted, hidden) is left out.
      }
    }
    if (!mounted || widget.item != itemAtStart) return;
    setState(() => _linked = loaded);
  }

  void _onEngagementChanged() {
    if (!mounted || _saveBusy) return;
    final postId = widget.item.post?.id;
    if (postId == null) return;
    final nextSaved = _engagement.resolveSaved(
      postId,
      SavedContentStore.instance.isSaved(postId) || (widget.item.post?.isSaved ?? false),
    );
    if (nextSaved != _saved) setState(() => _saved = nextSaved);
  }

  bool get _isOwn {
    final me = AuthSession.instance.user?.username.toLowerCase();
    final author = widget.item.authorUsername?.toLowerCase();
    return me != null && me.isNotEmpty && me == author;
  }

  Future<void> _openComments() async {
    final postId = widget.item.post?.id;
    if (postId == null) return;
    await PieceCommentSheet.show(
      context,
      contentId: postId,
      isScene: true,
      commentCount: _commentCount,
      artistUsername: widget.item.authorUsername,
      overMedia: true,
      onCountChanged: (count) {
        if (mounted) setState(() => _commentCount = count);
      },
    );
  }

  /// The link a Scene shares: its linked piece, or the artist's profile. Scenes have no
  /// share page of their own yet (BACKEND_CHANGES B33).
  String? get _shareLink {
    final ids = _linkedIds;
    if (ids.isNotEmpty) return AppLinkConfig.pieceUrl(ids.first);
    final username = widget.item.authorUsername;
    if (username == null || username.isEmpty) return null;
    return AppLinkConfig.profileUrl(username);
  }

  String get _shareText {
    final author = widget.item.authorName ?? 'an artist';
    final caption = widget.item.post?.caption?.trim();
    final link = _shareLink;
    return [
      'A Scene by $author on Studio 3',
      if (caption != null && caption.isNotEmpty) caption,
      ?link,
    ].join('\n\n');
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      await SharePlus.instance.share(ShareParams(text: _shareText, sharePositionOrigin: origin));
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not open sharing', icon: null);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareLink ?? _shareText));
    if (mounted) showStudioToast(context, 'Link copied');
  }

  Future<void> _editScene() async {
    final postId = widget.item.post?.id;
    if (postId == null) return;
    try {
      final post = await PostService.instance.getById(postId);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => EditScenePage(post: post)),
      );
    } catch (e) {
      if (!mounted) return;
      showStudioToast(
        context,
        e is ApiException ? e.message : 'Could not load for editing',
        icon: null,
      );
    }
  }

  /// More: copy link, then Edit for your own Scene, or Block and Report for someone else's.
  void _openMore() {
    final postId = widget.item.post?.id;
    final username = widget.item.authorUsername;
    showStudioSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          const SizedBox(height: 2),
          StudioActionRow(
            icon: StudioIcons.link,
            title: 'Copy link',
            onTap: () {
              Navigator.pop(sheetContext);
              _copyLink();
            },
          ),
          if (_isOwn)
            StudioActionRow(
              icon: StudioIcons.edit,
              title: 'Edit Scene',
              onTap: () {
                Navigator.pop(sheetContext);
                _editScene();
              },
            )
          else ...[
            if (username != null && username.isNotEmpty)
              StudioActionRow(
                icon: StudioIcons.block,
                title: 'Block @$username',
                onTap: () {
                  Navigator.pop(sheetContext);
                  // Blocking drops this Scene (and the rest of theirs) from the viewer.
                  confirmBlockUser(context, username: username);
                },
              ),
            if (postId != null)
              StudioActionRow(
                icon: StudioIcons.report,
                title: 'Report Scene',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showReportSheet(context, target: ReportTarget.post(postId));
                },
              ),
          ],
        ],
      ),
    );
  }

  void _openLinked() {
    if (_linkedIds.length > 1) {
      ScenePiecesSheet.show(context, pieces: _linked);
    } else if (_linked.isNotEmpty) {
      openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(_linked.first));
    }
  }

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
        thumbnailUrl: widget.item.thumbnailUrl ?? widget.item.mediaUrl,
        forSale: widget.item.isForSale,
      );
      if (resolution.cancelled) return;
      collectionIds = resolution.collectionIds;
    }

    final generation = ++_saveGeneration;
    setState(() {
      _saved = nextSaved;
      if (_saveCount != null) _saveCount = math.max(0, _saveCount! + (nextSaved ? 1 : -1));
    });
    _engagement.setSaved(postId, nextSaved);
    if (nextSaved) {
      SavedContentStore.instance.saveFeedItem(widget.item);
      for (final collectionId in collectionIds) {
        SavedContentStore.instance.addEntryToCollection(collectionId, postId, targetType: 'post');
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
      if (mounted && nextSaved && hadCollections && generation == _saveGeneration) {
        showCollectionSavedToast(
          context,
          saved: true,
          thumbnailUrl: widget.item.thumbnailUrl ?? widget.item.mediaUrl,
        );
      }
    } catch (_) {
      // Roll back local state so client/server stay aligned.
      if (!mounted || generation != _saveGeneration) return;
      setState(() {
        _saved = !nextSaved;
        if (_saveCount != null) _saveCount = math.max(0, _saveCount! + (nextSaved ? -1 : 1));
      });
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
    final mq = MediaQuery.of(context);
    final isVideo = widget.progress != null;
    // The progress line sits 26 up (or on the safe area); the text 16 above it.
    final lineBottom = widget.bottomInset + (mq.padding.bottom > 26 ? mq.padding.bottom : 26);
    final contentBottom = lineBottom + 18;

    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: _Fades()),
        Positioned(
          left: 0,
          right: 0,
          top: mq.padding.top,
          child: _TopBar(
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
            soundOn: isVideo ? widget.soundOn : null,
            onToggleSound: widget.onToggleSound,
            onMore: _openMore,
          ),
        ),
        Positioned(
          right: 10,
          bottom: contentBottom + 156,
          child: _Rail(
            saved: _saved,
            saveCount: _saveCount,
            commentCount: _commentCount,
            onSave: _toggleSave,
            onComments: _openComments,
            onShare: _share,
          ),
        ),
        Positioned(
          left: 16,
          right: 64,
          bottom: contentBottom,
          child: _Info(
            item: widget.item,
            followState: followState,
            followBusy: followBusy,
            onFollow: _isOwn ? null : toggleFollow,
            captionOpen: _captionOpen,
            onCaptionTap: () => setState(() => _captionOpen = !_captionOpen),
            linkedCount: _linkedIds.length,
            linked: _linked,
            onLinked: _openLinked,
          ),
        ),
        if (widget.progress != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: lineBottom,
            child: _ProgressLine(progress: widget.progress!),
          ),
      ],
    );
  }
}

const _textShadow = [Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1))];
const _iconShadow = Color(0x80000000);

/// The 130 fade under the top bar and the 380 fade under the text.
class _Fades extends StatelessWidget {
  const _Fades();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 130,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x73000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 380,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white icon with the boards' drop shadow (0 1 3 at 50 %).
class _ShadowIcon extends StatelessWidget {
  const _ShadowIcon(this.asset, {required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, 1),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: StudioIcon(asset, size: size, color: _iconShadow),
          ),
        ),
        StudioIcon(asset, size: size, color: StudioColors.galleryWhite),
      ],
    );
  }
}

class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(dimension: 44, child: Center(child: child)),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.soundOn,
    required this.onToggleSound,
    required this.onMore,
  });

  final VoidCallback onBack;

  /// Null for photos (no sound button).
  final bool? soundOn;
  final VoidCallback? onToggleSound;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          _TapTarget(
            label: 'Back',
            onTap: onBack,
            child: const _ShadowIcon(StudioIcons.back, size: 22),
          ),
          const Spacer(),
          if (soundOn != null)
            _TapTarget(
              label: soundOn! ? 'Sound on' : 'Sound off',
              onTap: onToggleSound,
              child: _ShadowIcon(soundOn! ? StudioIcons.soundOn : StudioIcons.soundOff, size: 22),
            ),
          _TapTarget(
            label: 'More',
            onTap: onMore,
            child: const _ShadowIcon(StudioIcons.more, size: 24),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.saved,
    required this.saveCount,
    required this.commentCount,
    required this.onSave,
    required this.onComments,
    required this.onShare,
  });

  final bool saved;
  final int? saveCount;
  final int commentCount;
  final VoidCallback onSave;
  final VoidCallback onComments;
  final void Function(BuildContext buttonContext) onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          label: saved ? 'Saved' : 'Save',
          icon: saved ? StudioIcons.saved : StudioIcons.save,
          count: saveCount,
          onTap: onSave,
        ),
        const SizedBox(height: 18),
        _RailButton(
          label: 'Comments',
          icon: StudioIcons.chat,
          count: commentCount > 0 ? commentCount : null,
          onTap: onComments,
        ),
        const SizedBox(height: 18),
        Builder(
          builder: (buttonContext) => _RailButton(
            label: 'Share',
            icon: StudioIcons.share,
            onTap: () => onShare(buttonContext),
          ),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.label, required this.icon, required this.onTap, this.count});

  final String label;
  final String icon;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShadowIcon(icon, size: 26),
              if (count != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: StudioType.mono(
                    11,
                    color: StudioColors.galleryWhite,
                  ).copyWith(shadows: _textShadow),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.item,
    required this.followState,
    required this.followBusy,
    required this.onFollow,
    required this.captionOpen,
    required this.onCaptionTap,
    required this.linkedCount,
    required this.linked,
    required this.onLinked,
  });

  final FeedItem item;
  final FollowState followState;
  final bool followBusy;

  /// Null on your own Scene (no Follow).
  final VoidCallback? onFollow;
  final bool captionOpen;
  final VoidCallback onCaptionTap;
  final int linkedCount;
  final List<PieceSummary> linked;
  final VoidCallback onLinked;

  @override
  Widget build(BuildContext context) {
    final username = item.authorUsername;
    final caption = (item.post?.caption ?? '').trim();
    void openArtist() => openUserProfile(context, username);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StudioTapArea(
              child: GestureDetector(
              onTap: username == null ? null : openArtist,
              behavior: HitTestBehavior.opaque,
              child: StudioAvatar(
                url: item.authorAvatarUrl,
                size: 32,
                ringWidth: 1.5,
                ringColor: StudioColors.galleryWhite,
                ringInside: true,
                semanticLabel: item.authorName,
              ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              // A text link (inline links are exempt from the 44 minimum).
              child: Semantics(
                link: true,
                child: GestureDetector(
                onTap: username == null ? null : openArtist,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  item.authorName ?? username ?? 'Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.sans(
                    15,
                    weight: StudioType.medium,
                    color: StudioColors.galleryWhite,
                  ).copyWith(shadows: _textShadow),
                ),
                ),
              ),
            ),
            if (onFollow != null && username != null && username.isNotEmpty) ...[
              const SizedBox(width: 10),
              SceneFollowButton(state: followState, busy: followBusy, onPressed: onFollow!),
            ],
          ],
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          StudioTapArea(
            child: Semantics(
            button: true,
            label: caption,
            hint: captionOpen ? 'Shows less' : 'Shows all of it',
            excludeSemantics: true,
            child: GestureDetector(
            onTap: onCaptionTap,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              // An open caption scrolls rather than pushing the artist off the screen.
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
              child: SingleChildScrollView(
                physics: captionOpen ? null : const NeverScrollableScrollPhysics(),
                child: Text(
                  caption,
                  maxLines: captionOpen ? null : 2,
                  overflow: captionOpen ? null : TextOverflow.ellipsis,
                  style: StudioType.sans(
                    14,
                    height: 1.45,
                    color: StudioColors.galleryWhite,
                  ).copyWith(shadows: _textShadow),
                ),
              ),
            ),
          ),
          ),
          ),
        ],
        if (linkedCount > 0) ...[
          const SizedBox(height: 10),
          SceneLinkedLine(count: linkedCount, pieces: linked, onTap: onLinked),
        ],
      ],
    );
  }
}

/// `SceneViewer` Follow on a Scene: solid white with Ink text, 28 high, radius 8, 12/500.
/// Following (and Requested) is a white outline with white text, the same size.
class SceneFollowButton extends StatelessWidget {
  const SceneFollowButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.busy = false,
  });

  final FollowState state;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final filled = state.filled;
    final textColor = filled ? StudioColors.ink : StudioColors.galleryWhite;
    return StudioTapArea(
      child: Semantics(
      button: true,
      enabled: !busy,
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? StudioColors.galleryWhite : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: const Color(0xB3FFFFFF)),
          ),
          child: Text(
            state.actionLabel,
            style: StudioType.sans(12, weight: StudioType.medium, color: textColor),
          ),
        ),
      ),
      ),
    );
  }
}

/// The linked piece as one plain line: a 26 × 35 thumbnail (radius 4, soft shadow), the title
/// 14/500 in white, the price 13 in softer white, and a 14 arrow. With more than one piece the
/// thumbnails overlap by 12 (each with a white edge) and the line reads "2 linked pieces".
class SceneLinkedLine extends StatelessWidget {
  const SceneLinkedLine({
    super.key,
    required this.count,
    required this.pieces,
    required this.onTap,
  });

  final int count;
  final List<PieceSummary> pieces;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final several = count > 1;
    final piece = pieces.isEmpty ? null : pieces.first;
    final price = piece != null && piece.isForSale && piece.priceCents != null
        ? formatMoney(piece.priceCents!)
        : null;
    final label = several ? '$count linked pieces' : (piece?.title ?? 'Linked piece');
    final shown = several ? pieces.take(3).toList() : pieces.take(1).toList();

    return StudioTapArea(
      child: Semantics(
      button: true,
      label: price == null ? label : '$label, $price',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shown.isNotEmpty) ...[
              if (several)
                // Each one 12 over the one before it.
                SizedBox(
                  width: 28 + (shown.length - 1) * 16,
                  height: 37,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * 16.0,
                          top: 0,
                          child: _LinkedThumb(url: shown[i].mediaUrl, outlined: true),
                        ),
                    ],
                  ),
                )
              else
                _LinkedThumb(url: shown.first.mediaUrl, outlined: false),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.sans(
                  14,
                  weight: StudioType.medium,
                  color: StudioColors.galleryWhite,
                ).copyWith(shadows: _textShadow),
              ),
            ),
            if (!several && price != null) ...[
              const SizedBox(width: 10),
              Text(
                price,
                style: StudioType.sans(
                  13,
                  color: const Color(0xBFFFFFFF),
                ).copyWith(shadows: _textShadow),
              ),
            ],
            const SizedBox(width: 10),
            const StudioIcon(StudioIcons.chevronRight, size: 14, color: StudioColors.galleryWhite),
          ],
        ),
      ),
      ),
    );
  }
}

class _LinkedThumb extends StatelessWidget {
  const _LinkedThumb({required this.url, required this.outlined});

  final String? url;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final size = outlined ? const Size(28, 37) : const Size(26, 35);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: outlined ? Border.all(color: const Color(0xCCFFFFFF)) : null,
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outlined ? 3 : 4),
        child: url == null || url!.isEmpty
            ? const ColoredBox(color: Color(0x33FFFFFF))
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(color: Color(0x33FFFFFF)),
              ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: SizedBox(
          height: 2,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0x4DFFFFFF)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: const ColoredBox(color: StudioColors.galleryWhite),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `ScenePiecesSheet`: "Linked pieces" (17/500), then one row per piece: a 48 × 64 picture
/// (radius 6), the title 15/500 and artist 13 in Graphite, and the price 14 or "Not for sale"
/// in Graphite, 12 above and below with a Line under each. Tapping a row opens that piece.
class ScenePiecesSheet extends StatelessWidget {
  const ScenePiecesSheet({super.key, required this.pieces});

  final List<PieceSummary> pieces;

  static Future<void> show(BuildContext context, {required List<PieceSummary> pieces}) {
    return showStudioSheet<void>(
      context: context,
      builder: (_) => ScenePiecesSheet(pieces: pieces),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      scrollable: true,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Linked pieces',
            style: StudioType.sans(17, weight: StudioType.medium, color: c.textPrimary),
          ),
        ),
        for (final piece in pieces) _LinkedPieceRow(piece: piece),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _LinkedPieceRow extends StatelessWidget {
  const _LinkedPieceRow({required this.piece});

  final PieceSummary piece;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final price = piece.isForSale && piece.priceCents != null ? formatMoney(piece.priceCents!) : null;
    final url = piece.mediaUrl ?? (piece.imageUrls.isEmpty ? null : piece.imageUrls.first);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(piece));
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: url == null || url.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.title.isEmpty ? 'Untitled' : piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    if ((piece.authorName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        piece.authorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.sans(13, color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                price ?? 'Not for sale',
                style: StudioType.sans(14, color: price == null ? c.textSecondary : c.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

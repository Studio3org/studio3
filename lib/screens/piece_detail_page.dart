import 'package:flutter/material.dart';

import '../models/feed_preview_item.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../theme/collect_detail_tokens.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/content_detail_loader.dart';
import 'edit_piece_page.dart';
import 'edit_scene_page.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/double_tap_like_hint.dart';
import '../widgets/piece_detail/materials_sheet.dart';
import '../widgets/piece_detail/piece_action_bar.dart';
import '../widgets/piece_detail/piece_artist_row.dart';
import '../widgets/piece_detail/piece_comment_sheet.dart';
import '../widgets/piece_detail/piece_figma_detail_body.dart';
import '../widgets/piece_detail/piece_hero_overlay.dart';
import '../widgets/piece_detail/piece_location_row.dart';
import '../widgets/piece_detail/piece_more_sheet.dart';
import '../widgets/piece_detail/piece_related_scenes_row.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/piece_series_row.dart';
import '../theme/app_fonts.dart';

class PieceDetailPage extends StatefulWidget {
  const PieceDetailPage({
    super.key,
    required this.item,
    this.initialImageIndex = 0,
  });

  final FeedPreviewItem item;
  final int initialImageIndex;

  @override
  State<PieceDetailPage> createState() => _PieceDetailPageState();
}

class _PieceDetailPageState extends State<PieceDetailPage>
    with
        TickerProviderStateMixin,
        DetailSaveState,
        DetailLikeState,
        DetailFollowState {
  late FeedPreviewItem _item;
  late final AnimationController _hintController;
  late final AnimationController _burstController;

  @override
  FeedPreviewItem get saveItem => _item;

  @override
  FeedPreviewItem get likeItem => _item;

  FeedPreviewItem get item => _item;

  String get _authorHandle =>
      item.handle.startsWith('@') ? item.handle.substring(1) : item.handle;

  @override
  String get followUsername => _authorHandle;

  bool get _isOwner {
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() == _authorHandle.toLowerCase();
  }

  Future<void> _onEdit() async {
    try {
      if (item.isPiece) {
        final piece = await PieceService.instance.getById(item.id);
        if (!mounted) return;
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(builder: (_) => EditPiecePage(piece: piece)),
        );
        if (saved == true) _loadDetail();
      } else {
        final post = await PostService.instance.getById(item.id);
        if (!mounted) return;
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(builder: (_) => EditScenePage(post: post)),
        );
        if (saved == true) _loadDetail();
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Could not load for editing';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void initState() {
    _item = engagementStore.applyToPreview(widget.item);
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    super.initState();
    liked = _item.isLiked;
    likeCount = _item.likeCount;
    applyFollowState(_item);
    _loadDetail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || liked || item.isScene) return;
      _hintController.forward();
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final loaded = await ContentDetailLoader.load(_item);
    if (!mounted) return;
    setState(() => _item = loaded);
    applySaveItem(loaded);
    applyLikeItem(loaded);
    applyFollowState(loaded);
  }

  Future<void> _onDoubleTapLike() async {
    _hintController.stop();
    _hintController.value = 1;
    await likeFromDoubleTap();
    if (!mounted) return;
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (item.isScene) return _buildSceneDetail();
    return _buildPieceDetail();
  }

  Widget _buildPieceDetail() {
    return Scaffold(
      backgroundColor: CollectDetailTokens.background,
      body: DetailScrollHandoff(
        bottomInset: MediaQuery.paddingOf(context).bottom,
        slivers: [
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DetailHeroImage(
                    item: item,
                    initialImageIndex: widget.initialImageIndex,
                    onDoubleTap: _onDoubleTapLike,
                  ),
                  PieceHeroOverlay(
                    saved: saved,
                    onBack: () => Navigator.pop(context),
                    onSave: toggleSave,
                    onShare: () => PieceShareSheet.show(
                      context,
                      item,
                      imageIndex: widget.initialImageIndex,
                    ),
                    onMore: () => PieceMoreSheet.show(
                      context,
                      item: item,
                      isOwner: _isOwner,
                      onEdit: _isOwner ? _onEdit : null,
                      imageIndex: widget.initialImageIndex,
                    ),
                  ),
                  if (!liked || _hintController.isAnimating)
                    DoubleTapLikeHint(animation: _hintController),
                  DoubleTapLikeBurst(animation: _burstController),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PieceFigmaDetailBody(
              item: item,
              followState: followState,
              followBusy: followBusy,
              onFollowToggle: toggleFollow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneDetail() {
    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      body: DetailScrollHandoff(
        bottomInset: MediaQuery.paddingOf(context).bottom,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: item.aspectRatioValue,
                  child: DetailHeroImage(
                    item: item,
                    initialImageIndex: widget.initialImageIndex,
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: HomeFeedTokens.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: HomeFeedTokens.detailBackground
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
                if (_isOwner)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 8,
                    child: IconButton(
                      onPressed: _onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: HomeFeedTokens.textPrimary,
                      style: IconButton.styleFrom(
                        backgroundColor: HomeFeedTokens.detailBackground
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PieceActionBar(
                  liked: liked,
                  saved: saved,
                  onLike: toggleLike,
                  onComment: () => PieceCommentSheet.show(
                    context,
                    contentId: item.id,
                    isScene: item.isScene,
                  ),
                  onShare: () => PieceShareSheet.show(
                    context,
                    item,
                    imageIndex: widget.initialImageIndex,
                  ),
                  onSave: toggleSave,
                ),
                const Divider(height: 1, color: Color(0xFFE8E5DF)),
                PieceArtistRow(
                  item: item,
                  followState: followState,
                  followBusy: followBusy,
                  onFollowToggle: toggleFollow,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    item.title,
                    style: AppFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.medium} · ${item.year}',
                              style: AppFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: HomeFeedTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.dimensions,
                              style: AppFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: HomeFeedTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.materials.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              showMaterialsSheet(context, item.materials),
                          child: Text(
                            'View Materials →',
                            style: AppFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: HomeFeedTokens.sky600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PieceLocationRow(location: item.location),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text(
                    item.story,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8E5DF)),
                const SizedBox(height: 16),
                PieceSeriesRow(
                  seriesName: item.seriesName,
                  thumbSeeds: item.seriesThumbs,
                  thumbUrls: item.seriesThumbUrls,
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE8E5DF)),
                const SizedBox(height: 16),
                PieceRelatedScenesRow(scenes: item.relatedScenes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

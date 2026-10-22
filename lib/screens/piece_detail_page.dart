import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/feed_preview_item.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../services/report_service.dart';
import '../theme/home_feed_tokens.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../utils/content_detail_loader.dart';
import 'edit_piece_page.dart';
import 'edit_scene_page.dart';
import '../widgets/content_actions_sheet.dart';
import '../widgets/piece_detail/ask_about_piece_sheet.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/piece_action_bar.dart';
import '../widgets/piece_detail/piece_artist_row.dart';
import '../widgets/piece_detail/materials_sheet.dart';
import '../widgets/piece_detail/piece_comment_sheet.dart';
import '../widgets/piece_detail/piece_location_row.dart';
import '../widgets/piece_detail/piece_related_scenes_row.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/collect_artist_row.dart';
import '../widgets/piece_detail/piece_page_sections.dart';
import '../widgets/piece_detail/piece_series_row.dart';
import '../widgets/studio/studio_chip.dart';

/// Detail page for a piece that is not for sale (`PieceNotForSale`; your own piece:
/// `ListOwnerPiece`, top part) and for Scenes, which keep their current layout.
class PieceDetailPage extends StatefulWidget {
  const PieceDetailPage({
    super.key,
    required this.item,
    this.initialImageIndex = 0,
    this.tappedIndex = 0,
    this.filter = FeedAvailabilityFilter.all,
    this.onWillAdvance,
  });

  final FeedPreviewItem item;
  final int initialImageIndex;
  final int tappedIndex;
  final FeedAvailabilityFilter filter;
  final void Function(int nextIndex)? onWillAdvance;

  @override
  State<PieceDetailPage> createState() => _PieceDetailPageState();
}

class _PieceDetailPageState extends State<PieceDetailPage>
    with DetailSaveState, DetailLikeState, DetailFollowState {
  late FeedPreviewItem _item;

  @override
  FeedPreviewItem get saveItem => _item;

  @override
  FeedPreviewItem get likeItem => _item;

  FeedPreviewItem get item => _item;

  String get _authorHandle => item.handle.startsWith('@') ? item.handle.substring(1) : item.handle;

  @override
  String get followUsername => _authorHandle;

  /// Report the piece/scene or block its artist (App Store guideline 1.2).
  void _onMore() {
    showContentActionsSheet(
      context,
      target: item.isScene ? ReportTarget.post(item.id) : ReportTarget.piece(item.id),
      authorUsername: _authorHandle,
      // Everything from this artist is hidden now, including this page.
      onBlocked: () {
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  bool get _isOwner {
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() == _authorHandle.toLowerCase();
  }

  bool get _canAskAboutPiece {
    if (item.isScene) return false;
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() != _authorHandle.toLowerCase();
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
      final message = e is ApiException ? e.message : 'Could not load for editing';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _onAskAboutPiece() async {
    final sent = await AskAboutPieceSheet.show(context, pieceId: item.id);
    if (sent == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent to the artist')));
    }
  }

  @override
  void initState() {
    _item = engagementStore.applyToPreview(widget.item);
    super.initState();
    liked = _item.isLiked;
    likeCount = _item.likeCount;
    applyFollowState(_item);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final loaded = await ContentDetailLoader.load(_item);
    if (!mounted) return;
    // Engagement overrides already merged in the loader — keep local
    // optimistic like/save if a toggle is still in flight via apply*.
    setState(() => _item = loaded);
    applySaveItem(loaded);
    applyLikeItem(loaded);
    applyFollowState(loaded);
  }

  @override
  Widget build(BuildContext context) {
    // Scenes keep this page as it was (plan, Phase 7); pieces follow the boards.
    return item.isScene ? _buildScene(context) : _buildPiece(context);
  }

  /// `PieceNotForSale`: same image, top icons, artist row and body as the fixed-price page,
  /// with no bottom bar and the not-for-sale line under the dimensions.
  Widget _buildPiece(BuildContext context) {
    final c = context.studio;
    final details = PieceDetailsSection.rowsFor(item);
    Widget padded(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

    final sections = <Widget>[
      padded(PieceTitleBlock(item: item, status: _statusLine(c))),
      if (item.story.trim().isNotEmpty) padded(PieceDescription(item.story)),
      if (item.materials.isNotEmpty) padded(PieceMadeWith(materials: item.materials)),
      if (item.relatedScenes.isNotEmpty) PieceRelatedScenesRow(scenes: item.relatedScenes),
      if (details.isNotEmpty) padded(PieceDetailsSection(rows: details)),
      if (item.seriesName.isNotEmpty &&
          (item.seriesThumbUrls.isNotEmpty || item.seriesThumbs.isNotEmpty))
        padded(
          PieceSeriesRow(
            seriesName: item.seriesName,
            thumbSeeds: item.seriesThumbs,
            thumbUrls: item.seriesThumbUrls,
            pieceCount: item.seriesPieceCount,
          ),
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the image, like the top icons.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.background,
        body: DetailScrollHandoff(
          tappedIndex: widget.tappedIndex,
          filter: widget.filter,
          onWillAdvance: widget.onWillAdvance,
          // No bar: 48 under the content, as the board's main padding.
          bottomInset: MediaQuery.paddingOf(context).bottom,
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: item.aspectRatioValue,
                    child: DetailHeroImage(item: item, initialImageIndex: widget.initialImageIndex),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PieceTopIcons(
                      isOwner: _isOwner,
                      saved: saved,
                      onBack: () => Navigator.pop(context),
                      onSave: toggleSave,
                      onShare: () =>
                          PieceShareSheet.show(context, item, imageIndex: widget.initialImageIndex),
                      onMore: _onMore,
                      onEdit: _onEdit,
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CollectArtistRow(
                    item: item,
                    followState: followState,
                    followBusy: followBusy,
                    onFollowToggle: toggleFollow,
                    isOwner: _isOwner,
                  ),
                  // Like and comment stay on the page (plan rule 4); Save and Share are in
                  // the top icons.
                  PieceActionBar(
                    liked: liked,
                    saved: saved,
                    onLike: toggleLike,
                    onComment: () =>
                        PieceCommentSheet.show(context, contentId: item.id, isScene: item.isScene),
                    onShare: () {},
                    onSave: toggleSave,
                    showSave: false,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: 26),
                    sections[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Not for sale" Mono pill and, for visitors, "Save it to hear if it's ever listed."
  /// (13 Graphite), 10 apart. Saving is what subscribes them to the listing notice. On your
  /// own piece the line is the pill alone: the board's "[N] people saved this" needs a save
  /// count the piece payload does not have. A sold piece shows the Collected chip instead.
  Widget _statusLine(StudioColors c) {
    if (item.status == 'sold') return const StudioStatusChip(StudioStatus.collected);
    return Row(
      children: [
        const StudioStatusChip(StudioStatus.notForSale),
        if (!_isOwner) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              "Save it to hear if it's ever listed.",
              style: StudioType.label13(color: c.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScene(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      body: DetailScrollHandoff(
        tappedIndex: widget.tappedIndex,
        filter: widget.filter,
        onWillAdvance: widget.onWillAdvance,
        bottomInset: MediaQuery.paddingOf(context).bottom,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: item.aspectRatioValue,
                  child: DetailHeroImage(item: item, initialImageIndex: widget.initialImageIndex),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: HomeFeedTokens.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: HomeFeedTokens.detailBackground.withValues(alpha: 0.7),
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
                        backgroundColor: HomeFeedTokens.detailBackground.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 8,
                    child: IconButton(
                      onPressed: _onMore,
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: HomeFeedTokens.textPrimary,
                      style: IconButton.styleFrom(
                        backgroundColor: HomeFeedTokens.detailBackground.withValues(alpha: 0.7),
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
                  onComment: () =>
                      PieceCommentSheet.show(context, contentId: item.id, isScene: item.isScene),
                  onShare: () =>
                      PieceShareSheet.show(context, item, imageIndex: widget.initialImageIndex),
                  onSave: toggleSave,
                ),
                const Divider(height: 1, color: Color(0xFFE8E5DF)),
                PieceArtistRow(
                  item: item,
                  followState: followState,
                  followBusy: followBusy,
                  onFollowToggle: toggleFollow,
                ),
                // "Ask about this piece" (piece-anchored inquiries) deferred to v2 in favor of
                // general-purpose chat. Left commented out rather than removed.
                // if (_canAskAboutPiece)
                //   Padding(
                //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                //     child: OutlinedButton(
                //       onPressed: _onAskAboutPiece,
                //       child: const Text('Ask about this piece'),
                //     ),
                //   ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: HomeFeedTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.dimensions,
                              style: GoogleFonts.inter(
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
                          onTap: () => showMaterialsSheet(context, item.materials),
                          child: Text(
                            'View Materials →',
                            style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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

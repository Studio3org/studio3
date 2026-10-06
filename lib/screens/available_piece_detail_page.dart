import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/feed_preview_item.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../theme/collect_detail_tokens.dart';
import '../utils/content_detail_loader.dart';
import 'edit_piece_page.dart';
import '../widgets/piece_detail/ask_about_piece_sheet.dart';
import '../widgets/piece_detail/available_collect_bar.dart';
import '../widgets/piece_detail/collect_artist_row.dart';
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/materials_sheet.dart';
import '../widgets/piece_detail/piece_action_bar.dart';
import '../widgets/piece_detail/piece_comment_sheet.dart';
import '../widgets/piece_detail/piece_location_row.dart';
import '../widgets/piece_detail/piece_related_scenes_row.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/piece_series_row.dart';

/// Collect / buy detail for available pieces (Figma 2302-1554).
class AvailablePieceDetailPage extends StatefulWidget {
  const AvailablePieceDetailPage({
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
  State<AvailablePieceDetailPage> createState() =>
      _AvailablePieceDetailPageState();
}

class _AvailablePieceDetailPageState extends State<AvailablePieceDetailPage>
    with DetailSaveState, DetailLikeState, DetailFollowState {
  late FeedPreviewItem _item;

  @override
  FeedPreviewItem get saveItem => _item;

  @override
  double get saveToastBottomMargin =>
      AvailableCollectBar.totalHeight(context) + 16;

  @override
  FeedPreviewItem get likeItem => _item;

  FeedPreviewItem get item => _item;

  String get _authorHandle =>
      item.handle.startsWith('@') ? item.handle.substring(1) : item.handle;

  @override
  String get followUsername => _authorHandle;

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
    final loaded = await ContentDetailLoader.loadPiece(_item);
    if (!mounted) return;
    setState(() => _item = loaded);
    applySaveItem(loaded);
    applyLikeItem(loaded);
    applyFollowState(loaded);
  }

  void _onCollect() {
    CollectPieceSheet.show(context, item: item);
  }

  bool get _isOwner {
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() == _authorHandle.toLowerCase();
  }

  bool get _canAskAboutPiece {
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() != _authorHandle.toLowerCase();
  }

  Future<void> _onEdit() async {
    try {
      final piece = await PieceService.instance.getById(item.id);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => EditPiecePage(piece: piece)),
      );
      if (saved == true) _loadDetail();
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

  Future<void> _onAskAboutPiece() async {
    final sent = await AskAboutPieceSheet.show(context, pieceId: item.id);
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to the artist')),
      );
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'sold':
        return 'Sold';
      case 'reserved':
        return 'Reserved';
      case 'delisted':
        return 'Not for sale';
      default:
        return 'Unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectBarHeight = AvailableCollectBar.totalHeight(context);
    final price = formatCollectPrice(item.priceCents);
    final isLive = item.isLive;

    return Scaffold(
      backgroundColor: CollectDetailTokens.background,
      body: Stack(
        children: [
          DetailScrollHandoff(
            tappedIndex: widget.tappedIndex,
            filter: widget.filter,
            onWillAdvance: widget.onWillAdvance,
            collectBarHeight: collectBarHeight,
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
                        color: CollectDetailTokens.textPrimary,
                        style: IconButton.styleFrom(
                          backgroundColor: CollectDetailTokens.background
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
                          color: CollectDetailTokens.textPrimary,
                          style: IconButton.styleFrom(
                            backgroundColor: CollectDetailTokens.background
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
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: CollectDetailTokens.divider,
                    ),
                    CollectArtistRow(
                      item: item,
                      followState: followState,
                      followBusy: followBusy,
                      onFollowToggle: toggleFollow,
                    ),
                    // "Ask about this piece" (piece-anchored inquiries) deferred to v2 in favor
                    // of general-purpose chat. Left commented out rather than removed.
                    // if (_canAskAboutPiece)
                    //   Padding(
                    //     padding: const EdgeInsets.fromLTRB(
                    //       CollectDetailTokens.horizontalPadding,
                    //       8,
                    //       CollectDetailTokens.horizontalPadding,
                    //       0,
                    //     ),
                    //     child: OutlinedButton(
                    //       onPressed: _onAskAboutPiece,
                    //       child: const Text('Ask about this piece'),
                    //     ),
                    //   ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CollectDetailTokens.horizontalPadding,
                        CollectDetailTokens.sectionGap,
                        CollectDetailTokens.horizontalPadding,
                        8,
                      ),
                      child: Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: CollectDetailTokens.titleSize,
                          fontWeight: FontWeight.w400,
                          height:
                              CollectDetailTokens.titleLineHeight /
                              CollectDetailTokens.titleSize,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CollectDetailTokens.horizontalPadding,
                      ),
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
                                    fontSize: CollectDetailTokens.metaSize,
                                    fontWeight: FontWeight.w400,
                                    height:
                                        CollectDetailTokens.metaLineHeight /
                                        CollectDetailTokens.metaSize,
                                    color: CollectDetailTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.dimensions,
                                  style: GoogleFonts.inter(
                                    fontSize: CollectDetailTokens.metaSize,
                                    fontWeight: FontWeight.w400,
                                    height:
                                        CollectDetailTokens.metaLineHeight /
                                        CollectDetailTokens.metaSize,
                                    color: CollectDetailTokens.textSecondary,
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
                                style: GoogleFonts.inter(
                                  fontSize: CollectDetailTokens.linkSize,
                                  fontWeight: FontWeight.w400,
                                  height: 15.6 / CollectDetailTokens.linkSize,
                                  color: CollectDetailTokens.link,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PieceLocationRow(location: item.location),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CollectDetailTokens.horizontalPadding,
                        CollectDetailTokens.sectionGap,
                        CollectDetailTokens.horizontalPadding,
                        CollectDetailTokens.sectionGap,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CollectDetailTokens.storyCardFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            item.story,
                            style: GoogleFonts.inter(
                              fontSize: CollectDetailTokens.storySize,
                              fontWeight: FontWeight.w400,
                              height:
                                  CollectDetailTokens.storyLineHeight /
                                  CollectDetailTokens.storySize,
                              color: CollectDetailTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: CollectDetailTokens.divider,
                    ),
                    const SizedBox(height: CollectDetailTokens.sectionGap),
                    PieceSeriesRow(
                      seriesName: item.seriesName,
                      thumbSeeds: item.seriesThumbs,
                      thumbUrls: item.seriesThumbUrls,
                    ),
                    const SizedBox(height: 24),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: CollectDetailTokens.divider,
                    ),
                    const SizedBox(height: CollectDetailTokens.sectionGap),
                    PieceRelatedScenesRow(scenes: item.relatedScenes),
                  ],
                ),
              ),
            ],
          ),
          AvailableCollectBar(
            priceDisplay: price,
            onCollect: isLive ? _onCollect : null,
            statusLabel: isLive ? null : _statusLabel(item.status),
          ),
        ],
      ),
    );
  }
}

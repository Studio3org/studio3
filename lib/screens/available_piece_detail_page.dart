import 'package:flutter/material.dart';

import '../models/feed_preview_item.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../theme/collect_detail_tokens.dart';
import '../utils/content_detail_loader.dart';
import 'edit_piece_page.dart';
import '../widgets/piece_detail/ask_about_piece_sheet.dart';
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/double_tap_like_hint.dart';
import '../widgets/piece_detail/piece_figma_detail_body.dart';
import '../widgets/piece_detail/piece_hero_overlay.dart';
import '../widgets/piece_detail/piece_more_sheet.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/place_bid_sheet.dart';

/// Collect / buy detail for available pieces (Figma 2707:3548).
class AvailablePieceDetailPage extends StatefulWidget {
  const AvailablePieceDetailPage({
    super.key,
    required this.item,
    this.initialImageIndex = 0,
  });

  final FeedPreviewItem item;
  final int initialImageIndex;

  @override
  State<AvailablePieceDetailPage> createState() =>
      _AvailablePieceDetailPageState();
}

class _AvailablePieceDetailPageState extends State<AvailablePieceDetailPage>
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
      if (!mounted || liked) return;
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

  void _onPlaceBid() {
    PlaceBidSheet.show(context, item: item);
  }

  void _onCompletePurchase() {
    CollectPieceSheet.show(
      context,
      item: item,
      winningBidCents: item.highestBidCents,
    );
  }

  bool get _isOwner {
    final viewerUsername = AuthSession.instance.user?.username;
    if (viewerUsername == null || viewerUsername.isEmpty) return false;
    return viewerUsername.toLowerCase() == _authorHandle.toLowerCase();
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

  Future<void> _onDoubleTapLike() async {
    _hintController.stop();
    _hintController.value = 1;
    await likeFromDoubleTap();
    if (!mounted) return;
    _burstController.forward(from: 0);
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'sold':
        return 'Sold';
      case 'reserved':
        return 'Reserved';
      case 'delisted':
        return 'Not for sale';
      case 'auction_won':
        return 'Auction ended';
      default:
        return 'Unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = formatCollectPrice(item.priceCents);
    final isLive = item.isLive;
    final isAuction = item.isAuction;
    final isAuctionWonByMe = item.isAuctionWon && item.isHighestBidder;

    return Scaffold(
      backgroundColor: CollectDetailTokens.background,
      body: DetailScrollHandoff(
        bottomPadding: 0,
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
              showCollect: true,
              collectPrice: price,
              onCollect: (!isAuction && isLive) ? _onCollect : null,
              onPlaceBid: isAuction
                  ? (isLive
                      ? _onPlaceBid
                      : (isAuctionWonByMe ? _onCompletePurchase : null))
                  : null,
              collectStatusLabel: isAuction
                  ? (isLive
                      ? null
                      : (isAuctionWonByMe
                          ? 'Complete purchase'
                          : _statusLabel(item.status)))
                  : (isLive ? null : _statusLabel(item.status)),
              onMessage: _isOwner ? null : _onAskAboutPiece,
              bottomInset: MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

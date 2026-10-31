import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart' show ChatPiece;
import '../models/feed_preview_item.dart';
import '../models/order.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/bid_service.dart';
import '../services/piece_service.dart';
import '../services/report_service.dart';
import '../utils/money_format.dart' show formatMoney;
import '../theme/studio_colors.dart';
import '../utils/content_detail_loader.dart';
import '../utils/require_login.dart';
import 'auction_flow.dart';
import 'conversation_thread_page.dart';
import 'edit_piece_page.dart';
import 'order_detail_page.dart';
import 'series_view_page.dart';
import '../widgets/auction/auction_widgets.dart';
import '../widgets/content_actions_sheet.dart';
import '../widgets/piece_detail/ask_about_piece_sheet.dart';
import '../widgets/piece_detail/available_collect_bar.dart';
import '../widgets/piece_detail/collect_artist_row.dart';
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/piece_detail/collected_bar.dart';
import '../widgets/piece_detail/manage_auction_sheet.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/piece_action_bar.dart';
import '../widgets/piece_detail/piece_comment_sheet.dart';
import '../widgets/piece_detail/piece_related_scenes_row.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/piece_page_sections.dart';
import '../widgets/piece_detail/piece_series_row.dart';

/// Piece page for a fixed-price piece (`BuyPiece`, `BuyPieceFull`): image with white top
/// icons, artist row, title block, description, Made with, The story behind this piece,
/// Details, series card, and the fixed Price / Collect bar. An auction piece
/// (`BuyPieceScrolled`, `BidLeading`, `BidOutbid`) has the auction bar instead.
///
/// Sold (`PieceCollected*`): no price and no Details; the Collected bar with the message
/// button, or, while it is on its way, the delivery card for the collector (no Save) and the
/// artist ("Your work").
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
  State<AvailablePieceDetailPage> createState() => _AvailablePieceDetailPageState();
}

class _AvailablePieceDetailPageState extends State<AvailablePieceDetailPage>
    with DetailSaveState, DetailLikeState, DetailFollowState {
  late FeedPreviewItem _item;

  @override
  FeedPreviewItem get saveItem => _item;

  @override
  double get saveToastBottomMargin => _barHeight + 16;

  /// The bar's height, for the scroll padding and the save toast.
  double get _barHeight {
    if (_sold) return PieceCollectedBar.totalHeight(context, withCard: _delivery != null);
    final base = AvailableCollectBar.totalHeight(
      context,
      hasInfo: item.isAuction || _priceDisplay != null,
    );
    final reserveNote = item.auction?.hasReserve == true && item.auction?.reserveMet == false;
    return base + (item.isAuction && reserveNote ? 21 : 0);
  }

  /// The viewer's own top bid here, from this phone (`BidStore`).
  int? _myTopBid;

  bool get _sold => item.status == 'sold';

  /// On a sold piece: the viewer's purchase, or as the artist their sale.
  Order? _order;

  PieceDelivery? get _delivery => _order == null
      ? null
      : PieceDelivery.fromOrder(
          _order!,
          forArtist: _isOwner,
          artistName: item.displayName,
        );

  /// The viewer collected this piece.
  bool get _isCollector => _order != null && !_isOwner;

  Future<void> _loadOrder({bool refresh = false}) async {
    if (!_sold || !AuthSession.instance.isLoggedIn) return;
    final order = await findViewerOrder(item.id, asSeller: _isOwner, refresh: refresh);
    if (mounted) setState(() => _order = order);
  }

  Future<void> _messageArtist() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to message',
      message: 'Log in or create a free account to message artists.',
    )) {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadPage(
          otherPartyUsername: _authorHandle,
          otherPartyName: item.displayName,
          otherPartyAvatarUrl: item.authorAvatarUrl,
          // A new chat starts about this piece (BACKEND_CHANGES B9). It is sold: no price.
          aboutPiece: ChatPiece(
            id: item.id,
            title: item.title,
            imageUrl: item.heroImageUrl,
            artistUsername: _authorHandle,
          ),
        ),
      ),
    );
  }

  /// The card's arrow and See shipping steps: the order, with its tracking.
  Future<void> _openOrder() async {
    final order = _order;
    if (order == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailPage(orderId: order.id, isSeller: _isOwner),
      ),
    );
    if (mounted) _loadOrder(refresh: true);
  }

  AuctionBarState get _auctionState => auctionBarState(
    auction: item.auction,
    isOwner: _isOwner,
    myTopBidCents: _myTopBid,
  );

  Future<void> _onAuctionAction() async {
    final auction = item.auction;
    if (auction == null) return;
    switch (_auctionState) {
      case AuctionBarState.open:
      case AuctionBarState.leading:
      case AuctionBarState.outbid:
        final after = await startBidding(context, pieceId: item.id, auction: auction);
        if (after != null && mounted) {
          setState(() => _myTopBid = BidStore.instance.topBidNow(item.id));
          await _loadDetail();
        }
      case AuctionBarState.won:
        await CollectPieceSheet.show(context, item: item, auction: auction);
        if (mounted) _loadDetail();
      case AuctionBarState.paymentFailed:
        await openAuctionOutcome(context, pieceId: item.id, type: 'auction_payment_failed');
        if (mounted) _loadDetail();
      case AuctionBarState.owner:
        // The seller's controls (restored from before commit 76f4ef9).
        final changed = await ManageAuctionSheet.show(context, pieceId: item.id, auction: auction);
        if (changed && mounted) _loadDetail();
      case AuctionBarState.ended:
        break;
    }
  }

  String? get _priceDisplay => item.priceCents == null ? null : formatMoney(item.priceCents!);

  @override
  FeedPreviewItem get likeItem => _item;

  FeedPreviewItem get item => _item;

  String get _authorHandle => item.handle.startsWith('@') ? item.handle.substring(1) : item.handle;

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
    BidStore.instance.topBid(_item.id).then((top) {
      if (mounted && top != null) setState(() => _myTopBid = top);
    });
  }

  Future<void> _loadDetail() async {
    final loaded = await ContentDetailLoader.loadPiece(_item);
    if (!mounted) return;
    setState(() => _item = loaded);
    applySaveItem(loaded);
    applyLikeItem(loaded);
    applyFollowState(loaded);
    if (_order == null) _loadOrder();
  }

  Future<void> _onCollect() async {
    if (!await requireLogin(
      context,
      title: 'Sign in to collect this piece',
      message: 'Log in or create a free account to collect this piece.',
    )) {
      return;
    }
    if (!mounted) return;
    CollectPieceSheet.show(context, item: item);
  }

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

  /// Word on the disabled bar button. Sold shows the Collected chip instead: "Collected
  /// for sold, never Sold" (`HandoffRules`).
  String _statusLabel(String? status) {
    switch (status) {
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
    final c = context.studio;
    final price = _priceDisplay;
    final collectBarHeight = _barHeight;
    final isLive = item.isLive;
    final sold = _sold;
    // A sold page is about the art: no price, no Details (`PieceCollected`).
    final details = sold ? const <(String, String)>[] : PieceDetailsSection.rowsFor(item);

    final sections = <Widget>[
      _padded(PieceTitleBlock(item: item)),
      if (item.story.trim().isNotEmpty) _padded(PieceDescription(item.story)),
      if (item.materials.isNotEmpty) _padded(PieceMadeWith(materials: item.materials)),
      if (item.relatedScenes.isNotEmpty) PieceRelatedScenesRow(scenes: item.relatedScenes),
      if (details.isNotEmpty) _padded(PieceDetailsSection(rows: details)),
      if (item.seriesName.isNotEmpty &&
          (item.seriesThumbUrls.isNotEmpty || item.seriesThumbs.isNotEmpty))
        _padded(
          PieceSeriesRow(
            seriesName: item.seriesName,
            thumbSeeds: item.seriesThumbs,
            thumbUrls: item.seriesThumbUrls,
            pieceCount: item.seriesPieceCount,
            onTap: item.seriesId == null
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SeriesViewPage(
                        seriesId: item.seriesId!,
                        initialName: item.seriesName,
                        initialPieceCount: item.seriesPieceCount,
                        authorName: item.authorName,
                        authorUsername: item.authorUsername,
                        isOwner: _isOwner,
                      ),
                    ),
                  ),
          ),
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the image, like the top icons.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: c.background,
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
                        top: 0,
                        left: 0,
                        right: 0,
                        child: PieceTopIcons(
                          isOwner: _isOwner,
                          showSave: !_isCollector,
                          saved: saved,
                          onBack: () => Navigator.pop(context),
                          onSave: toggleSave,
                          onShare: () => PieceShareSheet.show(
                            context,
                            item,
                            imageIndex: widget.initialImageIndex,
                          ),
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
                        ownerLabel: sold ? 'Your work' : 'Your piece',
                      ),
                      // Like and comment stay on the page (plan rule 4); Save and Share
                      // are in the top icons.
                      PieceActionBar(
                        liked: liked,
                        saved: saved,
                        onLike: toggleLike,
                        onComment: () => PieceCommentSheet.show(
                          context,
                          contentId: item.id,
                          isScene: item.isScene,
                        ),
                        onShare: () {},
                        onSave: toggleSave,
                        showSave: false,
                      ),
                      // "Ask about this piece" (piece-anchored inquiries) is deferred to v2
                      // in favor of general-purpose chat; _onAskAboutPiece stays for then.
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
            if (sold)
              PieceCollectedBar(
                onMessage: _isOwner ? null : _messageArtist,
                delivery: _delivery,
                onLink: _openOrder,
              )
            else if (item.isAuction)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AuctionBar(
                  auction: item.auction,
                  state: _auctionState,
                  onPrimary: _onAuctionAction,
                ),
              )
            else
              AvailableCollectBar(
                priceDisplay: price,
                onCollect: isLive ? _onCollect : null,
                statusLabel: isLive ? null : _statusLabel(item.status),
              ),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);
}

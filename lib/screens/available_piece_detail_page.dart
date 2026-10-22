import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feed_preview_item.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/report_service.dart';
import '../theme/collect_detail_tokens.dart' show formatMoney;
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../utils/content_detail_loader.dart';
import '../utils/require_login.dart';
import 'edit_piece_page.dart';
import '../widgets/content_actions_sheet.dart';
import '../widgets/piece_detail/ask_about_piece_sheet.dart';
import '../widgets/piece_detail/available_collect_bar.dart';
import '../widgets/piece_detail/collect_artist_row.dart';
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/piece_detail/detail_follow_state.dart';
import '../widgets/piece_detail/detail_hero_image.dart';
import '../widgets/piece_detail/detail_save_state.dart';
import '../widgets/piece_detail/detail_scroll_handoff.dart';
import '../widgets/piece_detail/piece_action_bar.dart';
import '../widgets/piece_detail/piece_comment_sheet.dart';
import '../widgets/piece_detail/piece_related_scenes_row.dart';
import '../widgets/piece_detail/piece_share_sheet.dart';
import '../widgets/piece_detail/piece_series_row.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_on_image.dart';

/// Piece page for a fixed-price piece (`BuyPiece`, `BuyPieceFull`): image with white top
/// icons, artist row, title block, description, Made with, The story behind this piece,
/// Details, series card, and the fixed Price / Collect bar.
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
  double get saveToastBottomMargin =>
      AvailableCollectBar.totalHeight(context, hasInfo: _priceDisplay != null) + 16;

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
  }

  Future<void> _loadDetail() async {
    final loaded = await ContentDetailLoader.loadPiece(_item);
    if (!mounted) return;
    setState(() => _item = loaded);
    applySaveItem(loaded);
    applyLikeItem(loaded);
    applyFollowState(loaded);
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
    final collectBarHeight = AvailableCollectBar.totalHeight(context, hasInfo: price != null);
    final isLive = item.isLive;
    final sold = item.status == 'sold';

    final sections = <Widget>[
      _titleBlock(c),
      if (item.story.trim().isNotEmpty)
        _padded(Text(item.story, style: StudioType.sans(16, height: 1.55, color: c.textBody))),
      if (item.materials.isNotEmpty) _padded(_madeWith(c)),
      if (item.relatedScenes.isNotEmpty) PieceRelatedScenesRow(scenes: item.relatedScenes),
      if (_details.isNotEmpty) _padded(_detailsSection(c)),
      if (item.seriesName.isNotEmpty &&
          (item.seriesThumbUrls.isNotEmpty || item.seriesThumbs.isNotEmpty))
        _padded(
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
                        child: StudioTopIconBar(
                          leading: [
                            StudioTopIcon(
                              icon: StudioIcons.back,
                              semanticLabel: 'Back',
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                          trailing: [
                            // Your own piece has no Save (`ListOwnerPiece`).
                            if (!_isOwner)
                              StudioTopIcon(
                                icon: saved ? StudioIcons.saved : StudioIcons.save,
                                semanticLabel: saved ? 'Saved' : 'Save',
                                onTap: toggleSave,
                              ),
                            StudioTopIcon(
                              icon: StudioIcons.share,
                              semanticLabel: 'Share',
                              onTap: () => PieceShareSheet.show(
                                context,
                                item,
                                imageIndex: widget.initialImageIndex,
                              ),
                            ),
                            if (_isOwner)
                              StudioTopIcon(
                                icon: StudioIcons.edit,
                                semanticLabel: 'Edit piece',
                                onTap: _onEdit,
                              )
                            else
                              StudioTopIcon(
                                icon: StudioIcons.more,
                                semanticLabel: 'More',
                                onTap: _onMore,
                              ),
                          ],
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
            AvailableCollectBar(
              priceDisplay: price,
              onCollect: isLive ? _onCollect : null,
              statusLabel: isLive || sold ? null : _statusLabel(item.status),
              collected: sold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

  /// Title 26/500, then the medium and style tags (14 Graphite), then dimensions and year
  /// in Mono 13, 8 apart.
  Widget _titleBlock(StudioColors c) {
    final meta = [
      item.medium,
      ...item.styleTags,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final facts = [
      item.dimensions,
      '${item.year}',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: StudioType.title26(color: c.textPrimary)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta, style: StudioType.body14(color: c.textSecondary)),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(facts, style: StudioType.mono13(color: c.textPrimary)),
          ],
        ],
      ),
    );
  }

  /// "Made with" (D7): 17/500 header, then one row per material name (15, 11 above and
  /// below, 1 px Line under). The piece stores names only, so the brand column and the
  /// MATERIALS / TOOLS labels stay off until the data carries them.
  Widget _madeWith(StudioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Made with', style: StudioType.header17(color: c.textPrimary)),
        const SizedBox(height: 2),
        for (final material in item.materials)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: Text(material, style: StudioType.sans(15, color: c.textPrimary)),
          ),
      ],
    );
  }

  /// Details rows that have data: Framing, Handling, Ships from.
  List<(String, String)> get _details => [
    if ((item.framingNote ?? '').trim().isNotEmpty) ('Framing', item.framingNote!.trim()),
    if ((item.handlingNotes ?? '').trim().isNotEmpty) ('Handling', item.handlingNotes!.trim()),
    if ((item.location ?? '').trim().isNotEmpty) ('Ships from', item.location!.trim()),
  ];

  /// "Details": 17/500 header, rows of label (14 Graphite) and value (14, right aligned),
  /// 16 apart, 11 above and below, 1 px Line under.
  Widget _detailsSection(StudioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Details', style: StudioType.header17(color: c.textPrimary)),
        const SizedBox(height: 2),
        for (final (label, value) in _details)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StudioType.body14(color: c.textSecondary)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: StudioType.body14(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

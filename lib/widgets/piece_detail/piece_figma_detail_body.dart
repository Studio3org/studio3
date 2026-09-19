import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';
import '../follow_button.dart';
import 'auction_bid_bar.dart';
import 'available_collect_bar.dart';
import 'collect_artist_row.dart';
import 'materials_sheet.dart';
import 'piece_details_section.dart';
import 'piece_related_scenes_row.dart';
import 'piece_series_card.dart';

class PieceFigmaDetailBody extends StatelessWidget {
  const PieceFigmaDetailBody({
    super.key,
    required this.item,
    required this.followState,
    required this.followBusy,
    required this.onFollowToggle,
    this.showCollect = false,
    this.collectPrice,
    this.onCollect,
    this.onCompletePurchase,
    this.onFixPayment,
    this.collectStatusLabel,
    this.onPlaceBid,
    this.onMessage,
    this.bottomInset = 0,
  });

  final FeedPreviewItem item;
  final FollowState followState;
  final bool followBusy;
  final VoidCallback onFollowToggle;
  final bool showCollect;
  final String? collectPrice;
  final VoidCallback? onCollect;
  /// The auction winner settling shipping and tax after their payment cleared.
  final VoidCallback? onCompletePurchase;

  /// The auction winner replacing a card that was declined at close.
  final VoidCallback? onFixPayment;

  final String? collectStatusLabel;
  final VoidCallback? onPlaceBid;
  final VoidCallback? onMessage;
  final double bottomInset;

  String get _metaLine {
    final parts = <String>[
      if (item.medium.trim().isNotEmpty) item.medium.trim(),
      ...item.styleTags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hasStory = item.story.trim().isNotEmpty;
    final hasScenes = item.relatedScenes.isNotEmpty;
    final hasSeries =
        item.seriesName.isNotEmpty && item.seriesThumbUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectArtistRow(
          item: item,
          followState: followState,
          followBusy: followBusy,
          onFollowToggle: onFollowToggle,
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CollectDetailTokens.titleHairline,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: PieceDetailType.title,
                  strutStyle: PieceDetailType.titleStrut,
                ),
                if (_metaLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _metaLine,
                    style: PieceDetailType.meta,
                    strutStyle: PieceDetailType.metaStrut,
                  ),
                ],
                if (item.dimensions.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.dimensions,
                    style: PieceDetailType.dimensions,
                    strutStyle: PieceDetailType.metaStrut,
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => showMaterialsSheet(context, item.materials),
                  child: Text(
                    'View Materials →',
                    style: PieceDetailType.materials,
                    strutStyle: PieceDetailType.materialsStrut,
                  ),
                ),
              ],
            ),
          ),
        ),
        PieceDetailsSection(
          year: item.year,
          location: item.location,
          framingNote: item.framingNote,
          shippingRegion: item.shippingRegion,
          handlingNotes: item.handlingNotes,
        ),
        if (hasStory || hasScenes || hasSeries)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasStory)
                  Text(
                    item.story,
                    style: PieceDetailType.story,
                    strutStyle: PieceDetailType.storyStrut,
                  ),
                if (hasScenes) ...[
                  if (hasStory) const SizedBox(height: 32),
                  PieceRelatedScenesRow(
                    scenes: item.relatedScenes,
                    title: 'The story behind this piece',
                    gap: 8,
                    headerPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                    listPadding: const EdgeInsets.only(left: 16),
                  ),
                ],
                if (hasSeries) ...[
                  if (hasStory || hasScenes) const SizedBox(height: 32),
                  PieceSeriesCard(
                    seriesName: item.seriesName,
                    seriesId: item.seriesId,
                    thumbUrls: item.seriesThumbUrls,
                    pieceCount: item.seriesThumbs.isNotEmpty
                        ? item.seriesThumbs.length
                        : item.seriesThumbUrls.length,
                    authorName: item.authorName,
                    authorUsername: item.handle,
                    inset: false,
                  ),
                ],
              ],
            ),
          ),
        if (showCollect && item.isAuction)
          AuctionBidBar(
            // The winning bid once there is one: after a close the highest *active* bid is
            // gone, so falling back to it would show the starting price on a piece that
            // just sold for far more.
            bidDisplay: formatCollectPrice(
              item.auction?.winningBidCents ??
                  item.highestBidCents ??
                  item.priceCents,
            ),
            bidCount: item.bidCount,
            auction: item.auction,
            auctionEndsAt: item.auctionEndsAt,
            onPlaceBid: onPlaceBid,
            onCompletePurchase: onCompletePurchase,
            onFixPayment: onFixPayment,
            statusLabel: collectStatusLabel,
            onMessage: onMessage,
          )
        else if (showCollect && collectPrice != null)
          AvailableCollectBar(
            priceDisplay: collectPrice!,
            onCollect: onCollect,
            statusLabel: collectStatusLabel,
            onMessage: onMessage,
          )
        else
          const SizedBox(height: 24),
        SizedBox(height: bottomInset),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../models/feed_preview_item.dart';
import '../screens/available_piece_detail_page.dart';
import '../screens/piece_detail_page.dart';
import 'reels_route.dart';
import 'slide_up_page_route.dart';

/// Opens a piece on its page, or a Scene (photo or video) in the Scene viewer. [from] is the
/// list it was tapped in, so the viewer swipes through those Scenes in the same order.
Future<void> openExploreDetail(BuildContext context, FeedItem item, {List<FeedItem>? from}) {
  if (item.type == FeedItemType.post) {
    return openScenes(context, item, from: from);
  }

  return openPieceDetailPreview(context, FeedPreviewItem.fromFeedItem(item));
}

/// Pushes the piece/collect detail screen for an already-resolved preview —
/// shared by [openExploreDetail] and deep-link resolution
/// ([DeepLinkService]), which builds its preview from a fetched
/// [PieceSummary] instead of a feed [FeedItem].
Future<void> openPieceDetailPreview(
  BuildContext context,
  FeedPreviewItem preview,
) {
  final page = preview.isAvailable
      ? AvailablePieceDetailPage(item: preview)
      : PieceDetailPage(item: preview);

  return Navigator.of(context).push<void>(
    SlideUpPageRoute<void>(page: page),
  );
}

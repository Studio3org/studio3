import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../share/share_sheet.dart';
import 'detail_share.dart';

/// Piece/scene share menu — thin wrapper around the generic [ShareSheet]
/// carrying the piece's title/story/link as the shared text.
abstract final class PieceShareSheet {
  static Future<void> show(
    BuildContext context,
    FeedPreviewItem item, {
    int imageIndex = 0,
  }) {
    return ShareSheet.show(
      context,
      shareText: buildPieceShareText(item, imageIndex: imageIndex),
    );
  }
}

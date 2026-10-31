import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_link_config.dart';
import '../../models/feed_preview_item.dart';
import '../studio/studio_toast.dart';

String buildPieceShareText(FeedPreviewItem item, {int imageIndex = 0}) {
  final pieceUrl = AppLinkConfig.pieceUrl(item.id);
  final lines = <String>[
    '${item.title} by ${item.displayName} on Studio',
    if (item.story.trim().isNotEmpty) item.story,
    pieceUrl,
  ];
  return lines.join('\n\n');
}

Future<void> shareFeedPreviewItem(
  BuildContext context,
  FeedPreviewItem item, {
  int imageIndex = 0,
}) async {
  await Clipboard.setData(ClipboardData(text: buildPieceShareText(item, imageIndex: imageIndex)));
  if (!context.mounted) return;
  showStudioToast(context, 'Link copied');
}

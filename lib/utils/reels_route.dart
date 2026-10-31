import 'package:flutter/material.dart';

import '../models/feed_item.dart';
import '../screens/reels_page.dart';
import '../services/feed_service.dart';

/// Opens the Scene viewer (`SceneViewer`) full screen over the app, on [items] from
/// [initialIndex]. Swiping up goes to the next one, down to the previous. With no [items] it
/// shows the video Scenes feed.
Future<void> openReels(
  BuildContext context, {
  int initialIndex = 0,
  List<FeedItem>? items,
}) async {
  List<FeedItem> reelsItems = items ?? const [];
  if (reelsItems.isEmpty) {
    final page = await FeedService.instance.getVideoScenes();
    reelsItems = page.items;
  }

  var index = initialIndex;
  if (index < 0 || index >= reelsItems.length) {
    index = 0;
  }

  if (!context.mounted) return;
  // Full screen with its own back arrow (the board), not the shell's Reels page under
  // the floating nav.
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ReelsPage(
        initialIndex: index,
        initialItems: reelsItems,
      ),
    ),
  );
}

/// Opens [item] in the Scene viewer. With [from] (the list it was tapped in) the viewer
/// swipes through that list's Scenes, photo and video, in the same order. Otherwise it is
/// this Scene, then the video Scenes feed.
Future<void> openScenes(
  BuildContext context,
  FeedItem item, {
  List<FeedItem>? from,
}) async {
  var scenes = [
    for (final entry in from ?? const <FeedItem>[])
      if (entry.type == FeedItemType.post) entry,
  ];
  if (!scenes.any((entry) => entry.id == item.id)) {
    var more = const <FeedItem>[];
    try {
      more = (await FeedService.instance.getVideoScenes()).items;
    } catch (_) {
      // Just this Scene, then.
    }
    scenes = [item, ...more.where((entry) => entry.id != item.id)];
  }
  if (!context.mounted) return;
  await openReels(
    context,
    initialIndex: scenes.indexWhere((entry) => entry.id == item.id),
    items: scenes,
  );
}

Future<void> openReelsForItem(BuildContext context, FeedItem item) =>
    openScenes(context, item);

Future<void> openReelsForPosts(
  BuildContext context,
  List<FeedItem> posts,
  FeedItem item,
) =>
    openScenes(context, item, from: posts);

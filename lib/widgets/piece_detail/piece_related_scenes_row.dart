import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../models/feed_preview_item.dart';
import '../../models/post_summary.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../../utils/explore_detail_route.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_on_image.dart';

/// "The story behind this piece" (`BuyPieceFull`): 17/500 header, 12 below it, then
/// Scenes as 130 × 231 cards (radius 12, 10 apart) that scroll sideways to the screen edge.
/// Video length is a plain white image label with a faint shadow, no circle
/// (`HandoffRules` "Top of images"). Hidden when the piece has no linked Scenes.
///
/// Placed full width: the header and first card sit 20 from the left.
class PieceRelatedScenesRow extends StatelessWidget {
  const PieceRelatedScenesRow({
    super.key,
    required this.scenes,
    this.title = 'The story behind this piece',
    this.gap = 12,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 20),
    this.listPadding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<RelatedScene> scenes;

  /// The header, its spacing and padding; the earlier piece body (restored
  /// `PieceFigmaDetailBody`) sets its own.
  final String title;
  final double gap;
  final EdgeInsets headerPadding;
  final EdgeInsets listPadding;

  static const double cardWidth = 130;
  static const double cardHeight = 231;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) return const SizedBox.shrink();
    final c = context.studio;
    // The viewer swipes through these Scenes in this order (it fetches the rest of each).
    final items = [
      for (final scene in scenes)
        if (scene.id != null)
          FeedItem.post(
            PostSummary(id: scene.id!, mediaUrl: scene.mediaUrl, mediaType: scene.mediaType),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: headerPadding,
          child: Text(title, style: StudioType.header17(color: c.textPrimary)),
        ),
        SizedBox(height: gap),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: listPadding,
            itemCount: scenes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final scene = scenes[index];
              final placeholder = ColoredBox(color: c.surface);
              return GestureDetector(
                onTap: scene.id == null
                    ? null
                    : () => openExploreDetail(
                          context,
                          items.firstWhere((item) => item.id == scene.id),
                          from: items,
                        ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (scene.mediaUrl != null && scene.mediaUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: scene.mediaUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => placeholder,
                            errorWidget: (_, _, _) => placeholder,
                          )
                        else
                          placeholder,
                        if (scene.isVideo || scene.duration != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: StudioImageLabel(
                              scene.duration ?? '',
                              icon: scene.isVideo ? StudioIcons.video : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

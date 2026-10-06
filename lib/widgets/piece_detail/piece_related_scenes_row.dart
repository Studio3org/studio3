import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/explore_detail_route.dart';
import '../../models/feed_item.dart';
import '../../models/post_summary.dart';

class PieceRelatedScenesRow extends StatelessWidget {
  const PieceRelatedScenesRow({
    super.key,
    required this.scenes,
  });

  final List<RelatedScene> scenes;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text(
            'Related Scenes · ${scenes.length}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 227,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 19),
            itemCount: scenes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final scene = scenes[index];
              return GestureDetector(
                onTap: scene.id == null
                    ? null
                    : () => openExploreDetail(
                          context,
                          FeedItem.post(
                            PostSummary(
                              id: scene.id!,
                              mediaUrl: scene.mediaUrl,
                              mediaType: scene.mediaType,
                            ),
                          ),
                        ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 128,
                    height: 227,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (scene.mediaUrl != null && scene.mediaUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: scene.mediaUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const _ScenePlaceholder(),
                          )
                        else
                          const _ScenePlaceholder(),
                        if (scene.isVideo)
                          Container(
                            color: Colors.black.withValues(alpha: 0.22),
                            alignment: Alignment.center,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        if (scene.duration != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Text(
                              scene.duration!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
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

class _ScenePlaceholder extends StatelessWidget {
  const _ScenePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(Icons.image_not_supported_outlined,
          color: Colors.grey.shade500),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

class PieceSeriesRow extends StatelessWidget {
  const PieceSeriesRow({
    super.key,
    required this.seriesName,
    this.thumbSeeds = const [],
    this.thumbUrls = const [],
  });

  final String seriesName;
  final List<int> thumbSeeds;
  final List<String> thumbUrls;

  @override
  Widget build(BuildContext context) {
    final urls = thumbUrls.where((url) => url.isNotEmpty).toList();
    final count = urls.isNotEmpty ? urls.length : thumbSeeds.length;
    if (seriesName.isEmpty || count == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text(
            '$seriesName · $count',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 19),
            itemCount: count,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = urls.isNotEmpty ? urls[index] : null;
              return ClipRRect(
                borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
                child: SizedBox(
                  width: 118,
                  height: 118,
                  child: url != null
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const _ThumbPlaceholder(),
                        )
                      : const _ThumbPlaceholder(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(Icons.image_not_supported_outlined,
          color: Colors.grey.shade500),
    );
  }
}

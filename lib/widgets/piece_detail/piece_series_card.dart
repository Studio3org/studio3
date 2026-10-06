import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../screens/series_view_page.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';

/// “Part of a series” — Figma 2707:3591.
class PieceSeriesCard extends StatelessWidget {
  const PieceSeriesCard({
    super.key,
    required this.seriesName,
    this.seriesId,
    this.thumbUrls = const [],
    this.pieceCount,
    this.authorName,
    this.authorUsername,
    this.inset = true,
  });

  final String seriesName;
  final String? seriesId;
  final List<String> thumbUrls;
  final int? pieceCount;
  final String? authorName;
  final String? authorUsername;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final urls = thumbUrls.where((url) => url.isNotEmpty).toList();
    if (seriesName.isEmpty || urls.isEmpty) return const SizedBox.shrink();
    final count = pieceCount ?? urls.length;
    final shown = urls.take(3).toList();
    final stackWidth = 117.0 + (shown.length > 1 ? (shown.length - 1) * 35.0 : 0);

    final card = GestureDetector(
      onTap: seriesId == null || seriesId!.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SeriesViewPage(
                    seriesId: seriesId!,
                    initialName: seriesName,
                    initialPieceCount: count,
                    initialCoverUrl: urls.first,
                    authorName: authorName,
                    authorUsername: authorUsername,
                  ),
                ),
              );
            },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: CollectDetailTokens.hairline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Part of a series',
                style: PieceDetailType.storyHeader,
                strutStyle: PieceDetailType.storyHeaderStrut,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: stackWidth,
                      height: 117,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            Positioned(
                              left: i * 35.0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: i == 0
                                      ? const []
                                      : const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            offset: Offset(2, 0),
                                            blurRadius: 2,
                                          ),
                                        ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 117,
                                    height: 117,
                                    child: CachedNetworkImage(
                                      imageUrl: shown[i],
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          const ColoredBox(
                                        color: Color(0xFFE8E5DF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 16,
                              child: Text(
                                seriesName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PieceDetailType.seriesName,
                                strutStyle: PieceDetailType.artistNameStrut,
                              ),
                            ),
                            Positioned(
                              top: 14,
                              left: 0,
                              right: 0,
                              height: 14,
                              child: Text(
                                '$count ${count == 1 ? 'piece' : 'pieces'}',
                                style: PieceDetailType.seriesCount,
                                strutStyle: PieceDetailType.artistHandleStrut,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: 3.1415926535,
                      child: SvgPicture.asset(
                        'assets/piece/series_chevron.svg',
                        width: 11,
                        height: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!inset) return card;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: card,
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../utils/image_preview_route.dart';
import '../home_feed/home_feed_widgets.dart';

/// Hero image for detail pages — matches feed aspect ratio and carousel index. With 2+
/// photos it pages sideways with the board's dots (`BuyPiece`: 6 px, 5 apart, 14 from the
/// bottom, white and 50 % white).
class DetailHeroImage extends StatefulWidget {
  const DetailHeroImage({super.key, required this.item, this.initialImageIndex = 0});

  final FeedPreviewItem item;
  final int initialImageIndex;

  @override
  State<DetailHeroImage> createState() => _DetailHeroImageState();
}

class _DetailHeroImageState extends State<DetailHeroImage> {
  late final PageController? _pageController;
  int _page = 0;

  FeedPreviewItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    final heroUrl = item.heroImageUrl;
    final useCarousel = (heroUrl == null || heroUrl.isEmpty) && item.imageCount > 1;
    _page = useCarousel ? widget.initialImageIndex.clamp(0, item.imageCount - 1) : 0;
    _pageController = useCarousel ? PageController(initialPage: _page) : null;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroUrl = item.heroImageUrl;
    if (heroUrl != null && heroUrl.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openImagePreview(context, imageUrls: [heroUrl], initialIndex: 0),
        child: FeedPicsumImage(url: heroUrl),
      );
    }

    if (item.imageCount > 1 && _pageController != null) {
      final urls = List.generate(item.imageCount, (i) => feedPreviewImageUrl(item, imageIndex: i));
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: item.imageCount,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openImagePreview(context, imageUrls: urls, initialIndex: index),
                child: FeedPicsumImage(url: urls[index]),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: IgnorePointer(
              child: Semantics(
                label: 'Photo ${_page + 1} of ${item.imageCount}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < item.imageCount; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: i == _page ? 1 : 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final fallbackUrl = feedPreviewImageUrl(item, imageIndex: widget.initialImageIndex);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openImagePreview(context, imageUrls: [fallbackUrl], initialIndex: 0),
      child: FeedPicsumImage(url: fallbackUrl),
    );
  }
}

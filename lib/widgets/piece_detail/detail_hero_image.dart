import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../utils/image_preview_route.dart';
import '../home_feed/home_feed_widgets.dart';

/// Hero image for detail pages — matches feed aspect ratio and carousel index.
class DetailHeroImage extends StatefulWidget {
  const DetailHeroImage({
    super.key,
    required this.item,
    this.initialImageIndex = 0,
    this.onDoubleTap,
  });

  final FeedPreviewItem item;
  final int initialImageIndex;
  final VoidCallback? onDoubleTap;

  @override
  State<DetailHeroImage> createState() => _DetailHeroImageState();
}

class _DetailHeroImageState extends State<DetailHeroImage> {
  late final PageController? _pageController;
  Timer? _singleTapTimer;

  FeedPreviewItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    final useCarousel = item.galleryImageUrls.length > 1;
    _pageController = useCarousel
        ? PageController(initialPage: widget.initialImageIndex.clamp(
            0,
            item.galleryImageUrls.length - 1,
          ))
        : null;
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _onTap(List<String> urls, int index) {
    if (widget.onDoubleTap == null) {
      openImagePreview(context, imageUrls: urls, initialIndex: index);
      return;
    }
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      openImagePreview(context, imageUrls: urls, initialIndex: index);
    });
  }

  void _onDoubleTap() {
    _singleTapTimer?.cancel();
    widget.onDoubleTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // A piece's real gallery (Figma 2716:5774 cover/reorder posting flow)
    // takes priority — only single-image pieces/scenes fall back to the
    // plain heroImageUrl.
    if (item.galleryImageUrls.length > 1 && _pageController != null) {
      final urls = item.galleryImageUrls;
      return PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTap(urls, index),
            onDoubleTap: widget.onDoubleTap == null ? null : _onDoubleTap,
            child: FeedPicsumImage(url: urls[index]),
          );
        },
      );
    }

    final heroUrl = item.heroImageUrl ??
        (item.galleryImageUrls.isNotEmpty ? item.galleryImageUrls.first : null);
    final fallbackUrl = heroUrl ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap([fallbackUrl], 0),
      onDoubleTap: widget.onDoubleTap == null ? null : _onDoubleTap,
      child: FeedPicsumImage(url: fallbackUrl),
    );
  }
}

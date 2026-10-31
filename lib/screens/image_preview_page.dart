import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/studio_colors.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_on_image.dart';

/// Full-screen pinch-to-zoom image viewer.
///
/// No board: Ink in both themes (like the dark edit screens, so the art reads true), the
/// close icon white over the image with the boards' faint shadow and no circle
/// (`HandoffRules` "Top of images").
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({super.key, required this.imageUrls, this.initialIndex = 0});

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController _pageController;
  late double _page;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _page = initial.toDouble();
    _pageController = PageController(initialPage: initial);
    _pageController.addListener(_onPageTick);
  }

  void _onPageTick() {
    final p = _pageController.page;
    if (p != null && mounted) setState(() => _page = p);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageTick);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: StudioColors.ink,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: FeedPicsumImage(url: widget.imageUrls[index], fit: BoxFit.contain),
                );
              },
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 6,
              child: StudioTopIcon(
                icon: StudioIcons.close,
                size: 22,
                semanticLabel: 'Close',
                onTap: () => Navigator.pop(context),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FeedDotIndicators(count: widget.imageUrls.length, page: _page),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

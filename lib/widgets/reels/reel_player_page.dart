import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/feed_item.dart';
import '../../services/post_service.dart';
import '../../theme/studio_colors.dart';
import '../feed_skeleton.dart';
import '../studio/studio_icon.dart';
import 'reel_overlay.dart';

/// Scene sound: off until they turn it on, then on for the rest of the session (`SceneViewer`).
final ValueNotifier<bool> sceneSoundOn = ValueNotifier(false);

/// One Scene in the viewer (`SceneViewer`, `SceneViewerPhoto`).
///
/// Videos play as soon as they are on screen, loop, and pause on a tap. 9:16 media fills the
/// screen; anything else (3:4, square, landscape) sits in the middle at its real shape over a
/// blurred, darker copy of itself, never black bars. A photo Scene with several photos swipes
/// left and right between them, with dots under the photo.
class ReelPlayerPage extends StatefulWidget {
  const ReelPlayerPage({
    super.key,
    required this.item,
    required this.isActive,
    this.bottomInset = 0,
    this.onBack,
  });

  final FeedItem item;
  final bool isActive;

  /// Space kept clear under the controls (the floating nav, when it shows).
  final double bottomInset;
  final VoidCallback? onBack;

  @override
  State<ReelPlayerPage> createState() => _ReelPlayerPageState();
}

class _ReelPlayerPageState extends State<ReelPlayerPage> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  bool _paused = false;
  final ValueNotifier<double> _progress = ValueNotifier(0);
  late FeedItem _item = widget.item;

  bool get _isVideo => _item.isVideo;

  @override
  void initState() {
    super.initState();
    sceneSoundOn.addListener(_applySound);
    _hydrate();
    if (widget.isActive && _isVideo) _initController();
  }

  /// A Scene opened from a short card (a piece page's Related Scenes) has only its id and
  /// picture; the rest (artist, caption, counts, linked piece) comes from the server.
  Future<void> _hydrate() async {
    final post = _item.post;
    if (post == null || post.id.isEmpty) return;
    if (post.authorUsername != null && post.authorUsername!.isNotEmpty) return;
    try {
      final full = await PostService.instance.getById(post.id);
      if (!mounted) return;
      setState(() => _item = FeedItem.post(full));
    } catch (_) {
      // Keep what we have; the picture still shows.
    }
  }

  void _applySound() {
    _controller?.setVolume(sceneSoundOn.value ? 1 : 0);
    if (mounted) setState(() {});
  }

  void _toggleSound() => sceneSoundOn.value = !sceneSoundOn.value;

  void _togglePause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant ReelPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item) {
      _item = widget.item;
      _hydrate();
    }
    if (!_isVideo) return;
    if (widget.isActive && !oldWidget.isActive) {
      _paused = false;
      _initController();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeController();
    }
  }

  @override
  void dispose() {
    sceneSoundOn.removeListener(_applySound);
    _disposeController();
    _progress.dispose();
    super.dispose();
  }

  /// Android Impeller + texture-backed video often produces green macroblock
  /// tearing on MediaTek/Mali devices. Platform views avoid that path.
  static VideoViewType get _viewType {
    if (kIsWeb) return VideoViewType.textureView;
    return Platform.isAndroid
        ? VideoViewType.platformView
        : VideoViewType.textureView;
  }

  Future<void> _initController() async {
    final url = _item.mediaUrl;
    if (url == null || url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    if (_controller != null || _initializing) return;
    setState(() {
      _initializing = true;
      _failed = false;
    });
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: VideoFormat.other,
      viewType: _viewType,
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(sceneSoundOn.value ? 1 : 0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      if (widget.isActive && !_paused) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('ReelPlayerPage: failed to initialize $url — $e');
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    final total = value.duration.inMilliseconds;
    _progress.value = total <= 0 ? 0 : value.position.inMilliseconds / total;
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _initializing = false;
    _progress.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo)
            GestureDetector(
              onTap: _togglePause,
              behavior: HitTestBehavior.opaque,
              child: _buildVideo(),
            )
          else
            ScenePhotos(
              urls: _item.imageUrls,
              aspectRatio: parseSceneAspect(_item.mediaAspectRatio),
            ),
          if (_isVideo && _paused)
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 64,
                  color: Color(0xE6FFFFFF),
                  shadows: [Shadow(color: Color(0x80000000), blurRadius: 6)],
                ),
              ),
            ),
          ReelOverlay(
            item: _item,
            bottomInset: widget.bottomInset,
            soundOn: sceneSoundOn.value,
            onToggleSound: _isVideo ? _toggleSound : null,
            progress: _isVideo ? _progress : null,
            onBack: widget.onBack,
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _controller;
    final poster = _item.thumbnailUrl;
    if (controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      final aspect = size.width == 0 || size.height == 0 ? 9 / 16 : size.width / size.height;
      return SceneMediaFrame(
        aspectRatio: aspect,
        backdrop: poster == null || poster.isEmpty
            ? null
            : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
        child: VideoPlayer(controller),
      );
    }
    if (_failed) {
      return const Center(
        child: StudioIcon(
          StudioIcons.video,
          size: 48,
          color: StudioColors.onDarkSecondary,
          semanticLabel: 'Video unavailable',
        ),
      );
    }
    if (poster != null && poster.isNotEmpty) {
      final aspect = parseSceneAspect(_item.mediaAspectRatio) ?? 9 / 16;
      return SceneMediaFrame(
        aspectRatio: aspect,
        backdrop: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
        child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
      );
    }
    return const ReelSkeleton();
  }
}

/// "3:4" → 0.75. Null when there is no usable ratio.
double? parseSceneAspect(String? ratio) {
  if (ratio == null) return null;
  final parts = ratio.split(RegExp(r'[:/x]'));
  if (parts.length != 2) return double.tryParse(ratio);
  final w = double.tryParse(parts[0].trim());
  final h = double.tryParse(parts[1].trim());
  if (w == null || h == null || w <= 0 || h <= 0) return null;
  return w / h;
}

/// Taller than 3:4 counts as 9:16 and fills the screen.
bool _fillsScreen(double aspect) => aspect < 0.7;

/// Media at its real shape: full screen when it is 9:16, otherwise centred over [backdrop]
/// blurred (28) and darkened (80 % over black, then 25 % black), as `SceneViewerPhoto`.
class SceneMediaFrame extends StatelessWidget {
  const SceneMediaFrame({
    super.key,
    required this.aspectRatio,
    required this.child,
    this.backdrop,
  });

  final double aspectRatio;
  final Widget child;
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    if (_fillsScreen(aspectRatio)) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: aspectRatio * 1000, height: 1000, child: child),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdrop != null)
          Positioned(
            left: -40,
            top: -40,
            right: -40,
            bottom: -40,
            child: Opacity(
              opacity: 0.8,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
                child: backdrop,
              ),
            ),
          ),
        const ColoredBox(color: Color(0x40000000)),
        Center(child: AspectRatio(aspectRatio: aspectRatio, child: child)),
      ],
    );
  }
}

/// A photo Scene: one page per photo, swiped left and right, with 6 dots (white, the rest at
/// 45 %) 16 under the photo when there is more than one.
class ScenePhotos extends StatefulWidget {
  const ScenePhotos({super.key, required this.urls, this.aspectRatio, this.pageBuilder});

  final List<String> urls;

  /// Draws photo [int] in place of loading its URL (stills in tests).
  final Widget Function(BuildContext context, int index)? pageBuilder;

  /// From the Scene (`mediaAspectRatio`); 3:4 when it has none.
  final double? aspectRatio;

  @override
  State<ScenePhotos> createState() => _ScenePhotosState();
}

class _ScenePhotosState extends State<ScenePhotos> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final aspect = widget.aspectRatio ?? 3 / 4;
    if (urls.isEmpty) return const ColoredBox(color: StudioColors.ink);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final photoHeight = _fillsScreen(aspect) ? height : (width / aspect).clamp(0.0, height);
        final dotsTop = (height + photoHeight) / 2 + 16;
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final builder = widget.pageBuilder;
                Widget photo() => builder != null
                    ? builder(context, i)
                    : CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const ColoredBox(color: StudioColors.ink),
                      );
                return SceneMediaFrame(aspectRatio: aspect, backdrop: photo(), child: photo());
              },
            ),
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                top: dotsTop.clamp(0.0, height - 22),
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < urls.length; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index ? StudioColors.galleryWhite : const Color(0x73FFFFFF),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

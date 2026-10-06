import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/feed_item.dart';
import '../feed_skeleton.dart';
import 'reel_overlay.dart';

class ReelPlayerPage extends StatefulWidget {
  const ReelPlayerPage({
    super.key,
    required this.item,
    required this.isActive,
    this.bottomOverlayPadding = 96,
  });

  final FeedItem item;
  final bool isActive;
  final double bottomOverlayPadding;

  @override
  State<ReelPlayerPage> createState() => _ReelPlayerPageState();
}

class _ReelPlayerPageState extends State<ReelPlayerPage> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  final _overlayKey = GlobalKey<ReelOverlayState>();
  bool _showHeart = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initController();
    }
  }

  void _onDoubleTap() {
    _overlayKey.currentState?.likeIfNotAlready();
    setState(() => _showHeart = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  void didUpdateWidget(covariant ReelPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initController();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeController();
    }
  }

  @override
  void dispose() {
    _disposeController();
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
    final url = widget.item.mediaUrl;
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
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      if (widget.isActive) {
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

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _initializing = false;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = _controller!.value.size;
                  final rawAspect = size.width == 0
                      ? 9 / 16
                      : size.width / size.height;

                  // Plain contain-fit at the video's real, original aspect
                  // ratio — no cropping, no forcing into 3:4/16:9. Whatever
                  // doesn't fill the screen on one axis shows as letterbox
                  // bars from the screen's own black background.
                  final screenAspect =
                      constraints.maxWidth / constraints.maxHeight;
                  late final double frameWidth;
                  late final double frameHeight;
                  if (rawAspect > screenAspect) {
                    frameWidth = constraints.maxWidth;
                    frameHeight = frameWidth / rawAspect;
                  } else {
                    frameHeight = constraints.maxHeight;
                    frameWidth = frameHeight * rawAspect;
                  }

                  return Center(
                    child: SizedBox(
                      width: frameWidth,
                      height: frameHeight,
                      child: VideoPlayer(_controller!),
                    ),
                  );
                },
              )
            else if (_failed)
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              )
            else
              const ReelSkeleton(),
            IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showHeart ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedScale(
                    scale: _showHeart ? 1 : 0.6,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),
              ),
            ),
            ReelOverlay(
              key: _overlayKey,
              item: widget.item,
              bottomPadding: widget.bottomOverlayPadding,
              muted: _muted,
              onToggleMute: _toggleMute,
            ),
          ],
        ),
      ),
    );
  }
}

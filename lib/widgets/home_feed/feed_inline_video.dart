import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/feed_item.dart';
import '../../utils/video_view_type.dart';

/// Inline autoplaying video for a scene/post feed card — plays muted once
/// enough of the card is on screen, pauses and frees the decoder once it
/// scrolls away, mirroring [ReelPlayerPage]'s controller lifecycle but
/// driven by scroll visibility instead of a `PageView` index.
class FeedInlineVideoTile extends StatefulWidget {
  const FeedInlineVideoTile({super.key, required this.item});

  final FeedItem item;

  @override
  State<FeedInlineVideoTile> createState() => _FeedInlineVideoTileState();
}

class _FeedInlineVideoTileState extends State<FeedInlineVideoTile> {
  static const _playVisibleFraction = 0.6;
  static const _pauseVisibleFraction = 0.3;

  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  bool _muted = true;
  bool _wantsPlaying = false;

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final fraction = info.visibleFraction;
    if (fraction <= 0) {
      _wantsPlaying = false;
      _disposeController();
      return;
    }
    if (fraction >= _playVisibleFraction) {
      _wantsPlaying = true;
      _initController();
      _controller?.play();
    } else if (fraction < _pauseVisibleFraction) {
      _wantsPlaying = false;
      _controller?.pause();
    }
  }

  Future<void> _initController() async {
    if (_controller != null || _initializing || _failed) return;
    final url = widget.item.mediaUrl;
    if (url == null || url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    _initializing = true;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: VideoFormat.other,
      viewType: resolveVideoViewType(),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || !_wantsPlaying) {
        await controller.dispose();
        _initializing = false;
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initializing = false;
    controller?.pause();
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final controller = _controller;
    final poster = item.thumbnailUrl ?? item.mediaUrl;

    return VisibilityDetector(
      key: ValueKey('feed-video-${item.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (poster != null)
            CachedNetworkImage(
              imageUrl: poster,
              fit: BoxFit.cover,
              errorWidget: (context, error, stackTrace) =>
                  ColoredBox(color: Colors.grey.shade300),
            )
          else
            ColoredBox(color: Colors.grey.shade300),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: _toggleMute,
              behavior: HitTestBehavior.opaque,
              child: MuteToggleButton(muted: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon-on-a-scrim toggle, used for the feed's inline video mute
/// control. Same scrim tone as [_StatusPill] in home_feed_widgets.dart so
/// it stays legible over any footage.
class MuteToggleButton extends StatelessWidget {
  const MuteToggleButton({super.key, required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0x99231F1B),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

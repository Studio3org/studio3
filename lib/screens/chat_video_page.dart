import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_icon.dart';

/// A video message full screen (`Conversation`, BACKEND_CHANGES B11): black, the video at
/// its own shape in the middle, playing with sound as it opens. A tap pauses or plays; at
/// the end the play button shows and a tap watches it again. Close at the top left.
class ChatVideoPage extends StatefulWidget {
  const ChatVideoPage({super.key, required this.url});

  final String url;

  @override
  State<ChatVideoPage> createState() => _ChatVideoPageState();
}

class _ChatVideoPageState extends State<ChatVideoPage> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.initialize().then(
      (_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _ended {
    final value = _controller.value;
    return value.duration > Duration.zero && value.position >= value.duration;
  }

  Future<void> _toggle() async {
    final value = _controller.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) {
      await _controller.pause();
      return;
    }
    if (_ended) await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: value.isPlaying ? 'Pause' : 'Play',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Center(
                  child: _failed
                      ? Text(
                          "Couldn't play this video",
                          style: StudioType.body14(color: StudioColors.galleryWhite),
                        )
                      : value.isInitialized
                      ? AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: VideoPlayer(_controller),
                        )
                      : const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: StudioColors.galleryWhite,
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (value.isInitialized && !value.isPlaying && !_failed)
            const IgnorePointer(
              child: Center(
                child: StudioIcon(StudioIcons.play, size: 48, color: Color(0xE6FFFFFF)),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: StudioIcon(
                        StudioIcons.close,
                        size: 22,
                        color: StudioColors.galleryWhite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

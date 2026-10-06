import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../data/post_media_assets.dart';
import '../theme/home_feed_tokens.dart';

/// Video "edit" step — select which part of the clip to upload (trim) and
/// whether to upload it without audio. Mirrors `PostEditPage`'s crop step
/// for images: full-screen, Close/Next banner, `onNext` bubbles the final
/// (possibly re-encoded) video path back up to `PostPage`.
class PostVideoEditPage extends StatefulWidget {
  const PostVideoEditPage({
    super.key,
    required this.videoPath,
    required this.onClose,
    required this.onNext,
  });

  final String videoPath;
  final VoidCallback onClose;
  final ValueChanged<String> onNext;

  @override
  State<PostVideoEditPage> createState() => _PostVideoEditPageState();
}

class _PostVideoEditPageState extends State<PostVideoEditPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  double _durationMs = 0;
  RangeValues _range = const RangeValues(0, 1);
  bool _muted = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.videoPath));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final durationMs = controller.value.duration.inMilliseconds
          .toDouble()
          .clamp(1.0, double.infinity);
      setState(() {
        _controller = controller;
        _durationMs = durationMs;
        _range = RangeValues(0, durationMs);
      });
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _isTrimmed => _range.start > 0 || _range.end < _durationMs;

  Future<void> _onNextTap() async {
    if (_processing) return;
    if (!_isTrimmed && !_muted) {
      widget.onNext(widget.videoPath);
      return;
    }
    setState(() => _processing = true);
    try {
      var builder = VideoEditorBuilder(videoPath: widget.videoPath);
      if (_isTrimmed) {
        builder = builder.trim(
          startTimeMs: _range.start.round(),
          endTimeMs: _range.end.round(),
        );
      }
      if (_muted) {
        builder = builder.removeAudio();
      }
      final outputPath = await builder.export();
      if (!mounted) return;
      widget.onNext(outputPath ?? widget.videoPath);
    } catch (_) {
      // Best-effort — fall back to the original clip rather than blocking
      // the user from posting at all.
      if (!mounted) return;
      widget.onNext(widget.videoPath);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  static String _formatMs(double ms) {
    final d = Duration(milliseconds: ms.round());
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final ready = _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _VideoEditBanner(
            topInset: topInset,
            onClose: widget.onClose,
            onNext: _onNextTap,
            processing: _processing,
          ),
          Expanded(
            child: Center(
              child: ready
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : _failed
                  ? const Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white54,
                      size: 48,
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          if (ready) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatMs(_range.start),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textInverse,
                    ),
                  ),
                  Text(
                    _formatMs(_range.end),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textInverse,
                    ),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: HomeFeedTokens.textInverse,
                inactiveTrackColor: const Color(0xFF4A4843),
                thumbColor: HomeFeedTokens.textInverse,
                overlayColor: Colors.white24,
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
              ),
              child: RangeSlider(
                min: 0,
                max: _durationMs,
                values: _range,
                onChanged: (values) => setState(() => _range = values),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
            child: Row(
              children: [
                Icon(
                  _muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload without audio',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textInverse,
                    ),
                  ),
                ),
                Switch(
                  value: _muted,
                  onChanged: (value) => setState(() => _muted = value),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoEditBanner extends StatelessWidget {
  const _VideoEditBanner({
    required this.topInset,
    required this.onClose,
    required this.onNext,
    required this.processing,
  });

  static const _bannerHeight = 64.0;
  static const _neutral300 = Color(0xFFC8C5BC);

  final double topInset;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _bannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    PostMediaAssets.closeIcon,
                    width: 14,
                    height: 14,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Trim',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: HomeFeedTokens.textInverse,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: processing ? null : onNext,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 76,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _neutral300,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Next',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: HomeFeedTokens.textPrimary,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

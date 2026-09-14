import 'dart:io';
import 'dart:typed_data';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../theme/home_feed_tokens.dart';
import '../widgets/create_flow/scene_video_tracks.dart';

/// Scene video Edit (Figma 2761:12111) — trim + mute, then Next.
class SceneVideoEditPage extends StatefulWidget {
  const SceneVideoEditPage({
    super.key,
    required this.videoPath,
    required this.onBack,
    required this.onNext,
  });

  final String videoPath;
  final VoidCallback onBack;
  final void Function(String videoPath, Uint8List? thumbnail) onNext;

  @override
  State<SceneVideoEditPage> createState() => _SceneVideoEditPageState();
}

class _SceneVideoEditPageState extends State<SceneVideoEditPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _muted = false;
  bool _processing = false;
  double _start = 0;
  double _end = 1;

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
      setState(() => _controller = controller);
      controller.addListener(_onTick);
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final start = Duration(
      milliseconds: (_start * duration.inMilliseconds).round(),
    );
    final end = Duration(
      milliseconds: (_end * duration.inMilliseconds).round(),
    );
    final pos = controller.value.position;
    if (pos + const Duration(milliseconds: 80) < start) {
      controller.seekTo(start);
    } else if (pos >= end) {
      controller.seekTo(start);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Duration get _duration => _controller?.value.duration ?? Duration.zero;

  bool get _isTrimmed => _start > 0.002 || _end < 0.998;

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _onNext() async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller?.pause();
    var path = widget.videoPath;
    try {
      if (_isTrimmed || _muted) {
        var builder = VideoEditorBuilder(videoPath: widget.videoPath);
        if (_isTrimmed && _duration.inMilliseconds > 0) {
          builder = builder.trim(
            startTimeMs: (_start * _duration.inMilliseconds).round(),
            endTimeMs: (_end * _duration.inMilliseconds).round(),
          );
        }
        if (_muted) builder = builder.removeAudio();
        path = await builder.export() ?? widget.videoPath;
      }
    } catch (_) {
      path = widget.videoPath;
    }

    Uint8List? thumb;
    try {
      final timeMs = _isTrimmed && path == widget.videoPath
          ? (_start * _duration.inMilliseconds).round()
          : 0;
      thumb = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 80,
        timeMs: timeMs,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _processing = false);
    widget.onNext(path, thumb);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final pos = ready ? controller.value.position : Duration.zero;
    final total = ready ? controller.value.duration : Duration.zero;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          SceneVideoFlowBanner(
            topInset: topInset,
            title: 'Edit',
            actionLabel: 'Next',
            onBack: widget.onBack,
            onAction: _processing ? null : _onNext,
            processing: _processing,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 36, 24, bottomInset + 16),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: const Color(0xFF4A4843),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ready)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: controller.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              )
                            else
                              Center(
                                child: _failed
                                    ? const Icon(
                                        Icons.videocam_off_outlined,
                                        color: HomeFeedTokens.textSecondary,
                                        size: 48,
                                      )
                                    : const CircularProgressIndicator(
                                        color: HomeFeedTokens.textSecondary,
                                      ),
                              ),
                            if (ready)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x4D231F1B),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Text(
                                    '${_format(pos)}/${_format(total)}',
                                    style: GoogleFonts.geist(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: HomeFeedTokens.textInverse,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drag the edges to trim',
                          style: GoogleFonts.geist(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SceneVideoTrimTrack(
                          startFraction: _start,
                          endFraction: _end,
                          onChanged: (start, end) {
                            setState(() {
                              _start = start;
                              _end = end;
                            });
                            if (ready) {
                              controller.seekTo(
                                Duration(
                                  milliseconds:
                                      (start * _duration.inMilliseconds)
                                          .round(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Row(
                      children: [
                        Text(
                          'Mute audio',
                          style: GoogleFonts.geist(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HomeFeedTokens.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        SceneVideoMuteSwitch(
                          value: _muted,
                          onChanged: (value) async {
                            setState(() => _muted = value);
                            await controller?.setVolume(value ? 0 : 1);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

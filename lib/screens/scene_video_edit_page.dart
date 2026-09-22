import 'dart:io';
import 'dart:typed_data';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart';
import '../widgets/create_flow/scene_video_tracks.dart';
import '../theme/app_fonts.dart';

/// Scene video Edit (Figma 2761:12111) — size, trim + mute, then Next.
///
/// [CropAspectRatio] is reused from the image editor rather than a video-specific type: the
/// four choices are the same four the home feed already knows how to size a tile against
/// (`ImageAspectRatioResolver`), so a video posted at, say, 1:1 renders at 1:1 in the feed
/// the same way an image posted at 1:1 does — one vocabulary for "what size was this posted
/// at", not two.
class SceneVideoEditPage extends StatefulWidget {
  const SceneVideoEditPage({
    super.key,
    required this.videoPath,
    required this.onBack,
    required this.onNext,
  });

  final String videoPath;
  final VoidCallback onBack;

  /// [aspectRatio] is the frame the video was actually cropped to — carried back so the
  /// posting flow can record it as `mediaAspectRatio`, same as an image scene's crop choice.
  /// Null when the export failed and the original, uncropped clip is being posted instead —
  /// claiming a frame the file was never actually cropped to would size the feed tile wrong.
  final void Function(
    String videoPath,
    Uint8List? thumbnail,
    CropAspectRatio? aspectRatio,
  ) onNext;

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
  CropAspectRatio _aspectRatio = CropAspectRatio.ratio9x16;

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

  /// The library's own enum for the same four ratios [CropAspectRatio] already covers —
  /// kept as a lookup here rather than merging the two types, since one belongs to the
  /// posting/feed vocabulary and the other to this one export call.
  VideoAspectRatio get _videoAspectRatio => switch (_aspectRatio) {
        CropAspectRatio.ratio16x9 => VideoAspectRatio.ratio16x9,
        CropAspectRatio.ratio9x16 => VideoAspectRatio.ratio9x16,
        CropAspectRatio.ratio3x4 => VideoAspectRatio.ratio3x4,
        CropAspectRatio.ratio1x1 => VideoAspectRatio.ratio1x1,
      };

  Future<void> _onNext() async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller?.pause();
    // Cropped every time, not just when it differs from the source clip's own shape — the
    // point of this step is that the poster chose a frame, and the uploaded file should
    // actually be that frame rather than whatever the camera happened to record.
    var path = widget.videoPath;
    var cropped = false;
    try {
      var builder = VideoEditorBuilder(videoPath: widget.videoPath)
          .crop(aspectRatio: _videoAspectRatio);
      if (_isTrimmed && _duration.inMilliseconds > 0) {
        builder = builder.trim(
          startTimeMs: (_start * _duration.inMilliseconds).round(),
          endTimeMs: (_end * _duration.inMilliseconds).round(),
        );
      }
      if (_muted) builder = builder.removeAudio();
      final exported = await builder.export();
      if (exported != null) {
        path = exported;
        cropped = true;
      }
    } catch (_) {
      // The crop/trim/mute pipeline failed end to end — post the original clip rather than
      // block the flow entirely. It goes up at its native shape; mediaAspectRatio is only
      // sent when the export we're about to trust actually produced the chosen frame.
      path = widget.videoPath;
      cropped = false;
    }

    Uint8List? thumb;
    try {
      final timeMs = _isTrimmed && !cropped
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
    widget.onNext(path, thumb, cropped ? _aspectRatio : null);
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
                    // Framed to the chosen size rather than filling whatever space is
                    // left — this preview is what "Size" is actually choosing, so it has
                    // to change shape when a chip is tapped, the same as the image
                    // editor's own frame does.
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _aspectRatio.value,
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
                                        style: AppFonts.geist(
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Size',
                          style: AppFonts.geist(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _SizeChipRow(
                          selected: _aspectRatio,
                          onChanged: (ratio) =>
                              setState(() => _aspectRatio = ratio),
                        ),
                      ],
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
                          style: AppFonts.geist(
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
                          style: AppFonts.geist(
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

/// The four size choices, styled to match the image editor's own aspect chips
/// ([_AspectChip] in scene_edit_page.dart) — a private widget there, so this is its video
/// equivalent rather than a shared import.
class _SizeChipRow extends StatelessWidget {
  const _SizeChipRow({required this.selected, required this.onChanged});

  final CropAspectRatio selected;
  final ValueChanged<CropAspectRatio> onChanged;

  static const _ratios = [
    CropAspectRatio.ratio16x9,
    CropAspectRatio.ratio9x16,
    CropAspectRatio.ratio3x4,
    CropAspectRatio.ratio1x1,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final ratio in _ratios) ...[
          if (ratio != _ratios.first) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(ratio),
              child: Container(
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == ratio
                      ? HomeFeedTokens.textPrimary
                      : const Color(0xFF3A3733),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (ratio) {
                    CropAspectRatio.ratio16x9 => '16:9',
                    CropAspectRatio.ratio9x16 => '9:16',
                    CropAspectRatio.ratio3x4 => '3:4',
                    CropAspectRatio.ratio1x1 => '1:1',
                  },
                  style: AppFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected == ratio
                        ? HomeFeedTokens.textInverse
                        : HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

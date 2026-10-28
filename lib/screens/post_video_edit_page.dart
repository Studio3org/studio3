import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_icon.dart';

/// The longest Scene video. The note calls 1:00 a placeholder until the real cap is set.
const kSceneMaxVideo = Duration(minutes: 1);

/// What the video steps hand on: the (possibly trimmed and muted) clip, its length and the
/// cover frame.
class SceneVideoResult {
  const SceneVideoResult({
    required this.path,
    required this.length,
    this.cover,
  });

  final String path;
  final Duration length;
  final Uint8List? cover;
}

enum _VideoStep { trim, cover }

/// Scene video steps, dark in both themes: trim (`SceneTrim`) then cover (`SceneCover`).
///
/// Trim: the clip 250 wide at 9:16 (radius 16, play mark), "Drag the ends to trim" with the
/// kept length over the cap in Mono, a filmstrip with a Gallery White bracket, Mute audio.
/// Cover: the chosen frame large, a filmstrip with a frame window to scrub, how it looks
/// full screen, on a shelf, square and landscape, and "Upload a cover instead".
class PostVideoEditPage extends StatefulWidget {
  const PostVideoEditPage({
    super.key,
    required this.videoPath,
    required this.onClose,
    required this.onNext,
    this.initialCover,
    this.debugDurationMs,
  });

  final String videoPath;

  /// Back from the first step (to the gallery).
  final VoidCallback onClose;
  final ValueChanged<SceneVideoResult> onNext;

  /// The frame captured when the clip was picked; the cover until another is chosen.
  final Uint8List? initialCover;

  /// Skips the player and uses this length, for tests.
  @visibleForTesting
  final double? debugDurationMs;

  @override
  State<PostVideoEditPage> createState() => _PostVideoEditPageState();
}

class _PostVideoEditPageState extends State<PostVideoEditPage> {
  static const _strip = 8;

  VideoPlayerController? _controller;
  bool _failed = false;
  double _durationMs = 0;
  RangeValues _range = const RangeValues(0, 1);
  bool _muted = false;
  bool _processing = false;
  _VideoStep _step = _VideoStep.trim;
  List<Uint8List?> _frames = const [];

  /// Where the cover frame sits, 0–1 across the kept part.
  double _coverAt = 0;
  Uint8List? _cover;
  Timer? _coverDebounce;
  bool _uploadedCover = false;

  @override
  void initState() {
    super.initState();
    _cover = widget.initialCover;
    final debug = widget.debugDurationMs;
    if (debug != null) {
      _durationMs = debug;
      _range = RangeValues(
        0,
        math.min(debug, kSceneMaxVideo.inMilliseconds.toDouble()),
      );
      _frames = List.filled(_strip, null);
    } else {
      _init();
    }
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
        _range = RangeValues(
          0,
          math.min(durationMs, kSceneMaxVideo.inMilliseconds.toDouble()),
        );
        _frames = List.filled(_strip, null);
      });
      await controller.setLooping(true);
      await controller.play();
      _loadFrames();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Evenly spaced frames for the filmstrip; missing ones stay as dark tiles.
  Future<void> _loadFrames() async {
    final builder = VideoEditorBuilder(videoPath: widget.videoPath);
    for (var i = 0; i < _strip; i++) {
      final at = (_durationMs * (i + 0.5) / _strip).round();
      try {
        final path = await builder.generateThumbnail(
          positionMs: at,
          quality: 60,
          height: 120,
        );
        if (path == null || !mounted) continue;
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        setState(() => _frames = [..._frames]..[i] = bytes);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _coverDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  bool get _isTrimmed => _range.start > 0 || _range.end < _durationMs;
  double get _coverMs => _range.start + (_range.end - _range.start) * _coverAt;

  // ---------------------------------------------------------------- trim

  /// Keeps the kept part between 1 s and the cap, moving the other end when needed.
  void _setRange(double start, double end, {required bool movingStart}) {
    final cap = kSceneMaxVideo.inMilliseconds.toDouble();
    start = start.clamp(0, _durationMs);
    end = end.clamp(0, _durationMs);
    if (end - start < 1000) {
      if (movingStart) {
        start = math.max(0, end - 1000);
      } else {
        end = math.min(_durationMs, start + 1000);
      }
    }
    if (end - start > cap) {
      if (movingStart) {
        end = start + cap;
      } else {
        start = end - cap;
      }
    }
    setState(() => _range = RangeValues(start, end));
    _controller?.seekTo(
      Duration(milliseconds: (movingStart ? start : end).round()),
    );
  }

  // ---------------------------------------------------------------- cover

  void _setCoverAt(double t) {
    setState(() {
      _coverAt = t.clamp(0.0, 1.0);
      _uploadedCover = false;
    });
    _controller?.seekTo(Duration(milliseconds: _coverMs.round()));
    _coverDebounce?.cancel();
    _coverDebounce = Timer(const Duration(milliseconds: 250), _grabCover);
  }

  Future<void> _grabCover() async {
    try {
      final path = await VideoEditorBuilder(videoPath: widget.videoPath)
          .generateThumbnail(
            positionMs: _coverMs.round(),
            quality: 85,
            height: 1280,
            exactFrame: true,
          );
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (mounted && !_uploadedCover) setState(() => _cover = bytes);
    } catch (_) {}
  }

  Future<void> _uploadCover() async {
    try {
      // imageQuality re-encodes to JPEG, the type the cover is uploaded as.
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _cover = bytes;
        _uploadedCover = true;
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------- next

  void _back() {
    if (_step == _VideoStep.cover) {
      setState(() => _step = _VideoStep.trim);
      return;
    }
    widget.onClose();
  }

  Future<void> _next() async {
    if (_step == _VideoStep.trim) {
      setState(() => _step = _VideoStep.cover);
      // Start on the first kept frame at full size (the pick-time frame is a square crop),
      // unless a cover was uploaded.
      if (!_uploadedCover) _setCoverAt(0);
      return;
    }
    if (_processing) return;
    final length = Duration(milliseconds: (_range.end - _range.start).round());
    if (!_isTrimmed && !_muted) {
      widget.onNext(
        SceneVideoResult(path: widget.videoPath, length: length, cover: _cover),
      );
      return;
    }
    setState(() => _processing = true);
    String? output;
    try {
      var builder = VideoEditorBuilder(videoPath: widget.videoPath);
      if (_isTrimmed) {
        builder = builder.trim(
          startTimeMs: _range.start.round(),
          endTimeMs: _range.end.round(),
        );
      }
      if (_muted) builder = builder.removeAudio();
      output = await builder.export();
    } catch (_) {
      // Best effort: post the original clip rather than block posting.
    }
    if (!mounted) return;
    setState(() => _processing = false);
    widget.onNext(
      SceneVideoResult(
        path: output ?? widget.videoPath,
        length: length,
        cover: _cover,
      ),
    );
  }

  static String _format(double ms) {
    final d = Duration(milliseconds: ms.round());
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: StudioColors.ink,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  title: _step == _VideoStep.trim ? 'Edit' : 'Set a cover',
                  onBack: _back,
                  onNext: _next,
                  busy: _processing,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      math.max(24, mq.padding.bottom),
                    ),
                    child: _step == _VideoStep.trim
                        ? _buildTrim()
                        : _buildCover(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _player({required double width, required double height}) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: const Color(0xFF1C1C1C),
          child: ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              : _failed
              ? Center(
                  child: Text(
                    "Couldn't play this video",
                    style: StudioType.label13(
                      color: StudioColors.onDarkSecondary,
                    ),
                  ),
                )
              : _cover != null
              ? Image.memory(_cover!, fit: BoxFit.cover)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildTrim() {
    final kept = _range.end - _range.start;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _player(width: 250, height: 444),
              Semantics(
                button: true,
                label: 'Play or pause',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    final c = _controller;
                    if (c == null) return;
                    setState(() => c.value.isPlaying ? c.pause() : c.play());
                  },
                  child: const StudioIcon(
                    StudioIcons.video,
                    size: 22,
                    color: StudioColors.galleryWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Drag the ends to trim',
                style: StudioType.sans(15, color: StudioColors.onDarkSecondary),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _format(kept),
                    style: StudioType.mono(
                      15,
                      color: StudioColors.galleryWhite,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' / ${_format(kSceneMaxVideo.inMilliseconds.toDouble())}',
                    style: StudioType.mono(15, color: StudioColors.onDarkTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TrimStrip(
          frames: _frames,
          start: _durationMs == 0 ? 0 : _range.start / _durationMs,
          end: _durationMs == 0 ? 1 : _range.end / _durationMs,
          onStart: (t) =>
              _setRange(t * _durationMs, _range.end, movingStart: true),
          onEnd: (t) =>
              _setRange(_range.start, t * _durationMs, movingStart: false),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Mute audio',
                style: StudioType.sans(17, color: StudioColors.galleryWhite),
              ),
            ),
            _DarkSwitch(
              value: _muted,
              onChanged: (v) => setState(() => _muted = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCover() {
    final cover = _cover;
    Widget preview(double w, double h, String label) => Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: w,
            height: h,
            child: cover == null
                ? const ColoredBox(color: Color(0xFF1C1C1C))
                : Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: StudioType.caption12(color: StudioColors.onDarkSecondary),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 220,
              height: 390,
              child: _uploadedCover && cover != null
                  ? Image.memory(cover, fit: BoxFit.cover)
                  : _player(width: 220, height: 390),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _CoverStrip(frames: _frames, at: _coverAt, onChanged: _setCoverAt),
        const SizedBox(height: 22),
        Text(
          "How it'll look around the app",
          style: StudioType.sans(13, color: StudioColors.onDarkSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            preview(54, 96, 'Full screen'),
            preview(54, 96, 'Shelf'),
            preview(80, 80, 'Square'),
            preview(100, 75, 'Landscape'),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: _uploadCover,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Center(
                  child: Text(
                    'Upload a cover instead',
                    style: StudioType.sans(
                      15,
                      weight: StudioType.medium,
                      color: StudioColors.onDarkSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Back 22 / title 16/500 centred / Next 15/500, all Gallery White (12 8 padding).
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.onNext,
    required this.busy,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.square(
                  dimension: StudioSize.tapTarget,
                  child: Center(
                    child: StudioIcon(
                      StudioIcons.backBold,
                      size: 22,
                      color: StudioColors.galleryWhite,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: StudioType.sans(
                  16,
                  weight: StudioType.medium,
                  color: StudioColors.galleryWhite,
                ),
              ),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: busy ? null : onNext,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Center(
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: StudioColors.galleryWhite,
                            ),
                          )
                        : Text(
                            'Next',
                            style: StudioType.sans(
                              15,
                              weight: StudioType.medium,
                              color: StudioColors.galleryWhite,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The filmstrip frames, 52 tall, radius 10, dark tiles where a frame isn't ready.
class _Frames extends StatelessWidget {
  const _Frames({required this.frames});

  final List<Uint8List?> frames;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          for (var i = 0; i < frames.length; i++)
            Expanded(
              child: frames[i] == null
                  ? SizedBox.expand(
                      child: ColoredBox(
                        color: Color(i.isEven ? 0xFF2A2826 : 0xFF33302D),
                      ),
                    )
                  : Image.memory(
                      frames[i]!,
                      fit: BoxFit.cover,
                      height: 52,
                      gaplessPlayback: true,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Trim strip (`SceneTrim`): outside the kept part dimmed, a Gallery White bracket (3 px
/// top and bottom, 10-wide ends) around it; drag either end.
class _TrimStrip extends StatelessWidget {
  const _TrimStrip({
    required this.frames,
    required this.start,
    required this.end,
    required this.onStart,
    required this.onEnd,
  });

  final List<Uint8List?> frames;
  final double start;
  final double end;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final left = start * w;
        final right = end * w;
        Widget handle(double x, ValueChanged<double> onDrag, String label) =>
            Positioned(
              // Kept inside the strip so the ends stay touchable at the edges.
              left: (x - 22).clamp(0.0, math.max(0.0, w - 44)),
              top: 0,
              bottom: 0,
              width: 44,
              child: Semantics(
                label: label,
                slider: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) =>
                      onDrag(((x + d.delta.dx) / w).clamp(0.0, 1.0)),
                ),
              ),
            );
        return SizedBox(
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _Frames(frames: frames)),
              Positioned(
                left: 0,
                width: left,
                top: 0,
                bottom: 0,
                child: const ColoredBox(color: Color(0xB3111111)),
              ),
              Positioned(
                left: right,
                right: 0,
                top: 0,
                bottom: 0,
                child: const ColoredBox(color: Color(0xB3111111)),
              ),
              Positioned(
                left: left,
                width: math.max(20, right - left),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: const Border.symmetric(
                        horizontal: BorderSide(
                          color: StudioColors.galleryWhite,
                          width: 3,
                        ),
                        vertical: BorderSide(
                          color: StudioColors.galleryWhite,
                          width: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              handle(left, onStart, 'Trim start'),
              handle(right, onEnd, 'Trim end'),
            ],
          ),
        );
      },
    );
  }
}

/// Cover strip (`SceneCover`): a 32-wide frame window (2 px Gallery White, radius 6) to drag
/// or tap along the frames.
class _CoverStrip extends StatelessWidget {
  const _CoverStrip({
    required this.frames,
    required this.at,
    required this.onChanged,
  });

  final List<Uint8List?> frames;
  final double at;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        void update(Offset p) => onChanged((p.dx - 16) / math.max(1, w - 32));
        return Semantics(
          slider: true,
          label: 'Cover frame',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => update(d.localPosition),
            onHorizontalDragUpdate: (d) => update(d.localPosition),
            child: SizedBox(
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _Frames(frames: frames)),
                  Positioned(
                    left: at * (w - 32),
                    top: 0,
                    bottom: 0,
                    width: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x33FAFAF8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: StudioColors.galleryWhite,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Switch on Ink: 44 × 26 track (#3A3A3A off, Gallery White on), 20 knob (Gallery White off,
/// Ink on).
class _DarkSwitch extends StatelessWidget {
  const _DarkSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Mute audio',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: StudioMotion.quick,
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? StudioColors.galleryWhite : const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(StudioRadius.round),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? StudioColors.ink : StudioColors.galleryWhite,
            ),
          ),
        ),
      ),
    );
  }
}

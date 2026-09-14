import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../services/permission_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/create_flow/create_flow_widgets.dart';
import '../widgets/create_flow/scene_video_tracks.dart';
import '../widgets/permission_denied_sheet.dart';

/// Scene video Set a cover (Figma 2761:12262).
class SceneSetCoverPage extends StatefulWidget {
  const SceneSetCoverPage({
    super.key,
    required this.videoPath,
    this.initialCoverBytes,
  });

  final String videoPath;
  final Uint8List? initialCoverBytes;

  static Future<Uint8List?> show(
    BuildContext context, {
    required String videoPath,
    Uint8List? initialCoverBytes,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SceneSetCoverPage(
          videoPath: videoPath,
          initialCoverBytes: initialCoverBytes,
        ),
      ),
    );
  }

  @override
  State<SceneSetCoverPage> createState() => _SceneSetCoverPageState();
}

class _SceneSetCoverPageState extends State<SceneSetCoverPage> {
  VideoPlayerController? _controller;
  Uint8List? _uploadedBytes;
  double _fraction = 0;
  bool _saving = false;

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
      await controller.pause();
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _seekTo(double fraction) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      _fraction = fraction;
      _uploadedBytes = null;
    });
    final ms = (fraction * controller.value.duration.inMilliseconds).round();
    await controller.seekTo(Duration(milliseconds: ms));
  }

  Future<void> _uploadImage() async {
    final outcome = await PermissionService.instance.requestGalleryAccess(
      forVideo: false,
    );
    if (outcome == GalleryPermissionOutcome.deniedForever) {
      if (!mounted) return;
      await showPermissionDeniedSheet(
        context,
        title: 'Photo access needed',
        message: 'Enable photo library access in Settings to upload a cover.',
      );
      return;
    }
    if (outcome == GalleryPermissionOutcome.denied) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _uploadedBytes = bytes);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    Uint8List? bytes = _uploadedBytes;
    if (bytes == null) {
      final controller = _controller;
      final timeMs = controller != null && controller.value.isInitialized
          ? (_fraction * controller.value.duration.inMilliseconds).round()
          : 0;
      try {
        bytes = await VideoThumbnail.thumbnailData(
          video: widget.videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 1080,
          quality: 85,
          timeMs: timeMs,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pop(context, bytes ?? widget.initialCoverBytes);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          SceneVideoFlowBanner(
            topInset: topInset,
            title: 'Set a cover',
            actionLabel: 'Save',
            onBack: () => Navigator.pop(context),
            onAction: _saving ? null : _save,
            processing: _saving,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 36, 24, bottomInset + 16),
              child: Column(
                children: [
                  SizedBox(
                    width: 300,
                    height: 533,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const Color(0xFF4A4843),
                            child: _uploadedBytes != null
                                ? Image.memory(
                                    _uploadedBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : ready
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: controller.value.size.width,
                                      height: controller.value.size.height,
                                      child: VideoPlayer(controller),
                                    ),
                                  )
                                : widget.initialCoverBytes != null
                                ? Image.memory(
                                    widget.initialCoverBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
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
                                'Cover',
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drag to pick a frame',
                          style: GoogleFonts.geist(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SceneVideoPlayheadTrack(
                          fraction: _fraction,
                          onChanged: _seekTo,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '- or -',
                    style: GoogleFonts.geist(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CreateFlowBottomButton(
                    label: 'Upload cover image',
                    height: 40,
                    backgroundColor: HomeFeedTokens.neutral800,
                    textColor: HomeFeedTokens.textInverse,
                    onTap: _uploadImage,
                    child: Text(
                      'Upload cover image',
                      style: GoogleFonts.geist(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: HomeFeedTokens.textInverse,
                      ),
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

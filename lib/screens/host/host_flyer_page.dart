import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/post_image_transform.dart';
import '../../utils/crop_cover_math.dart';
import '../../widgets/permission_denied_sheet.dart';
import '../../widgets/post_crop_preview.dart';
import '../../widgets/post_gallery/post_gallery_picker.dart';
import '../../widgets/post_gallery/posting_banner.dart';
import '../../widgets/studio/studio.dart';
import '../post_cover_page.dart' show CoverThirdsGrid;

/// The picked flyer: the photo and how it is framed at 3:4.
typedef HostFlyer = ({String path, PostImageTransform transform});

/// Event cover (`HostFlyer`): pick one photo from the library, then frame it on the dark cover
/// screen — a 3:4 frame with a faint grid, drag and pinch, no colour edits (every event image is
/// 3:4). Cancel leaves; Done returns the framing; "Choose a different image" goes back to the
/// library.
class HostFlyerPage extends StatefulWidget {
  const HostFlyerPage({super.key, this.initial});

  /// Reframe a flyer already picked.
  final HostFlyer? initial;

  static Future<HostFlyer?> open(BuildContext context, {HostFlyer? initial}) {
    return Navigator.of(context).push<HostFlyer>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => HostFlyerPage(initial: initial)),
    );
  }

  @override
  State<HostFlyerPage> createState() => _HostFlyerPageState();
}

class _HostFlyerPageState extends State<HostFlyerPage> {
  final _albumOpen = ValueNotifier(false);
  String _album = 'Recents';
  List<AssetEntity> _picked = const [];

  String? _path;
  PostImageTransform _transform = PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4);
  double _aspect = 1;
  Rect? _startBox;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) _frame(i.path, i.transform.copy());
  }

  @override
  void dispose() {
    _albumOpen.dispose();
    super.dispose();
  }

  void _frame(String path, PostImageTransform transform) {
    transform
      ..aspectRatio = CropAspectRatio.ratio3x4
      ..fitMode = CropFitMode.fill
      ..rotationDegrees = 0
      ..flipHorizontal = false
      ..flipVertical = false
      ..resetAdjust();
    setState(() {
      _path = path;
      _transform = transform;
    });
    _loadAspect(path);
  }

  Future<void> _loadAspect(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
      final image = (await codec.getNextFrame()).image;
      if (mounted && image.height > 0) setState(() => _aspect = image.width / image.height);
    } catch (_) {}
  }

  Future<void> _usePicked() async {
    if (_picked.isEmpty) return;
    final file = await _picked.first.file;
    if (file == null || !mounted) return;
    _frame(file.path, PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4));
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size frame) {
    final start = _startBox;
    if (start == null) return;
    final delta = details.localFocalPoint - _startFocal;
    final panned = CropCoverMath.translateBox(
      box: start,
      deltaNorm: -Offset(
        frame.width == 0 ? 0 : delta.dx / frame.width * start.width,
        frame.height == 0 ? 0 : delta.dy / frame.height * start.height,
      ),
    );
    final scaled = CropCoverMath.scaleBox(
      box: panned,
      scaleFactor: details.scale,
      cropAspect: CropAspectRatio.ratio3x4.value,
      imageAspect: _aspect,
    );
    setState(() => _transform.cropRect = scaled);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return path == null ? _gallery() : _framing(path);
  }

  Widget _gallery() {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.studio.background,
      body: Stack(
        children: [
          Positioned(
            top: top + PostingBanner.height,
            left: 0,
            right: 0,
            bottom: 0,
            child: PostGalleryPicker(
              openNotifier: _albumOpen,
              onDark: true,
              maxSelection: 1,
              allowVideos: false,
              initialSelection: _picked,
              onAlbumChanged: (name) => setState(() => _album = name),
              onSelectionChanged: (assets) => setState(() => _picked = assets),
              onPermissionPermanentlyDenied: () => showPermissionDeniedSheet(
                context,
                title: 'Photo access needed',
                message: 'Turn on photo library access in Settings to add a cover.',
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PostingBanner(
              topInset: top,
              onClose: () => Navigator.of(context).maybePop(),
              hasSelection: _picked.isNotEmpty,
              onNext: _picked.isNotEmpty ? _usePicked : null,
              albumName: _album,
              menuOpen: _albumOpen,
            ),
          ),
        ],
      ),
    );
  }

  /// The dark cover screen: Cancel, "Event cover" 16/500 and Done in Gallery White; the frame
  /// 24 from the sides at 3:4 with "Cover · 3:4" 12; the hint 14 at 80 %; "Choose a different
  /// image" 14 at the bottom.
  Widget _framing(String path) {
    const white = StudioColors.galleryWhite;
    final mq = MediaQuery.of(context);
    final width = (mq.size.width - 78).clamp(200.0, 360.0);
    final frame = Size(width, width * 4 / 3);
    Widget headerButton(String label, VoidCallback onTap, {bool strong = false}) => Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: StudioType.sans(15, weight: strong ? StudioType.medium : StudioType.regular, color: white),
          ),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: StudioColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    headerButton('Cancel', () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: Text(
                        'Event cover',
                        textAlign: TextAlign.center,
                        style: StudioType.sans(16, weight: StudioType.medium, color: white),
                      ),
                    ),
                    headerButton(
                      'Done',
                      () => Navigator.of(context).pop<HostFlyer>((path: path, transform: _transform.copy())),
                      strong: true,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox.fromSize(
                  size: frame,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (d) {
                          _startBox = _transform.resolvedCropRect(_aspect);
                          _startFocal = d.localFocalPoint;
                        },
                        onScaleUpdate: (d) => _onScaleUpdate(d, frame),
                        onScaleEnd: (_) => _startBox = null,
                        child: PostCropPreview.buildTransformedContent(
                          imagePath: path,
                          transform: _transform,
                          imageAspect: _aspect,
                        ),
                      ),
                      const IgnorePointer(child: CoverThirdsGrid()),
                      const Positioned(
                        left: 10,
                        top: 8,
                        child: IgnorePointer(child: StudioImageLabel('Cover · 3:4', mono: false, size: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drag and pinch to frame it',
                style: StudioType.body14(color: white.withValues(alpha: 0.8)),
              ),
              const Spacer(flex: 3),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _path = null),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        'Choose a different image',
                        style: StudioType.body14(color: white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

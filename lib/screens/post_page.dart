import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/post_image_transform.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
import '../widgets/studio/studio_icon.dart';
import 'post_cover_page.dart';
import 'post_create_page.dart';
import 'post_edit_page.dart';
import 'post_video_edit_page.dart';

enum _PostFlowStep { gallery, edit, videoEdit, details }

/// Single-route posting flow: gallery → edit → details (Figma 1609:1975).
class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  static const _bannerHeight = 64.0;
  static const _bottomControlsOffset = 42.0;
  /// Pieces: up to 4 angles (`NotePostCover`). Scenes keep 10.
  int get _maxSelection => _postType == 'piece' ? 4 : 10;

  _PostFlowStep _step = _PostFlowStep.gallery;
  String _postType = 'piece';
  List<AssetEntity> _pickedAssets = [];
  List<String>? _pickedImagePaths;
  String? _pickedVideoPath;
  Uint8List? _pickedVideoThumbnailBytes;
  final ValueNotifier<bool> _albumMenuOpen = ValueNotifier(false);
  String _selectedAlbumName = 'Recents';

  List<String> _editImagePaths = [];
  List<PostImageTransform> _editTransforms = [];
  int _previewImageIndex = 0;

  /// Which picked asset each photo path came from, so the cover step's order can be
  /// carried back into the gallery selection.
  final Map<String, String> _assetIdByPath = {};

  /// Framing per photo path, kept while going back and forth between gallery and cover.
  final Map<String, PostImageTransform> _coverTransforms = {};

  @override
  void dispose() {
    _albumMenuOpen.dispose();
    super.dispose();
  }

  void _exitFlow() => Navigator.pop(context);

  void _onPostTypeChanged(String type) {
    if (type == _postType) return;
    setState(() {
      _postType = type;
      _pickedAssets = [];
      _pickedImagePaths = null;
      _pickedVideoPath = null;
      _pickedVideoThumbnailBytes = null;
      _assetIdByPath.clear();
      _coverTransforms.clear();
    });
  }

  Future<void> _goToEdit() async {
    if (_pickedAssets.isEmpty) return;
    AssetEntity? video;
    for (final asset in _pickedAssets) {
      if (asset.type == AssetType.video) {
        video = asset;
        break;
      }
    }
    if (video != null) {
      final file = await video.file;
      // Same proven thumbnail source the gallery grid itself uses
      // (`_AssetThumbnail` in post_gallery_picker.dart) — captured now,
      // before the AssetEntity reference is gone, so both the compose
      // preview and the published thumbnail show a real poster frame
      // instead of a broken attempt to decode the video file as an image.
      final thumbnail = await video.thumbnailDataWithSize(
        const ThumbnailSize.square(720),
      );
      if (file == null || !mounted) return;
      setState(() {
        _pickedVideoPath = file.path;
        _pickedVideoThumbnailBytes = thumbnail;
        _pickedImagePaths = null;
        _step = _PostFlowStep.videoEdit;
      });
      return;
    }
    final paths = <String>[];
    for (final asset in _pickedAssets) {
      final file = await asset.file;
      if (file != null) {
        paths.add(file.path);
        _assetIdByPath[file.path] = asset.id;
      }
    }
    if (!mounted || paths.isEmpty) return;
    setState(() {
      _pickedImagePaths = paths;
      _step = _PostFlowStep.edit;
    });
  }

  void _goToDetailsFromVideoEdit(String finalVideoPath) {
    setState(() {
      _pickedVideoPath = finalVideoPath;
      _editImagePaths = [];
      _editTransforms = [];
      _previewImageIndex = 0;
      _step = _PostFlowStep.details;
    });
  }

  void _goToDetails(
    List<String> imagePaths,
    List<PostImageTransform> transforms,
    int previewImageIndex,
  ) {
    setState(() {
      _editImagePaths = imagePaths;
      _editTransforms = transforms;
      _previewImageIndex = previewImageIndex;
      if (_postType == 'piece') _keepCoverState(imagePaths, transforms);
      _step = _PostFlowStep.details;
    });
  }

  /// Remembers the cover step's order and framing, and puts the gallery selection in
  /// the same order so the first photo stays the cover.
  void _keepCoverState(List<String> paths, List<PostImageTransform> transforms) {
    for (var i = 0; i < paths.length; i++) {
      _coverTransforms[paths[i]] = transforms[i];
    }
    _pickedImagePaths = paths;
    final rank = {for (var i = 0; i < paths.length; i++) _assetIdByPath[paths[i]]: i};
    _pickedAssets = [..._pickedAssets]
      ..sort((a, b) => (rank[a.id] ?? paths.length).compareTo(rank[b.id] ?? paths.length));
  }

  /// Cover step → gallery (Back, system back, or the add tile).
  void _coverToGallery(List<String> paths, List<PostImageTransform> transforms) {
    setState(() {
      _keepCoverState(paths, transforms);
      _previewImageIndex = 0;
      _step = _PostFlowStep.gallery;
    });
  }

  void _backToEdit() {
    setState(() => _step = _PostFlowStep.edit);
  }

  void _backToGallery() {
    setState(() => _step = _PostFlowStep.gallery);
  }

  bool _handleBack() {
    switch (_step) {
      case _PostFlowStep.gallery:
        return true;
      case _PostFlowStep.edit when _showsCover:
        // PostCoverPage handles back itself so its order and framing are kept.
        return false;
      case _PostFlowStep.edit:
      case _PostFlowStep.videoEdit:
        _backToGallery();
        return false;
      case _PostFlowStep.details:
        // PostCreatePage steps back through its own steps, then calls onEdit.
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _PostFlowStep.gallery,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: switch (_step) {
        _PostFlowStep.gallery => _buildGallery(),
        _PostFlowStep.edit => _buildEdit(),
        _PostFlowStep.videoEdit => _buildVideoEdit(),
        _PostFlowStep.details => _buildDetails(),
      },
    );
  }

  Widget _buildGallery() {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasSelection = _pickedAssets.isNotEmpty || _pickedVideoPath != null;

    return Scaffold(
      backgroundColor: StudioColors.ink,
      body: Stack(
        children: [
          Positioned(
            top: topInset + _bannerHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: PostGalleryPicker(
              key: ValueKey(_postType),
              openNotifier: _albumMenuOpen,
              maxSelection: _maxSelection,
              allowVideos: _postType == 'scene',
              initialSelection: _pickedAssets,
              onAlbumChanged: (name) =>
                  setState(() => _selectedAlbumName = name),
              onSelectionChanged: (assets) =>
                  setState(() => _pickedAssets = assets),
              onPermissionPermanentlyDenied: () {
                showPermissionDeniedSheet(
                  context,
                  title: 'Photo access needed',
                  message:
                      'Enable photo library access in Settings to continue.',
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PostingBanner(
              topInset: topInset,
              onClose: _exitFlow,
              hasSelection: hasSelection,
              onNext: hasSelection ? _goToEdit : null,
              albumName: _selectedAlbumName,
              menuOpen: _albumMenuOpen,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + _bottomControlsOffset,
            child: ValueListenableBuilder<bool>(
              valueListenable: _albumMenuOpen,
              builder: (context, open, _) {
                if (open) return const SizedBox.shrink();
                return Center(
                  child: _PostingSelector(
                    postType: _postType,
                    onChanged: _onPostTypeChanged,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _showsCover =>
      _postType == 'piece' && _pickedImagePaths != null && _pickedImagePaths!.isNotEmpty;

  Widget _buildEdit() {
    final isPicked = _pickedImagePaths != null && _pickedImagePaths!.isNotEmpty;
    // Pieces: framing only (`PostCover`). Scenes keep the full edit step.
    if (_showsCover) {
      final paths = _pickedImagePaths!;
      return PostCoverPage(
        key: ValueKey('cover-${paths.join(",")}'),
        imagePaths: paths,
        initialImageIndex: _previewImageIndex,
        initialTransforms: [for (final p in paths) _coverTransforms[p] ?? PostImageTransform()],
        maxPhotos: _maxSelection,
        onBack: _coverToGallery,
        onAddPhotos: _coverToGallery,
        onNext: _goToDetails,
      );
    }
    return PostEditPage(
      key: ValueKey(
        'edit-$_postType-${(_pickedImagePaths ?? const []).join(",")}',
      ),
      postType: _postType,
      customImagePaths: isPicked ? _pickedImagePaths : null,
      initialImageIndex: _previewImageIndex,
      initialTransforms: _editTransforms.isNotEmpty ? _editTransforms : null,
      onClose: _exitFlow,
      onNext: _goToDetails,
    );
  }

  Widget _buildVideoEdit() {
    return PostVideoEditPage(
      key: ValueKey('video-edit-$_pickedVideoPath'),
      videoPath: _pickedVideoPath!,
      onClose: _exitFlow,
      onNext: _goToDetailsFromVideoEdit,
    );
  }

  Widget _buildDetails() {
    return PostCreatePage(
      key: const ValueKey('details'),
      postType: _postType,
      imagePaths: _editImagePaths,
      transforms: _editTransforms,
      previewImageIndex: _previewImageIndex,
      onClose: _exitFlow,
      onEdit: _pickedVideoPath != null
          ? () => setState(() => _step = _PostFlowStep.videoEdit)
          : _backToEdit,
      mediaKind: _pickedVideoPath != null ? 'video' : 'image',
      videoPath: _pickedVideoPath,
      videoThumbnailBytes: _pickedVideoThumbnailBytes,
    );
  }
}

/// Gallery header, dark like the `PostCover` step that follows (no board of its own):
/// close 22 in a 44 target, the album name 16/500 with a chevron in the middle, and
/// "Next" 15/500 as text (Secondary-on-dark until something is picked).
class _PostingBanner extends StatelessWidget {
  const _PostingBanner({
    required this.topInset,
    required this.onClose,
    required this.hasSelection,
    required this.onNext,
    required this.albumName,
    required this.menuOpen,
  });

  final double topInset;
  final VoidCallback onClose;
  final bool hasSelection;
  final VoidCallback? onNext;
  final String albumName;
  final ValueNotifier<bool> menuOpen;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudioColors.ink,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _PostPageState._bannerHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onClose,
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
                Expanded(
                  child: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: menuOpen,
                      builder: (context, open, _) => GestureDetector(
                        onTap: () => menuOpen.value = !open,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  albumName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: StudioType.sans(
                                    16,
                                    weight: StudioType.medium,
                                    color: StudioColors.galleryWhite,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: open ? -0.25 : 0.25,
                                duration: StudioMotion.quick,
                                child: const StudioIcon(
                                  StudioIcons.chevronRight,
                                  size: 16,
                                  color: StudioColors.galleryWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: hasSelection,
                  child: GestureDetector(
                    onTap: onNext,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          child: Text(
                            'Next',
                            style: StudioType.sans(
                              15,
                              weight: StudioType.medium,
                              color: hasSelection
                                  ? StudioColors.galleryWhite
                                  : StudioColors.onDarkSecondary,
                            ),
                          ),
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

/// Piece / Scene switch over the grid: an Ink pill (90 %) with 15 text, the chosen one
/// Gallery White 500, the other Secondary-on-dark.
class _PostingSelector extends StatelessWidget {
  const _PostingSelector({required this.postType, required this.onChanged});

  static const _selectorBg = Color(0xE6111111);

  final String postType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['piece', 'scene'];

    return Container(
      width: 200,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _selectorBg,
        borderRadius: BorderRadius.circular(StudioRadius.round),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final type in options)
            _SelectorTab(
              label: type == 'scene' ? 'Scene' : 'Piece',
              selected: postType == type,
              onTap: () => onChanged(type),
            ),
        ],
      ),
    );
  }
}

class _SelectorTab extends StatelessWidget {
  const _SelectorTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: StudioType.sans(
                15,
                weight: selected ? StudioType.medium : StudioType.regular,
                color: selected
                    ? StudioColors.galleryWhite
                    : StudioColors.onDarkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

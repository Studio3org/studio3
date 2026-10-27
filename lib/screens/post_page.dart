import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/post_image_transform.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
import '../widgets/studio/studio.dart';
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
  /// Pieces: up to 4 angles (`NotePostCover`). A Scene is one photo or one video (it used to
  /// allow 10 photos and post only the one on screen).
  int get _maxSelection => _postType == 'piece' ? 4 : 1;

  _PostFlowStep _step = _PostFlowStep.gallery;
  String _postType = 'piece';
  List<AssetEntity> _pickedAssets = [];
  List<String>? _pickedImagePaths;
  String? _pickedVideoPath;
  Uint8List? _pickedVideoThumbnailBytes;
  Duration? _pickedVideoLength;

  /// Set when opened from "Add a Scene from the studio": a Scene pre-linked to that piece.
  ScenePostArgs? _linkedPiece;
  bool _readArgs = false;

  /// The details steps were opened; they stay mounted (off stage) behind the photo steps
  /// so going back to the photos keeps what was typed.
  bool _detailsOpened = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArgs) return;
    _readArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ScenePostArgs) {
      _linkedPiece = args;
      _postType = 'scene';
    } else if (args == 'scene') {
      // Chosen on "What are you sharing?" (`PostCreate`).
      _postType = 'scene';
    }
  }

  @override
  void dispose() {
    _albumMenuOpen.dispose();
    super.dispose();
  }

  void _exitFlow() => Navigator.pop(context);

  /// Close on the picker asks first when something is picked (`PostPicker`).
  Future<void> _closePicker() async {
    if (_pickedAssets.isEmpty && _pickedVideoPath == null) {
      _exitFlow();
      return;
    }
    final discard = await showStudioConfirm(
      context,
      title: 'Discard this post?',
      message: "The photos you picked won't be kept.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep going',
    );
    if (discard && mounted) _exitFlow();
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
        _pickedVideoLength = video!.videoDuration;
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

  void _goToDetailsFromVideoEdit(SceneVideoResult result) {
    setState(() {
      _pickedVideoPath = result.path;
      _pickedVideoLength = result.length;
      if (result.cover != null) _pickedVideoThumbnailBytes = result.cover;
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
        _closePicker();
        return false;
      case _PostFlowStep.edit when _showsCover:
        // PostCoverPage handles back itself so its order and framing are kept.
        return false;
      case _PostFlowStep.videoEdit:
        // PostVideoEditPage steps back through trim and cover itself.
        return false;
      case _PostFlowStep.edit:
        _backToGallery();
        return false;
      case _PostFlowStep.details:
        // PostCreatePage steps back through its own steps, then calls onEdit.
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nothingPicked = _pickedAssets.isEmpty && _pickedVideoPath == null;
    return PopScope(
      canPop: _step == _PostFlowStep.gallery && nothingPicked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_detailsOpened || _step == _PostFlowStep.details)
            Offstage(
              offstage: _step != _PostFlowStep.details,
              child: TickerMode(
                enabled: _step == _PostFlowStep.details,
                child: _buildDetails(),
              ),
            ),
          if (_step != _PostFlowStep.details)
            switch (_step) {
              _PostFlowStep.gallery => _buildGallery(),
              _PostFlowStep.edit => _buildEdit(),
              _PostFlowStep.videoEdit => _buildVideoEdit(),
              _PostFlowStep.details => const SizedBox.shrink(),
            },
        ],
      ),
    );
  }

  Widget _buildGallery() {
    final c = context.studio;
    final hasSelection = _pickedAssets.isNotEmpty || _pickedVideoPath != null;
    final isPiece = _postType == 'piece';

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostPickerHeader(
              title: isPiece ? 'New piece' : 'New Scene',
              albumName: _selectedAlbumName,
              onClose: _closePicker,
              onNext: hasSelection ? _goToEdit : null,
              onAlbum: () => _albumMenuOpen.value = !_albumMenuOpen.value,
              countLabel: isPiece ? '${_pickedAssets.length} of $_maxSelection selected' : null,
            ),
            Expanded(
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
          ],
        ),
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
      // Back to the gallery, as the board's back arrow.
      onClose: _backToGallery,
      onNext: _goToDetails,
    );
  }

  Widget _buildVideoEdit() {
    return PostVideoEditPage(
      key: ValueKey('video-edit-$_pickedVideoPath'),
      videoPath: _pickedVideoPath!,
      initialCover: _pickedVideoThumbnailBytes,
      // Back to the gallery, as the board's back arrow.
      onClose: _backToGallery,
      onNext: _goToDetailsFromVideoEdit,
    );
  }

  Widget _buildDetails() {
    _detailsOpened = true;
    return PostCreatePage(
      key: ValueKey('details-$_postType'),
      active: _step == _PostFlowStep.details,
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
      videoLength: _pickedVideoLength,
      initialLinkedPiece: _postType == 'scene' ? _linkedPiece : null,
    );
  }
}

/// `PostPicker` top: Close (44) / "New piece" 16/500 / Next 15/500 (Tertiary until something is
/// picked), then the album name 15/500 (tap for the album list) and, for pieces, Mono 12
/// "2 of 4 selected" in Graphite, 16 20 10.
class PostPickerHeader extends StatelessWidget {
  const PostPickerHeader({
    super.key,
    required this.title,
    required this.albumName,
    required this.onClose,
    required this.onNext,
    this.onAlbum,
    this.countLabel,
  });

  final String title;
  final String albumName;
  final VoidCallback onClose;

  /// Null until something is picked.
  final VoidCallback? onNext;
  final VoidCallback? onAlbum;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(child: StudioIcon(StudioIcons.close, size: 22, color: c.textPrimary)),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: onNext != null,
                  child: GestureDetector(
                    onTap: onNext,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            'Next',
                            style: StudioType.sans(
                              15,
                              weight: StudioType.medium,
                              color: onNext != null ? c.textPrimary : c.textTertiary,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Semantics(
                  button: onAlbum != null,
                  hint: onAlbum != null ? 'Choose an album' : null,
                  child: GestureDetector(
                    onTap: onAlbum,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      albumName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (countLabel != null) Text(countLabel!, style: StudioType.mono(12, color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

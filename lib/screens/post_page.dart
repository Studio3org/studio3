import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
import '../widgets/post_gallery/posting_banner.dart';
import 'post_create_page.dart';
import 'post_edit_page.dart';

enum _PostFlowStep { gallery, edit, details }

/// Piece posting flow: gallery (up to 5 photos) → cover/edit → details.
class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  static const _maxPieceSelection = 5;

  _PostFlowStep _step = _PostFlowStep.gallery;
  List<AssetEntity> _pickedAssets = [];
  List<String>? _pickedImagePaths;
  final ValueNotifier<bool> _albumMenuOpen = ValueNotifier(false);
  String _selectedAlbumName = 'Recents';

  List<String> _editImagePaths = [];
  List<PostImageTransform> _editTransforms = [];
  int _previewImageIndex = 0;

  @override
  void dispose() {
    _albumMenuOpen.dispose();
    super.dispose();
  }

  void _exitFlow() => Navigator.pop(context);

  Future<void> _goToEdit() async {
    if (_pickedAssets.isEmpty) return;
    final paths = <String>[];
    for (final asset in _pickedAssets) {
      final file = await asset.file;
      if (file != null) paths.add(file.path);
    }
    if (!mounted || paths.isEmpty) return;
    setState(() {
      _pickedImagePaths = paths;
      _step = _PostFlowStep.edit;
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
      _step = _PostFlowStep.details;
    });
  }

  void _backToEdit() {
    setState(() => _step = _PostFlowStep.edit);
  }

  void _backToGallery() {
    setState(() => _step = _PostFlowStep.gallery);
  }

  /// Piece flow's "+" tile (Figma 2716:5774): pushes the gallery picker as
  /// its own route, seeded with everything already picked, so the running
  /// edit session (crop/adjust work, reorder) never gets torn down the way
  /// switching `_step` back to `.gallery` would.
  Future<List<AssetEntity>?> _pickMoreImages(int remainingSlots) async {
    final result = await Navigator.push<List<AssetEntity>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMorePickerPage(
          initialSelection: _pickedAssets,
          maxSelection: _pickedAssets.length + remainingSlots,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _pickedAssets = result);
    }
    return result;
  }

  bool _handleBack() {
    switch (_step) {
      case _PostFlowStep.gallery:
        return true;
      case _PostFlowStep.edit:
        _backToGallery();
        return false;
      case _PostFlowStep.details:
        _backToEdit();
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
        _PostFlowStep.details => _buildDetails(),
      },
    );
  }

  Widget _buildGallery() {
    final topInset = MediaQuery.paddingOf(context).top;
    final hasSelection = _pickedAssets.isNotEmpty;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Stack(
        children: [
          Positioned(
            top: topInset + PostingBanner.height,
            left: 0,
            right: 0,
            bottom: 0,
            child: PostGalleryPicker(
              openNotifier: _albumMenuOpen,
              maxSelection: _maxPieceSelection,
              allowVideos: false,
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
            child: PostingBanner(
              topInset: topInset,
              onClose: _exitFlow,
              hasSelection: hasSelection,
              onNext: hasSelection ? _goToEdit : null,
              albumName: _selectedAlbumName,
              menuOpen: _albumMenuOpen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdit() {
    final isPicked = _pickedImagePaths != null && _pickedImagePaths!.isNotEmpty;
    return PostEditPage(
      key: ValueKey('edit-piece-${(_pickedImagePaths ?? const []).join(",")}'),
      postType: 'piece',
      customImagePaths: isPicked ? _pickedImagePaths : null,
      initialImageIndex: _previewImageIndex,
      initialTransforms: _editTransforms.isNotEmpty ? _editTransforms : null,
      onClose: _backToGallery,
      onPickMore: _pickMoreImages,
      onNext: _goToDetails,
    );
  }

  Widget _buildDetails() {
    return PostCreatePage(
      key: const ValueKey('details'),
      postType: 'piece',
      imagePaths: _editImagePaths,
      transforms: _editTransforms,
      previewImageIndex: _previewImageIndex,
      onClose: _exitFlow,
      onEdit: _backToEdit,
    );
  }
}

/// Modal "add more" gallery route used by the piece flow's "+" tile — the
/// same banner/grid as the initial gallery step, but as its own pushed
/// route (rather than a `_step` switch) so it never tears down the
/// in-progress edit session underneath it. Pops with the final selection,
/// or null if the user backs out without confirming.
class _AddMorePickerPage extends StatefulWidget {
  const _AddMorePickerPage({
    required this.initialSelection,
    required this.maxSelection,
  });

  final List<AssetEntity> initialSelection;
  final int maxSelection;

  @override
  State<_AddMorePickerPage> createState() => _AddMorePickerPageState();
}

class _AddMorePickerPageState extends State<_AddMorePickerPage> {
  late List<AssetEntity> _selected = List.of(widget.initialSelection);
  final ValueNotifier<bool> _albumMenuOpen = ValueNotifier(false);
  String _selectedAlbumName = 'Recents';

  @override
  void dispose() {
    _albumMenuOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Stack(
        children: [
          Positioned(
            top: topInset + PostingBanner.height,
            left: 0,
            right: 0,
            bottom: 0,
            child: PostGalleryPicker(
              openNotifier: _albumMenuOpen,
              maxSelection: widget.maxSelection,
              initialSelection: widget.initialSelection,
              onAlbumChanged: (name) =>
                  setState(() => _selectedAlbumName = name),
              onSelectionChanged: (assets) =>
                  setState(() => _selected = assets),
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
            child: PostingBanner(
              topInset: topInset,
              onClose: () => Navigator.pop(context),
              hasSelection: _selected.isNotEmpty,
              onNext: _selected.isNotEmpty
                  ? () => Navigator.pop(context, _selected)
                  : null,
              albumName: _selectedAlbumName,
              menuOpen: _albumMenuOpen,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/post_media_assets.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
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
  static const _maxSelection = 10;

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
      if (file != null) paths.add(file.path);
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
      _step = _PostFlowStep.details;
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
      case _PostFlowStep.edit:
      case _PostFlowStep.videoEdit:
        _backToGallery();
        return false;
      case _PostFlowStep.details:
        if (_pickedVideoPath != null) {
          setState(() => _step = _PostFlowStep.videoEdit);
        } else {
          _backToEdit();
        }
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
      backgroundColor: Colors.black,
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

  Widget _buildEdit() {
    final isPicked = _pickedImagePaths != null && _pickedImagePaths!.isNotEmpty;
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

class _PostingBanner extends StatelessWidget {
  const _PostingBanner({
    required this.topInset,
    required this.onClose,
    required this.hasSelection,
    required this.onNext,
    required this.albumName,
    required this.menuOpen,
  });

  static const _neutral300 = Color(0xFFC8C5BC);

  final double topInset;
  final VoidCallback onClose;
  final bool hasSelection;
  final VoidCallback? onNext;
  final String albumName;
  final ValueNotifier<bool> menuOpen;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: _PostPageState._bannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
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
                    const Spacer(),
                    Opacity(
                      opacity: hasSelection ? 1 : 0.3,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onNext,
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 60,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _neutral300,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Next',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: HomeFeedTokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: menuOpen,
                  builder: (context, open, _) => GestureDetector(
                    onTap: () => menuOpen.value = !open,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          albumName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: HomeFeedTokens.textInverse,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: SvgPicture.asset(
                            PostMediaAssets.chevronDown,
                            width: 9,
                            height: 9,
                            colorFilter: ColorFilter.mode(
                              HomeFeedTokens.textInverse,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
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

class _PostingSelector extends StatelessWidget {
  const _PostingSelector({required this.postType, required this.onChanged});

  static const _selectorBg = Color(0xE6231F1B);

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
        borderRadius: BorderRadius.circular(100),
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

  static const _textSecondary = Color(0xFF8C8880);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: selected ? HomeFeedTokens.textInverse : _textSecondary,
        ),
      ),
    );
  }
}

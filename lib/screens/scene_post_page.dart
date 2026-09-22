import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
import '../widgets/post_gallery/posting_banner.dart';
import 'scene_create_page.dart';
import 'scene_edit_page.dart';
import 'scene_video_edit_page.dart';

enum _SceneFlowStep { gallery, edit, details }

/// Scene posting only: gallery → Edit (Figma 2756:10720) → details.
class ScenePostPage extends StatefulWidget {
  const ScenePostPage({super.key});

  @override
  State<ScenePostPage> createState() => _ScenePostPageState();
}

class _ScenePostPageState extends State<ScenePostPage> {
  static const _maxSelection = 1;

  _SceneFlowStep _step = _SceneFlowStep.gallery;
  List<AssetEntity> _pickedAssets = [];
  List<String> _imagePaths = [];
  List<PostImageTransform> _transforms = [];
  String? _videoPath;
  Uint8List? _videoThumbnailBytes;
  final ValueNotifier<bool> _albumMenuOpen = ValueNotifier(false);
  String _selectedAlbumName = 'Recents';

  @override
  void dispose() {
    _albumMenuOpen.dispose();
    super.dispose();
  }

  void _exitFlow() => Navigator.pop(context);

  Future<void> _goToEdit() async {
    if (_pickedAssets.isEmpty) return;
    final asset = _pickedAssets.first;
    if (asset.type == AssetType.video) {
      final file = await asset.file;
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(720),
      );
      if (file == null || !mounted) return;
      setState(() {
        _videoPath = file.path;
        _videoThumbnailBytes = thumbnail;
        _imagePaths = [];
        _transforms = [
          PostImageTransform(aspectRatio: CropAspectRatio.ratio9x16),
        ];
        _step = _SceneFlowStep.edit;
      });
      return;
    }
    final file = await asset.file;
    if (file == null || !mounted) return;
    setState(() {
      _videoPath = null;
      _videoThumbnailBytes = null;
      _imagePaths = [file.path];
      _transforms = [
        PostImageTransform(aspectRatio: CropAspectRatio.ratio9x16),
      ];
      _step = _SceneFlowStep.edit;
    });
  }

  void _backToGallery() {
    setState(() => _step = _SceneFlowStep.gallery);
  }

  void _backToEdit() {
    setState(() => _step = _SceneFlowStep.edit);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _SceneFlowStep.gallery,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step == _SceneFlowStep.details) {
          _backToEdit();
        } else {
          _backToGallery();
        }
      },
      child: switch (_step) {
        _SceneFlowStep.gallery => _buildGallery(),
        _SceneFlowStep.edit =>
          _videoPath != null
              ? SceneVideoEditPage(
                  videoPath: _videoPath!,
                  onBack: _backToGallery,
                  onNext: (path, thumbnail, aspectRatio) {
                    setState(() {
                      _videoPath = path;
                      if (thumbnail != null) {
                        _videoThumbnailBytes = thumbnail;
                      }
                      _transforms = [PostImageTransform(aspectRatio: aspectRatio)];
                      _step = _SceneFlowStep.details;
                    });
                  },
                )
              : SceneEditPage(
                  imagePath: _imagePaths.isEmpty ? null : _imagePaths.first,
                  videoThumbnailBytes: _videoThumbnailBytes,
                  initialTransform: _transforms.isEmpty
                      ? null
                      : _transforms.first,
                  onBack: _backToGallery,
                  onNext: (transform) {
                    setState(() {
                      _transforms = [transform];
                      _step = _SceneFlowStep.details;
                    });
                  },
                ),
        _SceneFlowStep.details => SceneCreatePage(
          imagePaths: _imagePaths,
          transforms: _transforms,
          previewImageIndex: 0,
          onClose: _exitFlow,
          onEdit: _backToEdit,
          onCoverChanged: (bytes) {
            setState(() => _videoThumbnailBytes = bytes);
          },
          mediaKind: _videoPath != null ? 'video' : 'image',
          videoPath: _videoPath,
          videoThumbnailBytes: _videoThumbnailBytes,
        ),
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
              maxSelection: _maxSelection,
              allowVideos: true,
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
}

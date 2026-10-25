import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/crop_cover_math.dart';
import '../widgets/permission_denied_sheet.dart';
import '../widgets/post_gallery/post_gallery_picker.dart';
import '../widgets/post_gallery/posting_banner.dart';
import 'event_create_page.dart';
import 'scene_edit_page.dart';

enum _EventFlowStep { gallery, edit, details }

/// Event posting: gallery (one photo) → scene-style edit locked to 3:4 → details.
class EventPostPage extends StatefulWidget {
  const EventPostPage({super.key});

  @override
  State<EventPostPage> createState() => _EventPostPageState();
}

class _EventPostPageState extends State<EventPostPage> {
  _EventFlowStep _step = _EventFlowStep.gallery;
  List<AssetEntity> _pickedAssets = [];
  String? _imagePath;
  PostImageTransform _transform = PostImageTransform(
    aspectRatio: CropAspectRatio.ratio3x4,
  );
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
    final file = await _pickedAssets.first.file;
    if (file == null || !mounted) return;
    setState(() {
      _imagePath = file.path;
      _transform = PostImageTransform(aspectRatio: CropAspectRatio.ratio3x4);
      _step = _EventFlowStep.edit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _EventFlowStep.gallery,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step == _EventFlowStep.details) {
          setState(() => _step = _EventFlowStep.edit);
        } else {
          setState(() => _step = _EventFlowStep.gallery);
        }
      },
      child: switch (_step) {
        _EventFlowStep.gallery => _buildGallery(),
        _EventFlowStep.edit => SceneEditPage(
            imagePath: _imagePath,
            initialTransform: _transform,
            showSizeTool: false,
            lockedAspectRatio: CropAspectRatio.ratio3x4,
            onBack: () => setState(() => _step = _EventFlowStep.gallery),
            onNext: (transform) {
              setState(() {
                _transform = transform;
                _transform.aspectRatio = CropAspectRatio.ratio3x4;
                _step = _EventFlowStep.details;
              });
            },
          ),
        _EventFlowStep.details => EventCreatePage(
            imagePath: _imagePath ?? '',
            transform: _transform,
            onClose: _exitFlow,
            onEdit: () => setState(() => _step = _EventFlowStep.edit),
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
              maxSelection: 1,
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
}

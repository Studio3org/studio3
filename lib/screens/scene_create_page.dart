import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/post_location_options.dart';
import '../data/post_media_assets.dart';
import '../models/piece_summary.dart';
import '../models/post_image_transform.dart';
import '../services/auth_session.dart';
import '../services/api_exception.dart';
import '../services/piece_service.dart';
import '../services/post_publish_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/create_flow_widgets.dart';
import '../widgets/create_flow/related_pieces_picker_page.dart';
import '../widgets/post_crop_preview.dart';
import '../utils/payout_setup.dart';
import '../widgets/publish_result_overlays.dart';
import 'scene_set_cover_page.dart';
import '../theme/app_fonts.dart';

/// Scene details step — independent of the piece create flow.
class SceneCreatePage extends StatefulWidget {
  const SceneCreatePage({
    super.key,
    required this.imagePaths,
    required this.transforms,
    required this.previewImageIndex,
    required this.onClose,
    this.onEdit,
    this.onCoverChanged,
    this.mediaKind = 'image',
    this.videoPath,
    this.videoThumbnailBytes,
  });

  final List<String> imagePaths;
  final List<PostImageTransform> transforms;
  final int previewImageIndex;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final ValueChanged<Uint8List>? onCoverChanged;
  final String mediaKind;
  final String? videoPath;
  final Uint8List? videoThumbnailBytes;

  @override
  State<SceneCreatePage> createState() => _SceneCreatePageState();
}

class _SceneCreatePageState extends State<SceneCreatePage> {
  final _descriptionController = TextEditingController();
  bool _publishing = false;
  bool _publishSuccess = false;
  bool _publishFailed = false;
  int _tab = 0;
  int _unlockedTab = 0;
  PostLocationOption? _selectedLocation;
  final Set<String> _linkedPieceIds = {};

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  int get _linkedCount => _linkedPieceIds.length;

  String? get _linkedTrailing {
    if (_linkedCount == 0) return null;
    return '$_linkedCount linked';
  }

  String get _linkedReviewLine {
    final n = _linkedCount;
    if (n == 1) return 'Linked to 1 piece';
    return 'Linked to $n pieces';
  }

  bool get _detailsFilled => _descriptionController.text.trim().isNotEmpty;

  void _onBannerBack() {
    if (_tab > 0) {
      setState(() => _tab = 0);
      return;
    }
    widget.onClose();
  }

  void _openLocationPicker() {
    ChooseLocationSheet.show(
      context,
      onLocationSelected: (location) {
        setState(() => _selectedLocation = location);
      },
    );
  }

  Future<void> _openLinkedPiecePicker() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return;
    List<PieceSummary> pieces;
    try {
      pieces = await PieceService.instance.getUserPieces(username);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your pieces')),
      );
      return;
    }
    if (!mounted) return;
    final selected = await RelatedPiecesPickerPage.show(
      context,
      pieces: pieces,
      selectedIds: Set<String>.from(_linkedPieceIds),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _linkedPieceIds
        ..clear()
        ..addAll(selected);
    });
  }

  PostDraft _buildDraft() {
    final caption = _descriptionController.text;
    return PostDraft(
      postType: 'scene',
      imagePaths: widget.imagePaths,
      mediaKind: widget.mediaKind,
      videoPath: widget.videoPath,
      videoThumbnailBytes: widget.videoThumbnailBytes,
      title: caption,
      description: caption,
      location: _selectedLocation?.displayName,
      transforms: widget.transforms,
      previewImageIndex: widget.previewImageIndex,
      linkedPieceId: _linkedPieceIds.isEmpty ? null : _linkedPieceIds.first,
      isForSale: false,
    );
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _publishFailed = false;
    });
    try {
      await PostPublishService.instance.publish(_buildDraft());
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _publishSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      if (e is ApiException && isPayoutSetupRequiredMessage(e.message)) {
        await openPayoutSetup(context);
        return;
      }
      setState(() => _publishFailed = true);
    }
  }

  void _finishPublishSuccess() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openSetCover() async {
    final path = widget.videoPath;
    if (path == null || path.isEmpty) return;
    final bytes = await SceneSetCoverPage.show(
      context,
      videoPath: path,
      initialCoverBytes: widget.videoThumbnailBytes,
    );
    if (bytes == null || !mounted) return;
    widget.onCoverChanged?.call(bytes);
  }

  void _onSaveAndContinue() {
    setState(() {
      _unlockedTab = 1;
      _tab = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final onReview = _tab == 1;
    final continueEnabled = onReview ? !_publishing : _detailsFilled;
    final ctaLabel = onReview ? 'Publish' : 'Save and continue';

    return StudioPublishFlowGate(
      publishing: _publishing,
      success: _publishSuccess,
      failure: _publishFailed,
      publishingMessage: 'Publishing your scene...',
      successTitle: 'Your scene is live',
      onSuccessDismiss: _finishPublishSuccess,
      onRetry: _publish,
      imagePath: widget.imagePaths.isEmpty
          ? null
          : widget.imagePaths[widget.previewImageIndex],
      transform: widget.transforms.isEmpty
          ? null
          : widget.transforms[widget.previewImageIndex],
      videoThumbnailBytes: widget.videoThumbnailBytes,
      child: PopScope(
        canPop:
            _tab == 0 && !_publishing && !_publishSuccess && !_publishFailed,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_publishSuccess) {
            _finishPublishSuccess();
            return;
          }
          if (_publishFailed) {
            setState(() => _publishFailed = false);
            return;
          }
          _onBannerBack();
        },
        child: Scaffold(
          backgroundColor: HomeFeedTokens.background,
          body: Column(
            children: [
              CreateFlowBanner(
                topInset: topInset,
                title: 'Scene',
                onClose: _onBannerBack,
                useBackChevron: true,
                height: 53,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      _buildCoverAndTabs(),
                      if (!onReview) _buildDetails() else _buildReviewCard(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 24, 10, bottomInset + 24),
                child: Opacity(
                  opacity: continueEnabled && !_publishing ? 1 : 0.4,
                  child: CreateFlowBottomButton(
                    label: ctaLabel,
                    height: 40,
                    backgroundColor: HomeFeedTokens.textPrimary,
                    textColor: HomeFeedTokens.textInverse,
                    onTap: _publishing || !continueEnabled
                        ? null
                        : (onReview ? _publish : _onSaveAndContinue),
                    child: Text(
                      ctaLabel,
                      style: AppFonts.geist(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: HomeFeedTokens.textInverse,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverAndTabs() {
    const tabLabels = ['Details', 'Review'];
    final counter = widget.mediaKind == 'video'
        ? '1/1'
        : '${widget.previewImageIndex + 1}/${widget.imagePaths.length}';
    return Column(
      children: [
        const SizedBox(height: 11),
        Center(
          child: widget.mediaKind == 'video'
              ? _SceneCoverPreview(
                  thumbnailBytes: widget.videoThumbnailBytes,
                  isVideo: true,
                  onEditCover: _openSetCover,
                  counterLabel: counter,
                )
              : (widget.imagePaths.isNotEmpty && widget.transforms.isNotEmpty)
              ? _SceneCoverPreview(
                  imagePath: widget.imagePaths[widget.previewImageIndex],
                  transform: widget.transforms[widget.previewImageIndex],
                  onEdit: widget.onEdit,
                  counterLabel: counter,
                )
              : const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: SizedBox(
                  width: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _tabButton(index: 0, label: tabLabels[0]),
                      _tabButton(index: 1, label: tabLabels[1]),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Color(0xFFC8C5BC),
                  child: SizedBox(height: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabButton({required int index, required String label}) {
    final selected = index == _tab;
    return GestureDetector(
      onTap: index <= _unlockedTab ? () => setState(() => _tab = index) : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppFonts.geist(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? HomeFeedTokens.textPrimary
                  : HomeFeedTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 2,
            decoration: BoxDecoration(
              color: selected ? HomeFeedTokens.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caption',
            style: AppFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HomeFeedTokens.textPrimary),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: null,
              cursorColor: HomeFeedTokens.textPrimary,
              style: AppFonts.geist(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Every piece has a behind-the-scenes…',
                hintStyle: AppFonts.geist(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _NavRow(
            label: 'Location',
            trailing: _selectedLocation?.name,
            onTap: _openLocationPicker,
          ),
          const SizedBox(height: 16),
          _NavRow(
            label: 'Link to piece(s)',
            trailing: _linkedTrailing,
            onTap: _openLinkedPiecePicker,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final caption = _descriptionController.text.trim();
    final location = _selectedLocation?.displayName ?? _selectedLocation?.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HomeFeedTokens.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC8C5BC), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Details',
                    style: AppFonts.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _tab = 0),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Edit',
                    style: AppFonts.geist(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                caption,
                style: AppFonts.geist(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ],
            if (location != null && location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                location,
                style: AppFonts.geist(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
            ],
            if (_linkedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                _linkedReviewLine,
                style: AppFonts.geist(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SceneCoverPreview extends StatelessWidget {
  const _SceneCoverPreview({
    required this.counterLabel,
    this.imagePath,
    this.transform,
    this.thumbnailBytes,
    this.isVideo = false,
    this.onEdit,
    this.onEditCover,
  });

  static const _width = 156.0;
  static const _height = 197.0;
  static const _radius = 8.0;

  final String counterLabel;
  final String? imagePath;
  final PostImageTransform? transform;
  final Uint8List? thumbnailBytes;
  final bool isVideo;
  final VoidCallback? onEdit;
  final VoidCallback? onEditCover;

  @override
  Widget build(BuildContext context) {
    final transform = this.transform;
    final imagePath = this.imagePath;
    final frame = Size(
      _width,
      transform != null ? _width / transform.aspectRatio.value : _height,
    );

    return SizedBox(
      width: frame.width,
      height: frame.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isVideo && imagePath != null && transform != null)
            PostCropPreview(
              imagePath: imagePath,
              transform: transform,
              borderRadius: BorderRadius.circular(_radius),
              frameSize: frame,
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: ColoredBox(
                color: const Color(0xFF4A4843),
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (thumbnailBytes != null)
                      Image.memory(
                        thumbnailBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          if (isVideo && onEditCover != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Center(
                child: GestureDetector(
                  onTap: onEditCover,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC231F1B),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      'Edit cover',
                      style: AppFonts.geist(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: HomeFeedTokens.textInverse,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isVideo && onEdit != null)
            Positioned(
              top: 7,
              right: 11,
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(
                  PostMediaAssets.createCoverEditIcon,
                  width: 26,
                  height: 18,
                ),
              ),
            ),
          if (!isVideo)
            Positioned(
              left: 5,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x4D231F1B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  counterLabel,
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
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.trailing});

  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Text(
              label,
              style: AppFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.geist(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 8),
            SvgPicture.asset(
              PostMediaAssets.createDetailsChevronSm,
              width: 5,
              height: 8,
            ),
          ],
        ),
      ),
    );
  }
}

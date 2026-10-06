import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:google_fonts/google_fonts.dart';

import '../data/post_material_options.dart';
import '../data/post_location_options.dart';
import '../data/post_picker_options.dart';
import '../data/post_media_assets.dart';
import '../models/listing_details.dart';
import '../models/piece_summary.dart';
import '../models/post_image_transform.dart';
import '../services/auth_session.dart';
import '../services/api_exception.dart';
import '../services/piece_service.dart';
import '../services/post_publish_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/create_flow_widgets.dart';
import '../widgets/create_flow/listing_details_form.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/post_create_option_sheet.dart';
import '../widgets/post_crop_preview.dart';
import '../widgets/seller_mode_required_dialog.dart';
import '../widgets/uploading_dialog.dart';
import 'add_materials_page.dart';

/// Add Piece / Scene details — posting flow step (Figma 1995:1486).
class PostCreatePage extends StatefulWidget {
  const PostCreatePage({
    super.key,
    required this.postType,
    required this.imagePaths,
    required this.transforms,
    required this.previewImageIndex,
    required this.onClose,
    this.onEdit,
    this.mediaKind = 'image',
    this.videoPath,
    this.videoThumbnailBytes,
  });

  final String postType;
  final List<String> imagePaths;
  final List<PostImageTransform> transforms;
  final int previewImageIndex;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final String mediaKind;
  final String? videoPath;
  final Uint8List? videoThumbnailBytes;

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  static const _neutral700 = Color(0xFF4A4843);
  static const _neutral300 = Color(0xFFC8C5BC);

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _listingFormKey = GlobalKey<ListingDetailsFormState>();
  bool _aiToolsUsed = false;
  bool _isProcess = false;
  bool _publishing = false;
  bool _listForSale = false;
  bool _reviewMode = false;
  PostLocationOption? _selectedLocation;
  String? _selectedMediumId;
  final Set<String> _selectedStyleIds = {};
  final List<PostMaterialOption> _selectedMaterials = [];
  String? _selectedSeriesId;
  String? _newSeriesName;
  String? _seriesLabel;
  String? _linkedPieceId;
  String? _linkedPieceLabel;

  bool get _isPiece => widget.postType == 'piece';

  @override
  void initState() {
    super.initState();
    _listForSale = _isPiece && AuthSession.instance.sellerEnabled;
    AuthSession.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onSessionChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_isPiece && AuthSession.instance.sellerEnabled && !_listForSale) {
      setState(() => _listForSale = true);
    }
  }

  Future<void> _onListForSaleChanged(bool value) async {
    if (!value) {
      setState(() {
        _listForSale = false;
        _listingFormKey.currentState?.clear();
      });
      return;
    }

    if (AuthSession.instance.sellerEnabled) {
      setState(() => _listForSale = true);
      return;
    }

    final switchToSeller = await showSellerModeRequiredDialog(context);
    if (!mounted) return;
    if (switchToSeller == true) {
      await Navigator.pushNamed(context, '/profile-settings');
      if (!mounted) return;
      if (AuthSession.instance.sellerEnabled) {
        setState(() => _listForSale = true);
      }
    }
  }

  void _openLocationPicker() {
    ChooseLocationSheet.show(
      context,
      onLocationSelected: (location) {
        setState(() => _selectedLocation = location);
      },
    );
  }

  void _openMediumPicker() {
    PostCreateOptionSheet.show(
      context,
      title: 'Select medium',
      searchHint: 'Search medium',
      options: PostMediumOptions.all,
      selectedIds: _selectedMediumId != null ? {_selectedMediumId!} : const {},
      mode: PostPickerSelectionMode.singleRadio,
      closeOnSelection: true,
      onSelectionChanged: (ids) {
        setState(() {
          _selectedMediumId = ids.isEmpty ? null : ids.first;
        });
      },
    );
  }

  void _openStylePicker() {
    PostCreateOptionSheet.show(
      context,
      title: 'Select style',
      searchHint: 'Search style',
      options: PostStyleOptions.all,
      selectedIds: Set<String>.from(_selectedStyleIds),
      mode: PostPickerSelectionMode.multiCheckbox,
      maxSelections: PostStyleOptions.maxSelections,
      onSelectionChanged: (ids) {
        setState(() {
          _selectedStyleIds
            ..clear()
            ..addAll(ids);
        });
      },
    );
  }

  String? get _mediumTrailing =>
      PostMediumOptions.byId(_selectedMediumId ?? '')?.name;

  String? get _styleTrailing {
    if (_selectedStyleIds.isEmpty) return null;
    if (_selectedStyleIds.length == 1) {
      return PostStyleOptions.byId(_selectedStyleIds.first)?.name;
    }
    return '${_selectedStyleIds.length}/${PostStyleOptions.maxSelections}';
  }

  Future<void> _openMaterialsPage() async {
    final result = await Navigator.push<List<PostMaterialOption>>(
      context,
      MaterialPageRoute<List<PostMaterialOption>>(
        builder: (_) => AddMaterialsPage(
          previewImagePath: widget.imagePaths[widget.previewImageIndex],
          transform: widget.transforms[widget.previewImageIndex],
          initialMaterials: List<PostMaterialOption>.from(_selectedMaterials),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedMaterials
          ..clear()
          ..addAll(result);
      });
    }
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
    final selected = await showModalBottomSheet<PieceSummary?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) =>
          _LinkedPiecePickerSheet(pieces: pieces, selectedId: _linkedPieceId),
    );
    if (!mounted) return;
    setState(() {
      _linkedPieceId = selected?.id;
      _linkedPieceLabel = selected?.title;
    });
  }

  Future<void> _openSeriesPicker() async {
    final result = await SeriesPickerSheet.show(
      context,
      selectedSeriesId: _selectedSeriesId,
      newSeriesName: _newSeriesName,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (!result.hasSelection) {
        _selectedSeriesId = null;
        _newSeriesName = null;
        _seriesLabel = null;
      } else {
        _selectedSeriesId = result.selectedSeriesId;
        _newSeriesName = result.newSeriesName;
        _seriesLabel = result.displayLabel;
      }
    });
  }

  String get _title =>
      widget.postType == 'scene' ? 'Create scene' : 'Create piece';

  PostDraft _buildDraft() {
    ListingDetails? listingDetails;
    if (_isPiece) {
      listingDetails = _listingFormKey.currentState?.buildListingDetails();
    }

    return PostDraft(
      postType: widget.postType,
      imagePaths: widget.imagePaths,
      mediaKind: widget.mediaKind,
      videoPath: widget.videoPath,
      videoThumbnailBytes: widget.videoThumbnailBytes,
      title: _nameController.text,
      description: _descriptionController.text,
      mediumId: _selectedMediumId,
      styleTags: _selectedStyleIds.toList(),
      location: _selectedLocation?.displayName,
      materials: List<PostMaterialOption>.from(_selectedMaterials),
      listingDetails: listingDetails,
      selectedSeriesId: _selectedSeriesId,
      newSeriesName: _newSeriesName,
      transforms: widget.transforms,
      previewImageIndex: widget.previewImageIndex,
      aiDisclosed: _aiToolsUsed,
      linkedPieceId: _linkedPieceId,
      isProcess: _isProcess,
      isForSale: _isPiece && _listForSale,
    );
  }

  Future<void> _publish(PostDraft draft) async {
    setState(() => _publishing = true);
    showUploadingDialog(context, message: 'Publishing…');
    try {
      await PostPublishService.instance.publish(draft);
      if (!mounted) return;
      hideUploadingDialog(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      final message = draft.isForSale
          ? 'Piece listed for sale'
          : 'Published successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.white,
          elevation: 6,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF3BA55D),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      hideUploadingDialog(context);
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  bool _validate() {
    if (_isPiece && _listForSale) {
      final form = _listingFormKey.currentState;
      if (form == null || !form.isPriceValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price to list for sale')),
        );
        return false;
      }
    }
    return true;
  }

  void _onSave() {
    if (!_validate()) return;
    _publish(_buildDraft().copyWith(status: 'draft'));
  }

  void _onNext() {
    if (!_validate()) return;
    setState(() => _reviewMode = true);
  }

  void _onBackToEdit() {
    setState(() => _reviewMode = false);
  }

  void _onCreate() {
    _publish(_buildDraft());
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !_reviewMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBackToEdit();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          CreateFlowBanner(
            topInset: topInset,
            title: _title,
            onClose: widget.onClose,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: _reviewMode ? _buildSummary() : _buildEditableForm(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
            child: Row(
              children: [
                CreateFlowBottomButton(
                  label: _reviewMode ? 'Back' : 'Save',
                  backgroundColor: _neutral700,
                  textColor: HomeFeedTokens.textInverse,
                  width: 68,
                  onTap: _publishing
                      ? null
                      : (_reviewMode ? _onBackToEdit : _onSave),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CreateFlowBottomButton(
                    label: _reviewMode ? 'Publish' : 'Next',
                    backgroundColor: _neutral300,
                    textColor: HomeFeedTokens.textPrimary,
                    onTap: _publishing
                        ? null
                        : (_reviewMode ? _onCreate : _onNext),
                    child: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEditableForm() {
    return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 13),
                  Center(
                    child: widget.mediaKind == 'video'
                        ? _VideoPreviewCard(
                            thumbnailBytes: widget.videoThumbnailBytes,
                            onEdit: widget.onEdit,
                          )
                        : _PreviewCard(
                            imagePath:
                                widget.imagePaths[widget.previewImageIndex],
                            transform:
                                widget.transforms[widget.previewImageIndex],
                            onEdit: widget.onEdit,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: CreateFlowTextField(
                      controller: _nameController,
                      hint: widget.postType == 'scene'
                          ? 'Give this scene a name'
                          : 'Give this piece a name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: createFlowHorizontalInset,
                    ),
                    child: CreateFlowDivider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: CreateFlowTextField(
                      controller: _descriptionController,
                      hint:
                          'Tell us what was happening in the studio. The more you share,\nthe further it travels.',
                      style: CreateFlowTextFieldStyle.body,
                      maxLines: 4,
                      minLines: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: createFlowHorizontalInset,
                    ),
                    child: CreateFlowDivider(),
                  ),
                  const SizedBox(height: 4),
                  CreateFlowMetadataRow(
                    iconAsset: PostMediaAssets.createLocationIcon,
                    iconWidth: 12,
                    iconHeight: 16,
                    label: 'Location',
                    trailing: _selectedLocation?.name,
                    onTap: _openLocationPicker,
                  ),
                  CreateFlowMetadataRow(
                    iconAsset: PostMediaAssets.createMediumIcon,
                    iconWidth: 12,
                    iconHeight: 11,
                    label: 'Medium',
                    trailing: _mediumTrailing,
                    onTap: _openMediumPicker,
                  ),
                  CreateFlowMetadataRow(
                    iconAsset: PostMediaAssets.createStyleIcon,
                    iconWidth: 12,
                    iconHeight: 12,
                    label: 'Style',
                    trailing: _styleTrailing,
                    onTap: _openStylePicker,
                  ),
                  CreateFlowMetadataRow(
                    iconAsset: PostMediaAssets.createMaterialsIcon,
                    iconWidth: 12,
                    iconHeight: 11,
                    label: 'Materials used',
                    countBadge: _selectedMaterials.isEmpty
                        ? null
                        : _selectedMaterials.length,
                    onTap: _openMaterialsPage,
                  ),
                  if (_isPiece) ...[
                    CreateFlowMetadataRow(
                      iconAsset: PostMediaAssets.createSeriesIcon,
                      iconWidth: 13,
                      iconHeight: 13,
                      label: 'Series',
                      trailing: _seriesLabel,
                      onTap: _openSeriesPicker,
                    ),
                    CreateFlowMetadataRow(
                      iconAsset: PostMediaAssets.createScenesIcon,
                      iconWidth: 12,
                      iconHeight: 11,
                      label: 'Related scenes',
                      onTap: () {},
                    ),
                  ] else ...[
                    CreateFlowMetadataRow(
                      iconAsset: PostMediaAssets.createScenesIcon,
                      iconWidth: 12,
                      iconHeight: 11,
                      label: 'Link to piece',
                      trailing: _linkedPieceLabel,
                      onTap: _openLinkedPiecePicker,
                    ),
                    CreateFlowToggleRow(
                      label: 'Process / work-in-progress scene',
                      value: _isProcess,
                      onChanged: (value) => setState(() => _isProcess = value),
                    ),
                  ],
                  CreateFlowToggleRow(
                    label: 'AI tools used',
                    iconAsset: PostMediaAssets.createAiToolsIcon,
                    value: _aiToolsUsed,
                    onChanged: (value) => setState(() => _aiToolsUsed = value),
                  ),
                  if (_isPiece) ...[
                    CreateFlowToggleRow(
                      label: 'List for sale',
                      value: _listForSale,
                      onChanged: _onListForSaleChanged,
                    ),
                    ListingDetailsForm(
                      key: _listingFormKey,
                      showSaleFields: _listForSale,
                    ),
                  ],
                ],
    );
  }

  /// Read-only recap of everything entered so far — reuses the same values
  /// as [_buildEditableForm] but as plain text (no fields, no chevrons, no
  /// toggles, no edit affordance on the preview image), so this reads as a
  /// summary to confirm rather than a second copy of the editable form.
  Widget _buildSummary() {
    ListingDetails? listingDetails;
    if (_isPiece && _listForSale) {
      listingDetails = _listingFormKey.currentState?.buildListingDetails();
    }
    final materialsLabel = _selectedMaterials.isEmpty
        ? null
        : _selectedMaterials.map((m) => m.name).join(', ');
    final title = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 13),
        Center(
          child: widget.mediaKind == 'video'
              ? _VideoPreviewCard(thumbnailBytes: widget.videoThumbnailBytes)
              : _PreviewCard(
                  imagePath: widget.imagePaths[widget.previewImageIndex],
                  transform: widget.transforms[widget.previewImageIndex],
                ),
        ),
        const SizedBox(height: 24),
        if (title.isNotEmpty) _summaryRow('Name', title),
        if (description.isNotEmpty) _summaryRow('Description', description),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: createFlowHorizontalInset,
            vertical: 8,
          ),
          child: CreateFlowDivider(),
        ),
        if (_selectedLocation != null)
          _summaryRow('Location', _selectedLocation!.name),
        if (_mediumTrailing != null) _summaryRow('Medium', _mediumTrailing!),
        if (_styleTrailing != null) _summaryRow('Style', _styleTrailing!),
        if (materialsLabel != null) _summaryRow('Materials', materialsLabel),
        if (_isPiece) ...[
          if (_seriesLabel != null) _summaryRow('Series', _seriesLabel!),
        ] else ...[
          if (_linkedPieceLabel != null)
            _summaryRow('Link to piece', _linkedPieceLabel!),
          if (_isProcess) _summaryRow('Process / work-in-progress', 'Yes'),
        ],
        if (_aiToolsUsed) _summaryRow('AI tools used', 'Yes'),
        if (_isPiece && _listForSale) ...[
          _summaryRow('List for sale', 'Yes'),
          if (listingDetails?.priceUsd != null)
            _summaryRow(
              'Price',
              '\$${listingDetails!.priceUsd!.toStringAsFixed(2)}',
            ),
          if (listingDetails?.dimensionsString != null)
            _summaryRow('Dimensions', listingDetails!.dimensionsString!),
          if (listingDetails?.framingMounting?.trim().isNotEmpty == true)
            _summaryRow(
              'Framing/mounting',
              listingDetails!.framingMounting!.trim(),
            ),
          if (listingDetails?.provenance?.trim().isNotEmpty == true)
            _summaryRow('Provenance', listingDetails!.provenance!.trim()),
          if (listingDetails?.yearCreated != null)
            _summaryRow('Year created', '${listingDetails!.yearCreated}'),
          if (listingDetails?.handlingNotes?.trim().isNotEmpty == true)
            _summaryRow(
              'Handling notes',
              listingDetails!.handlingNotes!.trim(),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8C8880),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textInverse,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({this.thumbnailBytes, this.onEdit});

  static const _cardWidth = 200.0;
  static const _cardHeight = 266.0;
  static const _cardRadius = 8.0;

  final Uint8List? thumbnailBytes;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      height: _cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_cardRadius),
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
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 56,
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    PostMediaAssets.createPencilIcon,
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.imagePath,
    required this.transform,
    this.onEdit,
  });

  static const _cardWidth = 200.0;
  static const _cardRadius = 8.0;

  final String imagePath;
  final PostImageTransform transform;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PostCropPreview(
            imagePath: imagePath,
            transform: transform,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          if (onEdit != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    PostMediaAssets.createPencilIcon,
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single-select picker for linking a scene to one of the user's pieces.
class _LinkedPiecePickerSheet extends StatelessWidget {
  const _LinkedPiecePickerSheet({required this.pieces, this.selectedId});

  final List<PieceSummary> pieces;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF231F1B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A4843),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Link to piece',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: pieces.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'You don\'t have any pieces yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF8C8880),
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            8,
                            0,
                            8,
                            safeAreaBottom + 16,
                          ),
                          children: [
                            _LinkedPieceTile(
                              title: 'None',
                              selected: selectedId == null,
                              onTap: () => Navigator.pop(context),
                            ),
                            for (final piece in pieces)
                              _LinkedPieceTile(
                                title: piece.title,
                                selected: selectedId == piece.id,
                                onTap: () => Navigator.pop(context, piece),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkedPieceTile extends StatelessWidget {
  const _LinkedPieceTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.white : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

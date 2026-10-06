import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


import '../data/post_material_options.dart';
import '../data/post_location_options.dart';
import '../data/post_picker_options.dart';
import '../data/post_media_assets.dart';
import '../models/listing_details.dart';
import '../models/post_summary.dart';
import '../models/post_image_transform.dart';
import '../services/auth_session.dart';
import '../services/api_exception.dart';
import '../services/post_service.dart';
import '../services/post_publish_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/create_flow_widgets.dart';
import '../widgets/create_flow/listing_details_form.dart';
import '../widgets/create_flow/piece_availability_form.dart';
import '../widgets/create_flow/piece_details_form.dart';
import '../widgets/create_flow/related_scenes_picker_page.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/post_create_option_sheet.dart';
import '../widgets/post_crop_preview.dart';
import '../utils/payout_setup.dart';
import '../widgets/publish_result_overlays.dart';
import 'add_materials_page.dart';
import '../theme/app_fonts.dart';

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
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _pieceDetailsKey = GlobalKey<PieceDetailsFormState>();
  final _listingFormKey = GlobalKey<ListingDetailsFormState>();
  bool _aiToolsUsed = false;
  bool _publishing = false;
  bool _publishSuccess = false;
  bool _publishFailed = false;
  bool _listForSale = false;
  bool? _forSaleChoice;
  String? _sellMode;
  int _auctionDays = 3;
  int _pieceTab = 0;
  int _unlockedTab = 0;
  PostLocationOption? _selectedLocation;
  String? _selectedMediumId;
  final Set<String> _selectedStyleIds = {};
  final List<PostMaterialOption> _selectedMaterials = [];
  String? _selectedSeriesId;
  String? _newSeriesName;
  String? _seriesLabel;
  final Set<String> _relatedSceneIds = {};

  bool get _isPiece => widget.postType == 'piece';

  @override
  void initState() {
    super.initState();
    _listForSale = false;
    _priceController.addListener(_onPriceChanged);
    _nameController.addListener(_onPriceChanged);
  }

  void _onPriceChanged() {
    if (_isPiece) setState(() {});
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _nameController.removeListener(_onPriceChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _onPieceForSaleChanged(bool value) async {
    if (!value) {
      setState(() {
        _forSaleChoice = false;
        _listForSale = false;
        _sellMode = null;
      });
      return;
    }
    final allowed = await ensureCanListForSale(context);
    if (!mounted) return;
    if (allowed) {
      setState(() {
        _forSaleChoice = true;
        _listForSale = true;
      });
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
      title: 'Medium',
      subtitle: 'Choose one',
      searchHint: 'Search medium',
      options: PostMediumOptions.all,
      selectedIds: _selectedMediumId != null ? {_selectedMediumId!} : const {},
      mode: PostPickerSelectionMode.singleRadio,
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
      title: 'Style',
      subtitle: 'Choose up to 3',
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

  String? get _pieceStyleTrailing {
    if (_selectedStyleIds.isEmpty) return null;
    final names = _selectedStyleIds
        .map((id) => PostStyleOptions.byId(id)?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  String? get _pieceMaterialsTrailing {
    if (_selectedMaterials.isEmpty) return null;
    return '${_selectedMaterials.length} added';
  }

  String? get _relatedScenesTrailing {
    if (_relatedSceneIds.isEmpty) return null;
    return '${_relatedSceneIds.length} linked';
  }

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

  Future<void> _openRelatedScenesPicker() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return;
    List<PostSummary> scenes;
    try {
      scenes = await PostService.instance.getUserPosts(username);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your scenes')),
      );
      return;
    }
    if (!mounted) return;
    final selected = await RelatedScenesPickerPage.show(
      context,
      scenes: scenes,
      selectedIds: Set<String>.from(_relatedSceneIds),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _relatedSceneIds
        ..clear()
        ..addAll(selected);
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

  PostDraft _buildDraft() {
    ListingDetails? listingDetails;
    if (_isPiece) {
      listingDetails =
          _pieceDetailsKey.currentState?.buildListingDetails() ??
          _listingFormKey.currentState?.buildListingDetails();
      final priceUsd = double.tryParse(_priceController.text.trim());
      if (listingDetails != null) {
        listingDetails = listingDetails.copyWith(
          priceUsd: priceUsd ?? listingDetails.priceUsd,
          listingType: _listForSale ? _sellMode : listingDetails.listingType,
          auctionDurationDays: _listForSale && _sellMode == 'auction'
              ? _auctionDays
              : listingDetails.auctionDurationDays,
          location: _selectedLocation?.name ?? listingDetails.location,
        );
      } else if (_listForSale) {
        listingDetails = ListingDetails(
          priceUsd: priceUsd,
          listingType: _sellMode,
          auctionDurationDays: _sellMode == 'auction' ? _auctionDays : null,
        );
      }
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
      relatedSceneIds: _relatedSceneIds.toList(),
      isForSale: _isPiece && _listForSale,
    );
  }

  Future<void> _publish(PostDraft draft) async {
    setState(() {
      _publishing = true;
      _publishFailed = false;
    });
    try {
      await PostPublishService.instance.publish(draft);
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

  bool get _priceValid {
    final price = double.tryParse(_priceController.text.trim());
    return price != null && price > 0;
  }

  bool get _detailsContinueEnabled {
    if (_nameController.text.trim().isEmpty) return false;
    if (!_listForSale) return true;
    return _selectedMediumId != null &&
        (_pieceDetailsKey.currentState?.hasDimensions ?? false);
  }

  bool get _availabilityComplete {
    if (_forSaleChoice == false) return true;
    if (_forSaleChoice != true) return false;
    if (_sellMode == 'fixed') return _priceValid;
    if (_sellMode == 'auction') {
      return _priceValid &&
          _auctionDays >= PieceAvailabilityForm.minAuctionDays &&
          _auctionDays <= PieceAvailabilityForm.maxAuctionDays;
    }
    return false;
  }

  bool _validate() {
    if (_isPiece && _listForSale) {
      if (!_priceValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price to list for sale')),
        );
        return false;
      }
      if (_sellMode == 'auction' &&
          (_auctionDays < PieceAvailabilityForm.minAuctionDays ||
              _auctionDays > PieceAvailabilityForm.maxAuctionDays)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auction duration must be 3–14 days')),
        );
        return false;
      }
    }
    return true;
  }

  bool _validateDetailsForContinue() {
    if (!_isPiece || !_listForSale) return true;
    if (_selectedMediumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a medium to list for sale')),
      );
      return false;
    }
    final form = _pieceDetailsKey.currentState;
    if (form == null || !form.hasDimensions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter width and height to list for sale'),
        ),
      );
      return false;
    }
    return true;
  }

  void _onCreate() {
    _publish(_buildDraft());
  }

  void _onPieceBannerBack() {
    if (_pieceTab > 0) {
      setState(() => _pieceTab -= 1);
      return;
    }
    (widget.onEdit ?? widget.onClose)();
  }

  void _onPieceContinue() {
    if (_pieceTab == 0) {
      if (!_availabilityComplete) return;
      setState(() {
        _pieceTab = 1;
        if (_unlockedTab < 1) _unlockedTab = 1;
      });
      return;
    }
    if (_pieceTab == 1) {
      if (!_validateDetailsForContinue()) return;
      setState(() {
        _pieceTab = 2;
        _unlockedTab = 2;
      });
      return;
    }
    _onCreate();
  }

  @override
  Widget build(BuildContext context) {
    return _buildPieceFlow(context);
  }

  Widget _buildPieceFlow(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final continueEnabled = _pieceTab == 0
        ? _availabilityComplete
        : _pieceTab == 1
        ? _detailsContinueEnabled
        : !_publishing;
    final ctaLabel = _pieceTab == 2 ? 'Publish' : 'Save and continue';

    return StudioPublishFlowGate(
      publishing: _publishing,
      success: _publishSuccess,
      failure: _publishFailed,
      publishingMessage: 'Publishing your piece...',
      successTitle: 'Your piece is live',
      onSuccessDismiss: _finishPublishSuccess,
      onRetry: () => _publish(_buildDraft()),
      imagePath: widget.imagePaths.isEmpty
          ? null
          : widget.imagePaths[widget.previewImageIndex],
      transform: widget.transforms.isEmpty
          ? null
          : widget.transforms[widget.previewImageIndex],
      videoThumbnailBytes: widget.videoThumbnailBytes,
      child: PopScope(
        canPop:
            _pieceTab == 0 &&
            !_publishing &&
            !_publishSuccess &&
            !_publishFailed,
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
          _onPieceBannerBack();
        },
        child: Scaffold(
          backgroundColor: HomeFeedTokens.background,
          body: Column(
            children: [
              CreateFlowBanner(
                topInset: topInset,
                title: 'Piece',
                onClose: _onPieceBannerBack,
                useBackChevron: true,
                height: 53,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildPieceCoverAndTabs(),
                      if (_pieceTab == 0)
                        PieceAvailabilityForm(
                          forSale: _forSaleChoice,
                          sellMode: _sellMode,
                          auctionDays: _auctionDays,
                          priceController: _priceController,
                          onForSaleChanged: _onPieceForSaleChanged,
                          onSellModeChanged: (mode) {
                            setState(() => _sellMode = mode);
                          },
                          onAuctionDaysChanged: (days) {
                            setState(() => _auctionDays = days);
                          },
                        ),
                      Visibility(
                        visible: _pieceTab == 1,
                        maintainState: true,
                        maintainAnimation: true,
                        child: PieceDetailsForm(
                          key: _pieceDetailsKey,
                          titleController: _nameController,
                          descriptionController: _descriptionController,
                          locationTrailing: _selectedLocation?.name,
                          mediumTrailing: _mediumTrailing,
                          styleTrailing: _pieceStyleTrailing,
                          materialsTrailing: _pieceMaterialsTrailing,
                          seriesTrailing: _seriesLabel,
                          relatedScenesTrailing: _relatedScenesTrailing,
                          onLocation: _openLocationPicker,
                          onMedium: _openMediumPicker,
                          onStyle: _openStylePicker,
                          onMaterials: _openMaterialsPage,
                          onSeries: _openSeriesPicker,
                          onRelatedScenes: _openRelatedScenesPicker,
                          onChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      if (_pieceTab == 2) _buildSummary(),
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
                    backgroundColor: HomeFeedTokens.neutral800,
                    textColor: HomeFeedTokens.textInverse,
                    onTap: _publishing || !continueEnabled
                        ? null
                        : _onPieceContinue,
                    child: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HomeFeedTokens.textInverse,
                            ),
                          )
                        : Text(
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

  Widget _buildPieceCoverAndTabs() {
    const tabLabels = ['Availability', 'Details', 'Review'];
    return Column(
      children: [
        const SizedBox(height: 11),
        Center(
          child: _PieceCoverPreview(
            imagePath: widget.imagePaths[widget.previewImageIndex],
            transform: widget.transforms[widget.previewImageIndex],
            onEdit: widget.onEdit,
            counterLabel:
                '${widget.previewImageIndex + 1}/${widget.imagePaths.length}',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _pieceTabButton(
                    index: 0,
                    label: tabLabels[0],
                    alignment: Alignment.centerLeft,
                  ),
                  _pieceTabButton(
                    index: 1,
                    label: tabLabels[1],
                    alignment: Alignment.center,
                  ),
                  _pieceTabButton(
                    index: 2,
                    label: tabLabels[2],
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
              const Positioned(
                left: -24,
                right: -24,
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

  Widget _pieceTabButton({
    required int index,
    required String label,
    required Alignment alignment,
  }) {
    final selected = index == _pieceTab;
    return Expanded(
      child: Align(
        alignment: alignment,
        child: GestureDetector(
          onTap: index <= _unlockedTab
              ? () => setState(() => _pieceTab = index)
              : null,
          behavior: HitTestBehavior.opaque,
          child: IntrinsicWidth(
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
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected
                        ? HomeFeedTokens.textPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Read-only recap of everything entered so far.
  Widget _buildSummary() {
    ListingDetails? listingDetails;
    if (_isPiece) {
      listingDetails = _pieceDetailsKey.currentState?.buildListingDetails();
      if (_listForSale) {
        final priceUsd = double.tryParse(_priceController.text.trim());
        if (listingDetails != null && priceUsd != null) {
          listingDetails = listingDetails.copyWith(
            priceUsd: priceUsd,
            listingType: _sellMode,
            auctionDurationDays: _sellMode == 'auction' ? _auctionDays : null,
          );
        }
      }
    }
    final materialsLabel = _selectedMaterials.isEmpty
        ? null
        : _selectedMaterials.map((m) => m.name).join(', ');
    final title = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (_seriesLabel != null) _summaryRow('Series', _seriesLabel!),
        if (_relatedScenesTrailing != null)
          _summaryRow('Related scenes', _relatedScenesTrailing!),
        if (_aiToolsUsed) _summaryRow('AI tools used', 'Yes'),
        if (_isPiece && listingDetails?.dimensionsString != null)
          _summaryRow('Dimensions', listingDetails!.dimensionsString!),
        if (_isPiece && listingDetails?.yearCreated != null)
          _summaryRow('Year created', '${listingDetails!.yearCreated}'),
        if (_isPiece &&
            listingDetails?.framingMounting?.trim().isNotEmpty == true)
          _summaryRow(
            'Framing/mounting',
            listingDetails!.framingMounting!.trim(),
          ),
        if (_isPiece &&
            listingDetails?.handlingNotes?.trim().isNotEmpty == true)
          _summaryRow('Handling notes', listingDetails!.handlingNotes!.trim()),
        if (_isPiece && !_listForSale && _forSaleChoice == false)
          _summaryRow('List for sale', 'No'),
        if (_isPiece && _listForSale) ...[
          _summaryRow('List for sale', 'Yes'),
          if (_sellMode == 'fixed') _summaryRow('Sale type', 'Fixed price'),
          if (_sellMode == 'auction') ...[
            _summaryRow('Sale type', 'Auction'),
            _summaryRow('Duration', '$_auctionDays days'),
          ],
          if (listingDetails?.priceUsd != null)
            _summaryRow(
              _sellMode == 'auction' ? 'Starting bid' : 'Price',
              '\$${listingDetails!.priceUsd!.toStringAsFixed(2)}',
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
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8C8880),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieceCoverPreview extends StatelessWidget {
  const _PieceCoverPreview({
    required this.imagePath,
    required this.transform,
    required this.counterLabel,
    this.onEdit,
  });

  static const _width = 156.0;
  static const _height = 197.0;
  static const _radius = 8.0;

  final String imagePath;
  final PostImageTransform transform;
  final String counterLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PostCropPreview(
            imagePath: imagePath,
            transform: transform,
            borderRadius: BorderRadius.circular(_radius),
            frameSize: const Size(_width, _height),
          ),
          if (onEdit != null)
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

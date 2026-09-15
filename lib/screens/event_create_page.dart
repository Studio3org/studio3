import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_location_options.dart';
import '../data/post_material_options.dart';
import '../data/post_media_assets.dart';
import '../data/post_picker_options.dart';
import '../models/post_image_transform.dart';
import '../models/post_summary.dart';
import '../services/auth_session.dart';
import '../services/post_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/piece_details_form.dart';
import '../widgets/create_flow/related_scenes_picker_page.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/post_create_option_sheet.dart';
import '../widgets/post_crop_preview.dart';
import '../widgets/publish_result_overlays.dart';
import 'add_materials_page.dart';

const _kSteps = ['Tickets', 'Details', 'Itinerary', 'Lineup', 'Review'];

/// Event details wizard — Figma `2862:15395` (Tickets) plus later steps.
class EventCreatePage extends StatefulWidget {
  const EventCreatePage({
    super.key,
    required this.imagePath,
    required this.transform,
    required this.onClose,
    required this.onEdit,
  });

  final String imagePath;
  final PostImageTransform transform;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  static const _hairline = Color(0xFFC8C5BC);
  static const _modeFill = Color(0xFF2A2622);
  static const _modeBorder = Color(0xFF352F2A);

  int _step = 0;
  bool? _paid;
  String? _ticketMode;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _when = TextEditingController();
  final _lineup = TextEditingController();
  final _included = TextEditingController();
  final _ticketPrice = TextEditingController(text: '25');
  final _capacity = TextEditingController();
  final _pieceDetailsKey = GlobalKey<PieceDetailsFormState>();
  PostLocationOption? _selectedLocation;
  String? _selectedMediumId;
  final Set<String> _selectedStyleIds = {};
  final List<PostMaterialOption> _selectedMaterials = [];
  String? _selectedSeriesId;
  String? _newSeriesName;
  String? _seriesLabel;
  final Set<String> _relatedSceneIds = {};
  bool _publishing = false;
  bool _publishSuccess = false;

  void _onTitleChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    _description.dispose();
    _venue.dispose();
    _when.dispose();
    _lineup.dispose();
    _included.dispose();
    _ticketPrice.dispose();
    _capacity.dispose();
    super.dispose();
  }

  TextStyle _geist({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = HomeFeedTokens.textPrimary,
  }) {
    return GoogleFonts.geist(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  bool get _canContinue => switch (_step) {
        0 => _paid == false || (_paid == true && _ticketMode != null),
        1 => _title.text.trim().isNotEmpty,
        2 => _when.text.trim().isNotEmpty || _venue.text.trim().isNotEmpty,
        3 => true,
        _ => true,
      };

  Future<void> _saveAndContinue() async {
    if (!_canContinue) return;
    if (_step < _kSteps.length - 1) {
      setState(() => _step += 1);
      return;
    }
    setState(() => _publishing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _publishing = false;
      _publishSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step > 0) {
          setState(() => _step -= 1);
        } else {
          widget.onClose();
        }
      },
      child: StudioPublishFlowGate(
        publishing: _publishing,
        success: _publishSuccess,
        failure: false,
        publishingMessage: 'Publishing event…',
        successTitle: 'Event posted',
        onSuccessDismiss: widget.onClose,
        onRetry: _saveAndContinue,
        imagePath: widget.imagePath,
        transform: widget.transform,
        child: Scaffold(
          backgroundColor: HomeFeedTokens.background,
          body: Column(
            children: [
              _banner(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 11),
                    Center(
                      child: _EventCoverPreview(
                        imagePath: widget.imagePath,
                        transform: widget.transform,
                        onEdit: widget.onEdit,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _stepper(),
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Color(0xFFC8C5BC),
                    ),
                    switch (_step) {
                      0 => _ticketsBody(),
                      1 => _detailsBody(),
                      2 => _itineraryBody(),
                      3 => _lineupBody(),
                      _ => _reviewBody(),
                    },
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
                  child: Opacity(
                    opacity: _canContinue ? 1 : 0.4,
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton(
                        onPressed: _canContinue ? _saveAndContinue : null,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: HomeFeedTokens.neutral800,
                          disabledForegroundColor: HomeFeedTokens.textInverse,
                          backgroundColor: HomeFeedTokens.neutral800,
                          foregroundColor: HomeFeedTokens.textInverse,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _step == _kSteps.length - 1
                              ? 'Publish event'
                              : 'Save and continue',
                          style: _geist(
                            size: 16,
                            color: HomeFeedTokens.textInverse,
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
    );
  }

  Widget _banner() {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 53,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_step > 0) {
                      setState(() => _step -= 1);
                    } else {
                      widget.onClose();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    PostMediaAssets.createBannerBack,
                    width: 7,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      HomeFeedTokens.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Event',
                  style: _geist(size: 16, weight: FontWeight.w500),
                ),
                const Spacer(),
                const SizedBox(width: 36, height: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _kSteps.length; i++)
            GestureDetector(
              onTap: () {
                if (i <= _step) setState(() => _step = i);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kSteps[i],
                    style: _geist(
                      size: 13,
                      weight: i == _step ? FontWeight.w500 : FontWeight.w400,
                      color: i == _step
                          ? HomeFeedTokens.textPrimary
                          : HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 47,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i == _step
                            ? HomeFeedTokens.textPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ticketsBody() {
    return Column(
      children: [
        _ticketSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Is this a paid event?',
                style: _geist(
                  size: 13,
                  weight: FontWeight.w500,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton(
                      label: 'Yes',
                      selected: _paid == true,
                      onTap: () => setState(() {
                        _paid = true;
                        _ticketMode ??= 'fixed';
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _choiceButton(
                      label: 'Free/RSVP',
                      selected: _paid == false,
                      onTap: () => setState(() {
                        _paid = false;
                        _ticketMode = null;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_paid == true) ...[
          _ticketSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Admission',
                  style: _geist(
                    size: 13,
                    weight: FontWeight.w500,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _sellModeCard(
                  title: 'Fixed price',
                  subtitle: 'One price, first to buy',
                  selected: _ticketMode == 'fixed',
                  onTap: () => setState(() => _ticketMode = 'fixed'),
                ),
                const SizedBox(height: 16),
                _sellModeCard(
                  title: 'Auction',
                  subtitle: '3 - 14 days, highest bid wins',
                  selected: _ticketMode == 'auction',
                  onTap: () => setState(() => _ticketMode = 'auction'),
                ),
              ],
            ),
          ),
          _ticketSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Admission',
                  style: _geist(
                    size: 13,
                    weight: FontWeight.w500,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _includedField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _priceChip(),
                    const SizedBox(width: 10),
                    Expanded(child: _capacityField()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _ticketSection({required Widget child}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  Widget _choiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? HomeFeedTokens.neutral800 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(color: HomeFeedTokens.textPrimary),
        ),
        child: Text(
          label,
          style: _geist(
            size: 16,
            color: selected
                ? HomeFeedTokens.textInverse
                : HomeFeedTokens.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _sellModeCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _modeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? null : Border.all(color: _modeBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: _geist(
                size: 14,
                weight: FontWeight.w500,
                color: selected
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: _geist(
                size: 12,
                color: selected
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _includedField() {
    return Container(
      height: 42,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _modeBorder),
      ),
      child: TextField(
        controller: _included,
        cursorColor: HomeFeedTokens.textPrimary,
        style: _geist(size: 12, color: HomeFeedTokens.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'What’s included',
          hintStyle: _geist(size: 12, color: HomeFeedTokens.textSecondary),
        ),
      ),
    );
  }

  Widget _priceChip() {
    return Container(
      width: 74,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\$',
            style: _geist(size: 10, color: HomeFeedTokens.textSecondary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _ticketPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              cursorColor: HomeFeedTokens.textPrimary,
              style: _geist(size: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _capacityField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: Center(
        child: TextField(
          controller: _capacity,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: HomeFeedTokens.textPrimary,
          style: _geist(size: 12),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Capacity',
            hintStyle: _geist(size: 12, color: HomeFeedTokens.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _geist(
              size: 13,
              weight: FontWeight.w500,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            cursorColor: HomeFeedTokens.textPrimary,
            style: _geist(size: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _geist(size: 16, color: HomeFeedTokens.textSecondary),
              isDense: true,
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFC8C5BC)),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFC8C5BC)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: HomeFeedTokens.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsBody() {
    return PieceDetailsForm(
      key: _pieceDetailsKey,
      titleController: _title,
      descriptionController: _description,
      locationTrailing: _selectedLocation?.displayName,
      mediumTrailing: PostMediumOptions.byId(_selectedMediumId ?? '')?.name,
      styleTrailing: _styleTrailing,
      materialsTrailing: _selectedMaterials.isEmpty
          ? null
          : '${_selectedMaterials.length} added',
      seriesTrailing: _seriesLabel,
      relatedScenesTrailing: _relatedSceneIds.isEmpty
          ? null
          : '${_relatedSceneIds.length} linked',
      onLocation: _openLocationPicker,
      onMedium: _openMediumPicker,
      onStyle: _openStylePicker,
      onMaterials: _openMaterialsPage,
      onSeries: _openSeriesPicker,
      onRelatedScenes: _openRelatedScenesPicker,
      onChanged: () => setState(() {}),
    );
  }

  String? get _styleTrailing {
    if (_selectedStyleIds.isEmpty) return null;
    final names = _selectedStyleIds
        .map((id) => PostStyleOptions.byId(id)?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return null;
    return names.join(', ');
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

  Widget _itineraryBody() {
    return Column(
      children: [
        _field(
          label: 'Date & time',
          controller: _when,
          hint: 'Sat, July 25th · 8:00PM',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _lineupBody() {
    return Column(
      children: [
        _field(
          label: 'Featured artists',
          controller: _lineup,
          hint: 'Amara, Cedric, Daisy',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _reviewBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title.text.trim().isEmpty ? 'Untitled event' : _title.text.trim(),
            style: _geist(size: 16, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _paid == true ? 'Paid event' : 'Free / RSVP',
            style: _geist(size: 13, color: HomeFeedTokens.textSecondary),
          ),
          if (_venue.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_venue.text.trim(), style: _geist(size: 13)),
          ],
          if (_when.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_when.text.trim(), style: _geist(size: 13)),
          ],
        ],
      ),
    );
  }
}

class _EventCoverPreview extends StatelessWidget {
  const _EventCoverPreview({
    required this.imagePath,
    required this.transform,
    this.onEdit,
  });

  static const _width = 156.0;
  static const _height = 197.0;

  final String imagePath;
  final PostImageTransform transform;
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
            borderRadius: BorderRadius.circular(8),
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
                '1/1',
                style: GoogleFonts.geist(
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

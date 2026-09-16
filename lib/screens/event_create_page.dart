import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_location_options.dart';
import '../data/post_media_assets.dart';
import '../data/post_picker_options.dart';
import '../models/post_image_transform.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/event_date_sheet.dart';
import '../widgets/create_flow/event_ticket_edit_page.dart';
import '../widgets/post_create_option_sheet.dart';
import '../widgets/post_crop_preview.dart';
import '../widgets/publish_result_overlays.dart';

const _kSteps = ['Details', 'Tickets', 'Lineup', 'Review'];

/// Event details wizard — Details → Tickets → Lineup → Review.
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
  static const _disabledFill = Color(0xFFC8C5BC);

  int _step = 0;
  bool? _paid;
  final _tickets = <EventTicketTier>[];
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _lineup = TextEditingController();
  PostLocationOption? _selectedLocation;
  EventDateSelection? _eventDate;
  String? _categoryId;
  bool _isPublic = false;
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
    _lineup.dispose();
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

  bool get _hasCompleteTicket => _tickets.any((ticket) => ticket.isComplete);

  bool get _canContinue => switch (_step) {
        0 => _title.text.trim().isNotEmpty,
        1 => _paid == false || (_paid == true && _hasCompleteTicket),
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
                      0 => _detailsBody(),
                      1 => _ticketsBody(),
                      2 => _lineupBody(),
                      _ => _reviewBody(),
                    },
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: _canContinue ? _saveAndContinue : null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: _disabledFill,
                        disabledForegroundColor: HomeFeedTokens.textPrimary,
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
                          color: _canContinue
                              ? HomeFeedTokens.textInverse
                              : HomeFeedTokens.textPrimary,
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
                        if (_tickets.isEmpty) {
                          _tickets.add(
                            const EventTicketTier(name: 'General Admission'),
                          );
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _choiceButton(
                      label: 'Free/RSVP',
                      selected: _paid == false,
                      onTap: () => setState(() => _paid = false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_paid == true)
          _ticketSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket Tiers',
                  style: _geist(
                    size: 13,
                    weight: FontWeight.w500,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _tickets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ticketTierCard(_tickets[i], i),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _addTicketType,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    '+ Add ticket type',
                    style: _geist(
                      size: 13,
                      weight: FontWeight.w500,
                      color: ticketAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ticketTierCard(EventTicketTier ticket, int index) {
    final description = ticket.descriptionLine;
    final perOrder = ticket.perOrderLine;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.name.trim().isEmpty ? 'Untitled ticket' : ticket.name,
                  style: _geist(size: 13, weight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: () => _editTicket(index),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Edit',
                  style: _geist(
                    size: 12,
                    weight: FontWeight.w500,
                    color: ticketAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description ?? 'No description yet',
            style: _geist(size: 12, color: HomeFeedTokens.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            ticket.priceLine,
            style: _geist(
              size: 12,
              color: ticket.priceLineIsHint
                  ? ticketAccent
                  : HomeFeedTokens.textPrimary,
            ),
          ),
          if (perOrder != null) ...[
            const SizedBox(height: 2),
            Text(
              perOrder,
              style: _geist(size: 12, color: HomeFeedTokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTicketType() async {
    final result = await EventTicketEditPage.open(
      context,
      initial: EventTicketTier(
        name: _tickets.isEmpty ? 'General Admission' : '',
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _tickets.add(result));
  }

  Future<void> _editTicket(int index) async {
    final result = await EventTicketEditPage.open(
      context,
      initial: _tickets[index],
    );
    if (!mounted || result == null) return;
    setState(() => _tickets[index] = result);
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
    return Column(
      children: [
        _section(
          child: _LabeledOutlineField(
            label: 'Title',
            labelGap: 8,
            controller: _title,
            hint: 'Give this event a name',
            fontSize: 13,
            onChanged: (_) => setState(() {}),
          ),
        ),
        _section(
          child: _LabeledOutlineField(
            label: 'Description',
            labelGap: 16,
            controller: _description,
            hint:
                'Tell us what was happening in the studio. The more you share, the further it travels.',
            fontSize: 12,
            maxLines: 4,
            minLines: 3,
            height: null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            children: [
              _NavRow(
                label: 'Location',
                trailing: _selectedLocation?.displayName,
                onTap: _openLocationPicker,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Date',
                trailing: _eventDate?.summary,
                onTap: _openDateSheet,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Category',
                trailing: EventCategoryOptions.byId(_categoryId ?? '')?.name,
                onTap: _openCategoryPicker,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public',
                          style: _geist(
                            size: 13,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Off shows this only to people you share it with',
                          style: _geist(
                            size: 12,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: Colors.white,
                    activeTrackColor: HomeFeedTokens.neutral800,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFC8C5BC),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairline, width: 0.5)),
      ),
      child: child,
    );
  }

  void _openLocationPicker() {
    ChooseLocationSheet.show(
      context,
      onLocationSelected: (location) {
        setState(() => _selectedLocation = location);
      },
    );
  }

  Future<void> _openDateSheet() async {
    final result = await EventDateSheet.show(context, initial: _eventDate);
    if (result != null && mounted) {
      setState(() => _eventDate = result);
    }
  }

  void _openCategoryPicker() {
    PostCreateOptionSheet.show(
      context,
      title: 'Add Category',
      subtitle: 'Choose one',
      searchHint: 'Search category',
      options: EventCategoryOptions.all,
      selectedIds: _categoryId != null ? {_categoryId!} : const {},
      mode: PostPickerSelectionMode.singleRadio,
      onSelectionChanged: (ids) {
        setState(() => _categoryId = ids.isEmpty ? null : ids.first);
      },
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
          if (_paid == true)
            for (final ticket in _tickets.where((t) => t.isComplete)) ...[
              const SizedBox(height: 4),
              Text(
                '${ticket.name} · ${ticket.priceLine}',
                style: _geist(size: 13),
              ),
            ],
          if (_selectedLocation != null) ...[
            const SizedBox(height: 4),
            Text(_selectedLocation!.displayName, style: _geist(size: 13)),
          ],
          if (_eventDate != null) ...[
            const SizedBox(height: 4),
            Text(_eventDate!.summary, style: _geist(size: 13)),
          ],
          if (_categoryId != null) ...[
            const SizedBox(height: 4),
            Text(
              EventCategoryOptions.byId(_categoryId!)?.name ?? '',
              style: _geist(size: 13),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _isPublic ? 'Public' : 'Not public',
            style: _geist(size: 13, color: HomeFeedTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LabeledOutlineField extends StatelessWidget {
  const _LabeledOutlineField({
    required this.label,
    required this.labelGap,
    required this.controller,
    required this.hint,
    required this.fontSize,
    this.maxLines = 1,
    this.minLines,
    this.height = 40,
    this.onChanged,
  });

  final String label;
  final double labelGap;
  final TextEditingController controller;
  final String hint;
  final double fontSize;
  final int maxLines;
  final int? minLines;
  final double? height;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textSecondary,
          ),
        ),
        SizedBox(height: labelGap),
        Container(
          height: height,
          width: double.infinity,
          alignment: maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HomeFeedTokens.textPrimary),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            onChanged: onChanged,
            cursorColor: HomeFeedTokens.textPrimary,
            style: GoogleFonts.geist(
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: GoogleFonts.geist(
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: maxLines > 1
                  ? const EdgeInsets.all(12)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.trailing,
  });

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
              style: GoogleFonts.geist(
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
                  style: GoogleFonts.geist(
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
                'Event',
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/listing_details.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_chip.dart';
import '../studio/studio_field.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';
import '../studio/studio_switch.dart';
import '../studio/studio_tooltip.dart';
import 'post_flow_widgets.dart';

/// Framing choices on the Framing sheet; the board draws "Unframed".
const kFramingOptions = ['Unframed', 'Framed', 'Ready to hang'];

/// "Tell us about it" (`PostDetailsForSale`, `PostDetailsProgress`, `PostNFSDetails`): step 2
/// of 3 of posting a piece.
///
/// Title and Description (underline 17), Dimensions W × H × D in Mono 18 with the unit, and
/// for a sale Weight (Mono 18, lb) and the Framing row; then Location (with the privacy
/// line), Medium, Style, Materials and tools, Series, and Additional details (Year created,
/// Edition, Signed, Handling notes, and the existing provenance and AI disclosure).
///
/// Required, each with a red dot while empty: title, width and height, location, medium;
/// for a sale also depth, weight and framing. Continue stays off until none are left and
/// the line under it counts them.
class PieceDetailsStep extends StatefulWidget {
  const PieceDetailsStep({
    super.key,
    required this.forSale,
    required this.titleController,
    required this.descriptionController,
    required this.location,
    required this.medium,
    required this.style,
    required this.materialsCount,
    required this.series,
    required this.onLocation,
    required this.onMedium,
    required this.onStyle,
    required this.onMaterials,
    required this.onSeries,
    this.relatedScenesCount = 0,
    this.onRelatedScenes,
    required this.onBack,
    required this.onContinue,
  });

  final bool forSale;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String? location;
  final String? medium;
  final String? style;
  final int materialsCount;
  final String? series;
  final VoidCallback onLocation;
  final VoidCallback onMedium;
  final VoidCallback onStyle;
  final VoidCallback onMaterials;
  final VoidCallback onSeries;

  /// Related Scenes (`PostRelatedScenes`): how many are linked, and the picker.
  final int relatedScenesCount;
  final VoidCallback? onRelatedScenes;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  PieceDetailsStepState createState() => PieceDetailsStepState();
}

class PieceDetailsStepState extends State<PieceDetailsStep> {
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _depth = TextEditingController();
  final _weight = TextEditingController();
  final _year = TextEditingController();
  final _edition = TextEditingController(text: '1 of 1');
  final _handling = TextEditingController();
  final _provenance = TextEditingController();

  String _unit = 'in';
  String _weightUnit = 'lb';
  String? _framing = kFramingOptions.first;
  bool? _signed;
  bool _aiTools = false;
  bool _additionalOpen = false;

  /// Disclosed on the piece when AI tools were used (kept from the old form).
  bool get aiDisclosed => _aiTools;

  List<TextEditingController> get _all => [
    _width,
    _height,
    _depth,
    _weight,
    _year,
    _edition,
    _handling,
    _provenance,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in [..._all, widget.titleController]) {
      c.addListener(_rebuild);
    }
  }

  @override
  void didUpdateWidget(PieceDetailsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.titleController != widget.titleController) {
      oldWidget.titleController.removeListener(_rebuild);
      widget.titleController.addListener(_rebuild);
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.titleController.removeListener(_rebuild);
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _number(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v != null && v > 0 ? v : null;
  }

  bool get _hasTitle => widget.titleController.text.trim().isNotEmpty;
  bool get _hasSize => _number(_width) != null && _number(_height) != null;
  bool get _depthMissing => widget.forSale && _number(_depth) == null;
  bool get _weightMissing => widget.forSale && _number(_weight) == null;
  bool get _framingMissing => widget.forSale && (_framing == null || _framing!.isEmpty);
  bool get _locationMissing => widget.location == null || widget.location!.isEmpty;
  bool get _mediumMissing => widget.medium == null || widget.medium!.isEmpty;

  /// Required fields still empty (the dimensions count once for width/height and once
  /// for depth).
  int get missingCount => [
    !_hasTitle,
    !_hasSize,
    _depthMissing,
    _weightMissing,
    _framingMissing,
    _locationMissing,
    _mediumMissing,
  ].where((m) => m).length;

  ListingDetails buildListingDetails({double? priceUsd, String? location}) {
    final edition = _edition.text.trim();
    return ListingDetails(
      priceUsd: priceUsd,
      width: _number(_width),
      height: _number(_height),
      depth: _number(_depth),
      dimensionUnit: _unit,
      weight: widget.forSale ? _number(_weight) : null,
      weightUnit: _weightUnit,
      framingMounting: widget.forSale ? _framing : null,
      location: location,
      provenance: _provenance.text.trim(),
      yearCreated: int.tryParse(_year.text.trim()),
      edition: edition.isEmpty ? null : edition,
      signed: _signed,
      handlingNotes: _handling.text.trim(),
    );
  }

  Future<void> _pickFraming() async {
    final picked = await showFramingSheet(context, selected: _framing);
    if (picked != null && mounted) setState(() => _framing = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final missing = missingCount;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostStepHeader(onBack: widget.onBack, current: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PostHeading(
                      title: 'Tell us about it',
                      // Not for sale has no line once nothing is missing (`PostNFSDetails`).
                      subtitle: missing > 0
                          ? 'Fields with a red dot still need something.'
                          : (widget.forSale ? 'What collectors see on the piece page.' : null),
                    ),
                    const SizedBox(height: 22),
                    StudioUnderlineField(
                      label: 'Title',
                      controller: widget.titleController,
                      hint: 'Give it a title',
                      required: true,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 22),
                    StudioUnderlineField(
                      label: 'Description',
                      controller: widget.descriptionController,
                      hint: 'Tell people what inspired it, how long it took…',
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 22),
                    _dimensions(c),
                    if (widget.forSale) ...[
                      const SizedBox(height: 22),
                      StudioTooltip(
                        message:
                            'Used only to get shipping quotes. It never shows on your piece.',
                        builder: (context, toggle) => StudioUnderlineField(
                          label: 'Weight',
                          controller: _weight,
                          hint: 'Add weight',
                          mono: true,
                          sansHint: true,
                          valueSize: 18,
                          required: true,
                          labelTrailing: StudioInfoButton(
                            onTap: toggle,
                            semanticLabel: 'What is weight?',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [_decimal],
                          trailing: _UnitToggle(
                            value: _weightUnit,
                            options: const ['lb', 'kg'],
                            mono: true,
                            onChanged: (u) => setState(() => _weightUnit = u),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (widget.forSale)
                      PostChevronRow(
                        label: 'Framing',
                        value: _framing,
                        required: _framingMissing,
                        info: 'Tell collectors how it arrives: unframed, framed, or '
                            'ready to hang.',
                        onTap: _pickFraming,
                      ),
                    PostChevronRow(
                      label: 'Location',
                      value: widget.location,
                      required: _locationMissing,
                      info: 'The city the piece is in. Collectors see the city only.',
                      onTap: widget.onLocation,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                      child: Text(
                        'Only your city is shown. Your pickup address stays private in your '
                        'payout settings.',
                        style: StudioType.caption12(height: 1.45, color: c.textSecondary),
                      ),
                    ),
                    PostChevronRow(
                      label: 'Medium',
                      value: widget.medium,
                      required: _mediumMissing,
                      onTap: widget.onMedium,
                    ),
                    PostChevronRow(
                      label: 'Style',
                      value: widget.style,
                      info: 'Up to three styles. They help people find it in Explore.',
                      onTap: widget.onStyle,
                    ),
                    PostChevronRow(
                      label: 'Materials and tools',
                      value: widget.materialsCount > 0 ? '${widget.materialsCount}' : null,
                      mono: true,
                      info: 'What you made it with, brushes included. Shown on the piece '
                          'under Made with.',
                      onTap: widget.onMaterials,
                    ),
                    PostChevronRow(
                      label: 'Series',
                      value: widget.series,
                      onTap: widget.onSeries,
                    ),
                    if (widget.onRelatedScenes != null)
                      PostChevronRow(
                        label: 'Related Scenes',
                        value: widget.relatedScenesCount > 0
                            ? '${widget.relatedScenesCount}'
                            : null,
                        mono: true,
                        info: 'Scenes that show how this piece came together. They appear on '
                            'the piece under The story behind this piece.',
                        onTap: widget.onRelatedScenes!,
                      ),
                    if (!_additionalOpen)
                      PostChevronRow(
                        label: 'Additional details',
                        placeholder: 'Optional',
                        onTap: () => setState(() => _additionalOpen = true),
                      )
                    else
                      _additional(c),
                  ],
                ),
              ),
            ),
            PostBottomAction(
              button: StudioButton(
                label: 'Continue',
                height: 54,
                onPressed: missing == 0 ? widget.onContinue : null,
              ),
              caption: missing == 0
                  ? null
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$missing',
                            style: StudioType.mono(12, color: c.textSecondary),
                          ),
                          TextSpan(
                            text: missing == 1
                                ? ' required field left'
                                : ' required fields left',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: StudioType.caption12(color: c.textSecondary),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensions(StudioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Dimensions', style: StudioType.label13(color: c.textSecondary)),
            if (!_hasSize || _depthMissing) const StudioRequiredDot(),
            if (!widget.forSale)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'depth optional',
                  style: StudioType.mono(10, color: c.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _DimensionCell(controller: _width, axis: 'W')),
            _times(c),
            Expanded(child: _DimensionCell(controller: _height, axis: 'H')),
            _times(c),
            Expanded(child: _DimensionCell(controller: _depth, axis: 'D')),
            const SizedBox(width: 10),
            _UnitToggle(
              value: _unit,
              options: const ['in', 'cm'],
              underline: true,
              onChanged: (u) => setState(() => _unit = u),
            ),
          ],
        ),
        if (_depthMissing && _hasSize) ...[
          const SizedBox(height: 6),
          Text(
            'Depth is needed to sell.',
            style: StudioType.caption12(color: c.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _times(StudioColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    child: Text('×', style: StudioType.mono(18, color: c.textPlaceholder)),
  );

  Widget _additional(StudioColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Additional details',
                  style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
              Text('Optional', style: StudioType.caption12(color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StudioUnderlineField(
                  label: 'Year created',
                  controller: _year,
                  hint: 'YYYY',
                  mono: true,
                  valueSize: 18,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StudioUnderlineField(
                  label: 'Edition',
                  controller: _edition,
                  hint: '1 of 10',
                  mono: true,
                  valueSize: 18,
                  maxLength: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Signed', style: StudioType.label13(color: c.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              StudioChip(
                label: 'Yes',
                selected: _signed == true,
                horizontalPadding: 16,
                onTap: () => setState(() => _signed = _signed == true ? null : true),
              ),
              const SizedBox(width: 8),
              StudioChip(
                label: 'No',
                selected: _signed == false,
                horizontalPadding: 16,
                onTap: () => setState(() => _signed = _signed == false ? null : false),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StudioUnderlineField(
            label: 'Handling notes',
            controller: _handling,
            hint: 'Framed under glass, handle by the edges…',
            maxLines: 4,
            minLines: 1,
          ),
          const SizedBox(height: 20),
          StudioUnderlineField(
            label: 'Provenance',
            controller: _provenance,
            hint: 'Ownership history',
            maxLines: 4,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Made with AI tools',
                  style: StudioType.sans(16, color: c.textPrimary),
                ),
              ),
              StudioSwitch(value: _aiTools, onChanged: (v) => setState(() => _aiTools = v)),
            ],
          ),
        ],
      ),
    );
  }
}

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

/// One dimension: the Mono 18 number with its 11 Tertiary axis letter right after it, over
/// a 1 px underline; the letter alone is the placeholder.
class _DimensionCell extends StatefulWidget {
  const _DimensionCell({required this.controller, required this.axis});

  final TextEditingController controller;
  final String axis;

  @override
  State<_DimensionCell> createState() => _DimensionCellState();
}

class _DimensionCellState extends State<_DimensionCell> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.mono(18, color: c.textPrimary);
    final empty = widget.controller.text.isEmpty;
    return GestureDetector(
      onTap: _focus.requestFocus,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(bottom: _focus.hasFocus ? 7.5 : 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _focus.hasFocus ? c.textPrimary : c.lineStrong,
              width: _focus.hasFocus ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: IntrinsicWidth(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  style: style,
                  cursorColor: c.textPrimary,
                  cursorWidth: 1.5,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_decimal],
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: widget.axis,
                    hintStyle: style.copyWith(color: c.textPlaceholder),
                    semanticCounterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            if (!empty)
              Text(' ${widget.axis}', style: StudioType.mono(11, color: c.textTertiary)),
          ],
        ),
      ),
    );
  }
}

/// A unit that flips on tap ("in" ↔ "cm", "lb" ↔ "kg"); underlined as its own cell on the
/// dimensions row.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    this.underline = false,
    this.mono = false,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool underline;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final next = options[(options.indexOf(value) + 1) % options.length];
    final text = Text(
      value,
      style: mono || underline
          ? StudioType.mono(14, color: c.textPrimary)
          : StudioType.body14(color: c.textPrimary),
    );
    return Semantics(
      button: true,
      label: 'Unit $value, switch to $next',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(next),
        behavior: HitTestBehavior.opaque,
        child: underline
            ? Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.lineStrong)),
                ),
                child: text,
              )
            : text,
      ),
    );
  }
}

/// The Framing sheet: "Framing" 22/500 and [kFramingOptions] as option rows; tapping one
/// returns it.
Future<String?> showFramingSheet(BuildContext context, {String? selected}) {
  return showStudioSheet<String>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.studio;
      return StudioSheet(
        horizontalPadding: 24,
        gap: 0,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Framing', style: StudioType.title22(color: c.textPrimary)),
          ),
          for (final option in kFramingOptions)
            StudioSelectRow(
              title: option,
              selected: selected == option,
              divider: option != kFramingOptions.last,
              titleSize: 17,
              titleLetterSpacing: 0,
              verticalPadding: 16,
              ruleInset: 14,
              onTap: () => Navigator.pop(sheetContext, option),
            ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../../data/post_media_assets.dart';
import '../../models/listing_details.dart';
import '../../theme/home_feed_tokens.dart';
import '../choose_location_sheet.dart';
import 'create_flow_widgets.dart';
import '../../theme/app_fonts.dart';

/// Inline listing + general artwork-detail fields for piece creation.
///
/// Price/dimensions/shipping-region only apply when [showSaleFields] is true
/// ("List for sale" toggled on); year/framing/provenance/handling notes are
/// general piece metadata and always render regardless of sale status.
class ListingDetailsForm extends StatefulWidget {
  const ListingDetailsForm({
    super.key,
    this.showSaleFields = true,
    this.includePrice = true,
  });

  final bool showSaleFields;
  /// Price lives on the Availability tab for piece posting.
  final bool includePrice;

  @override
  ListingDetailsFormState createState() => ListingDetailsFormState();
}

class ListingDetailsFormState extends State<ListingDetailsForm> {
  static const _textSecondary = Color(0xFF8C8880);
  static const _neutral700 = Color(0xFF4A4843);

  final _priceController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _depthController = TextEditingController();
  final _nonStandardController = TextEditingController();
  final _framingController = TextEditingController();
  final _provenanceController = TextEditingController();
  final _yearController = TextEditingController();
  final _handlingController = TextEditingController();
  final _weightController = TextEditingController();
  final _packageLengthController = TextEditingController();
  final _packageWidthController = TextEditingController();
  final _packageHeightController = TextEditingController();
  final _declaredValueController = TextEditingController();

  String _dimensionUnit = 'in';
  String _packageUnit = 'in';
  bool _nonStandardFormat = false;
  String? _location;

  bool get isPriceValid {
    final price = double.tryParse(_priceController.text.trim());
    return price != null && price > 0;
  }

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_notifyChanged);
  }

  void _notifyChanged() => setState(() {});

  @override
  void dispose() {
    _priceController
      ..removeListener(_notifyChanged)
      ..dispose();
    _widthController.dispose();
    _heightController.dispose();
    _depthController.dispose();
    _nonStandardController.dispose();
    _framingController.dispose();
    _provenanceController.dispose();
    _yearController.dispose();
    _handlingController.dispose();
    _weightController.dispose();
    _packageLengthController.dispose();
    _packageWidthController.dispose();
    _packageHeightController.dispose();
    _declaredValueController.dispose();
    super.dispose();
  }

  void clear() {
    _priceController.clear();
    _widthController.clear();
    _heightController.clear();
    _depthController.clear();
    _nonStandardController.clear();
    _framingController.clear();
    _provenanceController.clear();
    _yearController.clear();
    _handlingController.clear();
    _weightController.clear();
    _packageLengthController.clear();
    _packageWidthController.clear();
    _packageHeightController.clear();
    _declaredValueController.clear();
    setState(() {
      _dimensionUnit = 'in';
      _packageUnit = 'in';
      _nonStandardFormat = false;
      _location = null;
    });
  }

  ListingDetails buildListingDetails() {
    return ListingDetails(
      priceUsd: double.tryParse(_priceController.text.trim()),
      width: double.tryParse(_widthController.text.trim()),
      height: double.tryParse(_heightController.text.trim()),
      depth: double.tryParse(_depthController.text.trim()),
      dimensionUnit: _dimensionUnit,
      nonStandardFormat: _nonStandardFormat,
      nonStandardDescription: _nonStandardController.text,
      framingMounting: _framingController.text,
      location: _location,
      provenance: _provenanceController.text,
      yearCreated: int.tryParse(_yearController.text.trim()),
      handlingNotes: _handlingController.text,
      weightKg: double.tryParse(_weightController.text.trim()),
      packageLength: double.tryParse(_packageLengthController.text.trim()),
      packageWidth: double.tryParse(_packageWidthController.text.trim()),
      packageHeight: double.tryParse(_packageHeightController.text.trim()),
      packageUnit: _packageUnit,
      declaredValueUsd: double.tryParse(_declaredValueController.text.trim()),
    );
  }

  /// The backend rejects a for-sale listing without these, so the create flow
  /// checks them before publish rather than surfacing a server error.
  bool get areShippingFieldsValid {
    final values = [
      double.tryParse(_weightController.text.trim()),
      double.tryParse(_packageLengthController.text.trim()),
      double.tryParse(_packageWidthController.text.trim()),
      double.tryParse(_packageHeightController.text.trim()),
      double.tryParse(_declaredValueController.text.trim()),
    ];
    return values.every((v) => v != null && v > 0);
  }

  void _openLocationPicker() {
    ChooseLocationSheet.show(
      context,
      onLocationSelected: (loc) {
        setState(() => _location = loc.name);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSaleFields) ...[
          if (widget.includePrice) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: createFlowHorizontalInset,
              ),
              child: CreateFlowDivider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CreateFlowTextField(
                    controller: _priceController,
                    hint: 'Price (required)',
                    prefixText: '\$ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  if (!isPriceValid &&
                      _priceController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Enter a valid price greater than 0',
                        style: AppFonts.inter(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ] else if (_priceController.text.trim().isEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Required to list for sale',
                        style: AppFonts.inter(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: createFlowHorizontalInset),
            child: CreateFlowDivider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: CreateFlowTextField(
                    controller: _widthController,
                    hint: 'W',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: AppFonts.inter(fontSize: 14, color: _textSecondary),
                  ),
                ),
                Expanded(
                  child: CreateFlowTextField(
                    controller: _heightController,
                    hint: 'H',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: AppFonts.inter(fontSize: 14, color: _textSecondary),
                  ),
                ),
                Expanded(
                  child: CreateFlowTextField(
                    controller: _depthController,
                    hint: 'D',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _neutral700,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UnitChip(
                    label: 'in',
                    selected: _dimensionUnit == 'in',
                    onTap: () => setState(() => _dimensionUnit = 'in'),
                  ),
                  _UnitChip(
                    label: 'cm',
                    selected: _dimensionUnit == 'cm',
                    onTap: () => setState(() => _dimensionUnit = 'cm'),
                  ),
                ],
              ),
            ),
          ),
          CreateFlowToggleRow(
            label: 'Non-standard format',
            value: _nonStandardFormat,
            onChanged: (v) => setState(() => _nonStandardFormat = v),
          ),
          if (_nonStandardFormat)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: CreateFlowTextField(
                controller: _nonStandardController,
                hint: 'Describe non-standard dimensions',
                style: CreateFlowTextFieldStyle.body,
                maxLines: 2,
                minLines: 2,
              ),
            ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: createFlowHorizontalInset),
            child: CreateFlowDivider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipping details',
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Measure the packed crate or box, not the artwork — couriers '
                  'quote on what actually ships.',
                  style: AppFonts.inter(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: CreateFlowTextField(
              controller: _weightController,
              hint: 'Packed weight (kg)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: CreateFlowTextField(
                    controller: _packageLengthController,
                    hint: 'L',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: AppFonts.inter(fontSize: 14, color: _textSecondary),
                  ),
                ),
                Expanded(
                  child: CreateFlowTextField(
                    controller: _packageWidthController,
                    hint: 'W',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: AppFonts.inter(fontSize: 14, color: _textSecondary),
                  ),
                ),
                Expanded(
                  child: CreateFlowTextField(
                    controller: _packageHeightController,
                    hint: 'H',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _neutral700,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UnitChip(
                    label: 'in',
                    selected: _packageUnit == 'in',
                    onTap: () => setState(() => _packageUnit = 'in'),
                  ),
                  _UnitChip(
                    label: 'cm',
                    selected: _packageUnit == 'cm',
                    onTap: () => setState(() => _packageUnit = 'cm'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: CreateFlowTextField(
              controller: _declaredValueController,
              hint: 'Declared value',
              prefixText: '\$ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 16, 0),
            child: Text(
              'Used for customs and insurance if the work is damaged in transit.',
              style: AppFonts.inter(fontSize: 11, color: _textSecondary),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: createFlowHorizontalInset),
          child: CreateFlowDivider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CreateFlowTextField(
            controller: _framingController,
            hint: 'Framing/mounting (optional)',
          ),
        ),
        if (widget.showSaleFields) ...[
          CreateFlowMetadataRow(
            iconAsset: PostMediaAssets.createLocationIcon,
            iconWidth: 12,
            iconHeight: 16,
            label: 'Shipping region',
            trailing: _location,
            onTap: _openLocationPicker,
          ),
          if (_location != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CreateFlowLocationChip(
                  label: _location!,
                  onRemove: () => setState(() => _location = null),
                ),
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CreateFlowTextField(
            controller: _provenanceController,
            hint: 'Provenance — ownership history',
            style: CreateFlowTextFieldStyle.body,
            maxLines: 3,
            minLines: 2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CreateFlowTextField(
            controller: _yearController,
            hint: 'Year created',
            keyboardType: TextInputType.number,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CreateFlowTextField(
            controller: _handlingController,
            hint: 'Handling notes — shipping and care instructions',
            style: CreateFlowTextFieldStyle.body,
            maxLines: 3,
            minLines: 2,
          ),
        ),
      ],
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HomeFeedTokens.textInverse : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? HomeFeedTokens.textPrimary : _textSecondary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/post_media_assets.dart';
import '../../models/listing_details.dart';
import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
import '../../theme/app_fonts.dart';

/// Figma 2720:6711 — piece posting Details tab.
class PieceDetailsForm extends StatefulWidget {
  const PieceDetailsForm({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.locationTrailing,
    required this.mediumTrailing,
    required this.styleTrailing,
    required this.materialsTrailing,
    required this.seriesTrailing,
    required this.onLocation,
    required this.onMedium,
    required this.onStyle,
    required this.onMaterials,
    required this.onSeries,
    required this.onRelatedScenes,
    this.relatedScenesTrailing,
    this.onChanged,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String? locationTrailing;
  final String? mediumTrailing;
  final String? styleTrailing;
  final String? materialsTrailing;
  final String? seriesTrailing;
  final VoidCallback onLocation;
  final VoidCallback onMedium;
  final VoidCallback onStyle;
  final VoidCallback onMaterials;
  final VoidCallback onSeries;
  final VoidCallback onRelatedScenes;
  final String? relatedScenesTrailing;
  final VoidCallback? onChanged;

  @override
  PieceDetailsFormState createState() => PieceDetailsFormState();
}

class PieceDetailsFormState extends State<PieceDetailsForm> {
  static const _rule = Color(0xFFC8C5BC);

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _yearController = TextEditingController();
  final _framingController = TextEditingController();
  final _handlingController = TextEditingController();

  String _dimensionUnit = 'in';
  bool _additionalOpen = false;
  final _additionalSectionKey = GlobalKey();

  int get _additionalFilledCount {
    var n = 0;
    if (_yearController.text.trim().isNotEmpty) n++;
    if (_framingController.text.trim().isNotEmpty) n++;
    if (_handlingController.text.trim().isNotEmpty) n++;
    return n;
  }

  String? get _additionalTrailing {
    final n = _additionalFilledCount;
    if (n == 0) return null;
    return '$n of 3 added';
  }

  bool get hasDimensions {
    final w = double.tryParse(_widthController.text.trim());
    final h = double.tryParse(_heightController.text.trim());
    return w != null && w > 0 && h != null && h > 0;
  }

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_emitChanged);
    _heightController.addListener(_emitChanged);
    _yearController.addListener(_onAdditionalChanged);
    _framingController.addListener(_onAdditionalChanged);
    _handlingController.addListener(_onAdditionalChanged);
  }

  void _emitChanged() => widget.onChanged?.call();

  void _onAdditionalChanged() {
    setState(() {});
    _emitChanged();
  }

  void _toggleAdditional() {
    final opening = !_additionalOpen;
    setState(() => _additionalOpen = opening);
    if (!opening) return;
    // Wait for the newly-revealed fields to actually be laid out before
    // asking to scroll to them — otherwise ensureVisible measures the
    // pre-expansion layout and undershoots.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _additionalSectionKey.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  @override
  void dispose() {
    _widthController
      ..removeListener(_emitChanged)
      ..dispose();
    _heightController
      ..removeListener(_emitChanged)
      ..dispose();
    _yearController
      ..removeListener(_onAdditionalChanged)
      ..dispose();
    _framingController
      ..removeListener(_onAdditionalChanged)
      ..dispose();
    _handlingController
      ..removeListener(_onAdditionalChanged)
      ..dispose();
    super.dispose();
  }

  ListingDetails buildListingDetails() {
    return ListingDetails(
      width: double.tryParse(_widthController.text.trim()),
      height: double.tryParse(_heightController.text.trim()),
      dimensionUnit: _dimensionUnit,
      framingMounting: _framingController.text,
      yearCreated: int.tryParse(_yearController.text.trim()),
      handlingNotes: _handlingController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          child: _LabeledField(
            label: 'Title',
            labelGap: 8,
            child: _OutlineField(
              controller: widget.titleController,
              hint: 'Give this piece a name',
              fontSize: 13,
            ),
          ),
        ),
        _section(
          child: _LabeledField(
            label: 'Description',
            labelGap: 16,
            child: _OutlineField(
              controller: widget.descriptionController,
              hint:
                  'Tell us what was happening in the studio. The more you share, the further it travels.',
              fontSize: 12,
              maxLines: 4,
              minLines: 3,
              height: null,
            ),
          ),
        ),
        _section(
          child: _LabeledField(
            label: 'Dimension',
            labelGap: 16,
            child: _DimensionRow(
              widthController: _widthController,
              heightController: _heightController,
              unit: _dimensionUnit,
              onUnitChanged: (unit) => setState(() => _dimensionUnit = unit),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _NavRow(
                label: 'Location',
                trailing: widget.locationTrailing,
                onTap: widget.onLocation,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Medium',
                trailing: widget.mediumTrailing,
                onTap: widget.onMedium,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Style',
                trailing: widget.styleTrailing,
                onTap: widget.onStyle,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Materials',
                trailing: widget.materialsTrailing,
                onTap: widget.onMaterials,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Series',
                trailing: widget.seriesTrailing,
                trailingSize: 13,
                onTap: widget.onSeries,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Related Scenes',
                trailing: widget.relatedScenesTrailing,
                onTap: widget.onRelatedScenes,
              ),
              const SizedBox(height: 24),
              _NavRow(
                label: 'Additional details',
                trailing: _additionalTrailing,
                trailingSize: 13,
                expanded: _additionalOpen,
                onTap: _toggleAdditional,
              ),
            ],
          ),
        ),
        if (_additionalOpen)
          Padding(
            key: _additionalSectionKey,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                _LabeledField(
                  label: 'Year created',
                  labelGap: 8,
                  child: _OutlineField(
                    controller: _yearController,
                    hint: '2026',
                    fontSize: 13,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 24),
                _LabeledField(
                  label: 'Framing/mounting',
                  labelGap: 8,
                  child: _OutlineField(
                    controller: _framingController,
                    hint: 'Framed, floating, or fending for itself?',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                _LabeledField(
                  label: 'Handling notes',
                  labelGap: 8,
                  child: _OutlineField(
                    controller: _handlingController,
                    hint: 'What would you tell the mover if you could?',
                    fontSize: 13,
                  ),
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
        border: Border(bottom: BorderSide(color: _rule, width: 0.5)),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.labelGap,
    required this.child,
  });

  final String label;
  final double labelGap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kProfileGeist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textSecondary,
          ),
        ),
        SizedBox(height: labelGap),
        child,
      ],
    );
  }
}

class _OutlineField extends StatelessWidget {
  const _OutlineField({
    required this.controller,
    required this.hint,
    required this.fontSize,
    this.maxLines = 1,
    this.minLines,
    this.height = 40,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final double fontSize;
  final int maxLines;
  final int? minLines;
  final double? height;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      cursorColor: HomeFeedTokens.textPrimary,
      style: AppFonts.geist(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: HomeFeedTokens.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppFonts.geist(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: HomeFeedTokens.textSecondary,
        ),
        border: InputBorder.none,
        contentPadding: maxLines > 1
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );

    return Container(
      height: height,
      width: double.infinity,
      alignment: maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: field,
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.widthController,
    required this.heightController,
    required this.unit,
    required this.onUnitChanged,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final String unit;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DimBox(controller: widthController, suffix: 'W')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SvgPicture.asset(
            PostMediaAssets.createDimensionClose,
            width: 8,
            height: 8,
          ),
        ),
        Expanded(child: _DimBox(controller: heightController, suffix: 'H')),
        const SizedBox(width: 10),
        _UnitButton(unit: unit, onChanged: onUnitChanged),
      ],
    );
  }
}

class _DimBox extends StatelessWidget {
  const _DimBox({required this.controller, required this.suffix});

  final TextEditingController controller;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              cursorColor: HomeFeedTokens.textPrimary,
              style: AppFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            suffix,
            style: kProfileGeist(
              fontSize: 10,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({required this.unit, required this.onChanged});

  final String unit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 40,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: HomeFeedTokens.background,
        tooltip: 'Unit',
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final option in const ['in', 'cm'])
            PopupMenuItem(
              value: option,
              height: 40,
              child: Text(option, style: kProfileGeist(fontSize: 13)),
            ),
        ],
        child: Container(
          width: 44,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HomeFeedTokens.textPrimary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                unit,
                style: kProfileGeist(
                  fontSize: 13,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              SvgPicture.asset(
                PostMediaAssets.createUnitChevron,
                width: 8,
                height: 4,
                colorFilter: const ColorFilter.mode(
                  HomeFeedTokens.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.trailing,
    this.trailingSize = 12,
    this.expanded,
  });

  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final double trailingSize;
  final bool? expanded;

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
              style: kProfileGeist(
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
                    fontSize: trailingSize,
                    fontWeight: FontWeight.w400,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 8),
            Transform.rotate(
              angle: expanded == true ? -1.5707963267948966 : 0,
              child: SvgPicture.asset(
                PostMediaAssets.createDetailsChevronSm,
                width: 5,
                height: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

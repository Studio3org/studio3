import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/piece_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/payout_setup.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/studio_loading.dart';

class EditPiecePage extends StatefulWidget {
  const EditPiecePage({super.key, required this.piece});

  final PieceSummary piece;

  @override
  State<EditPiecePage> createState() => _EditPiecePageState();
}

class _EditPiecePageState extends State<EditPiecePage> {
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late final TextEditingController _medium;
  late final TextEditingController _dimensions;
  late final TextEditingController _priceUsd;
  late final TextEditingController _yearCreated;
  late final TextEditingController _framingMounting;
  late final TextEditingController _provenance;
  late final TextEditingController _handlingNotes;
  late final TextEditingController _materials;
  late final TextEditingController _styleTags;
  late final TextEditingController _altText;
  late final TextEditingController _weightKg;
  late final TextEditingController _packageLength;
  late final TextEditingController _packageWidth;
  late final TextEditingController _packageHeight;
  late final TextEditingController _declaredValueUsd;

  bool _isForSale = false;
  bool _aiDisclosed = false;
  // Only meaningful when the piece is an ended auction (see _canSwitchToFixedPrice).
  // Auction -> fixed is one-directional here on purpose: switching the other way is
  // already a dedicated flow — Manage auction -> Run it again — which asks for a
  // duration and a starting bid properly instead of overloading this price field.
  bool _sellAsFixedPrice = false;
  String? _shippingRegion;
  String _packageUnit = 'in';
  static const _cmPerInch = 2.54;
  late String _status;
  bool _saving = false;
  String? _error;

  static const _editableStatuses = ['draft', 'live', 'delisted'];

  @override
  void initState() {
    super.initState();
    final p = widget.piece;
    _title = TextEditingController(text: p.title);
    _caption = TextEditingController(text: p.caption);
    _medium = TextEditingController(text: p.medium);
    _dimensions = TextEditingController(text: p.dimensions);
    _priceUsd = TextEditingController(
      text: p.priceCents != null ? (p.priceCents! / 100).toStringAsFixed(2) : '',
    );
    _yearCreated = TextEditingController(text: p.yearCreated?.toString() ?? '');
    _framingMounting = TextEditingController(text: p.framingMounting);
    _provenance = TextEditingController(text: p.provenance);
    _handlingNotes = TextEditingController(text: p.handlingNotes);
    _materials = TextEditingController(text: p.materials.join(', '));
    _styleTags = TextEditingController(text: p.styleTags.join(', '));
    _altText = TextEditingController(text: p.altText);
    _weightKg = TextEditingController(text: _fmtNum(p.weightKg));
    _packageLength = TextEditingController(text: _fmtNum(_fromCm(p.packageLengthCm)));
    _packageWidth = TextEditingController(text: _fmtNum(_fromCm(p.packageWidthCm)));
    _packageHeight = TextEditingController(text: _fmtNum(_fromCm(p.packageHeightCm)));
    _declaredValueUsd = TextEditingController(
      text: p.declaredValueCents != null
          ? (p.declaredValueCents! / 100).toStringAsFixed(2)
          : '',
    );
    _isForSale = p.isForSale;
    _aiDisclosed = p.aiDisclosed;
    _shippingRegion = p.shippingRegion;
    _status = _editableStatuses.contains(p.status) ? p.status! : (p.status ?? 'live');
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _medium.dispose();
    _dimensions.dispose();
    _priceUsd.dispose();
    _yearCreated.dispose();
    _framingMounting.dispose();
    _provenance.dispose();
    _handlingNotes.dispose();
    _materials.dispose();
    _styleTags.dispose();
    _altText.dispose();
    _weightKg.dispose();
    _packageLength.dispose();
    _packageWidth.dispose();
    _packageHeight.dispose();
    _declaredValueUsd.dispose();
    super.dispose();
  }

  String _fmtNum(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  double? _fromCm(double? cm) {
    if (cm == null) return null;
    return _packageUnit == 'cm' ? cm : cm / _cmPerInch;
  }

  double? _toCm(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null) return null;
    return _packageUnit == 'cm' ? value : value * _cmPerInch;
  }

  void _setPackageUnit(String unit) {
    if (unit == _packageUnit) return;
    double? convert(String raw) {
      final value = double.tryParse(raw.trim());
      if (value == null) return null;
      return unit == 'cm' ? value * _cmPerInch : value / _cmPerInch;
    }

    void rewrite(TextEditingController controller) {
      final converted = convert(controller.text);
      controller.text = _fmtNum(converted);
    }

    rewrite(_packageLength);
    rewrite(_packageWidth);
    rewrite(_packageHeight);
    setState(() => _packageUnit = unit);
  }

  Future<void> _onListForSaleChanged(bool value) async {
    if (!value) {
      setState(() => _isForSale = false);
      return;
    }
    final allowed = await ensureCanListForSale(context);
    if (!mounted) return;
    if (allowed) setState(() => _isForSale = true);
  }

  /// An auction that ended without a sale is delisted with no buyer and no bids
  /// outstanding — the one shape assert_terms_editable (server side) allows switching.
  /// A *live* auction is deliberately excluded even with zero bids: the guard's own
  /// message says to cancel it first, and doing that here would silently skip the
  /// refund-and-notify step every bidder is owed if one exists by the time this saves.
  bool get _canSwitchToFixedPrice =>
      widget.piece.isAuction && widget.piece.status != 'live';

  Future<void> _onSellAsFixedPriceChanged(bool value) async {
    if (!value) {
      setState(() => _sellAsFixedPrice = false);
      return;
    }
    // Same payout gate as any other for-sale toggle — this makes the piece purchasable.
    final allowed = await ensureCanListForSale(context);
    if (!mounted || !allowed) return;
    setState(() {
      _sellAsFixedPrice = true;
      _isForSale = true;
      // The point of switching is to put it back on sale, not just relabel it — an
      // ended auction is delisted, and leaving it there would save a listingType nobody
      // can buy.
      if (_status == 'delisted' || _status == 'draft') _status = 'live';
    });
  }

  bool get _statusIsEditable => _editableStatuses.contains(widget.piece.status ?? 'live');

  void _openShippingRegionPicker() {
    ChooseLocationSheet.show(
      context,
      onLocationSelected: (loc) {
        setState(() => _shippingRegion = loc.name);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final materials = _materials.text
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    final styleTags = _styleTags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      if (_medium.text.trim().isNotEmpty) 'medium': _medium.text.trim(),
      if (_dimensions.text.trim().isNotEmpty) 'dimensions': _dimensions.text.trim(),
      if (_yearCreated.text.trim().isNotEmpty)
        'yearCreated': int.tryParse(_yearCreated.text.trim()),
      if (_framingMounting.text.trim().isNotEmpty)
        'framingMounting': _framingMounting.text.trim(),
      if (_provenance.text.trim().isNotEmpty) 'provenance': _provenance.text.trim(),
      if (_handlingNotes.text.trim().isNotEmpty)
        'handlingNotes': _handlingNotes.text.trim(),
      'materials': materials,
      'styleTags': styleTags,
      'aiDisclosed': _aiDisclosed,
      if (_altText.text.trim().isNotEmpty) 'altText': _altText.text.trim(),
      'isForSale': _isForSale,
      if (_sellAsFixedPrice) 'listingType': 'fixed',
      if (_isForSale) ...{
        if (_priceUsd.text.trim().isNotEmpty)
          'priceCents': ((double.tryParse(_priceUsd.text.trim()) ?? 0) * 100).round(),
        if (_shippingRegion != null) 'shippingRegion': _shippingRegion,
        if (_weightKg.text.trim().isNotEmpty)
          'weightKg': double.tryParse(_weightKg.text.trim()),
        if (_packageLength.text.trim().isNotEmpty)
          'packageLengthCm': _toCm(_packageLength.text),
        if (_packageWidth.text.trim().isNotEmpty)
          'packageWidthCm': _toCm(_packageWidth.text),
        if (_packageHeight.text.trim().isNotEmpty)
          'packageHeightCm': _toCm(_packageHeight.text),
        if (_declaredValueUsd.text.trim().isNotEmpty)
          'declaredValueCents':
              ((double.tryParse(_declaredValueUsd.text.trim()) ?? 0) * 100)
                  .round(),
      },
      if (_statusIsEditable) 'status': _status,
    };
    try {
      await PieceService.instance.update(widget.piece.id, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && isPayoutSetupRequiredMessage(e.message)) {
        setState(() => _saving = false);
        await openPayoutSetup(context);
        return;
      }
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save changes';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _saving,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            'Edit piece',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Field(label: 'Title', controller: _title),
            const SizedBox(height: 16),
            _Field(label: 'Caption', controller: _caption, maxLines: 3),
            const SizedBox(height: 16),
            _Field(label: 'Medium', controller: _medium),
            const SizedBox(height: 16),
            _Field(label: 'Dimensions', controller: _dimensions),
            const SizedBox(height: 16),
            _Field(label: 'Year created', controller: _yearCreated),
            const SizedBox(height: 16),
            _Field(label: 'Framing / mounting', controller: _framingMounting),
            const SizedBox(height: 16),
            _Field(label: 'Provenance', controller: _provenance, maxLines: 3),
            const SizedBox(height: 16),
            _Field(label: 'Handling notes', controller: _handlingNotes, maxLines: 3),
            const SizedBox(height: 16),
            _Field(label: 'Materials (comma separated)', controller: _materials),
            const SizedBox(height: 16),
            _Field(label: 'Style tags (comma separated)', controller: _styleTags),
            const SizedBox(height: 16),
            _Field(label: 'Alt text', controller: _altText, maxLines: 2),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI tools used'),
              value: _aiDisclosed,
              onChanged: (v) => setState(() => _aiDisclosed = v),
            ),
            if (_canSwitchToFixedPrice) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sell at a fixed price instead'),
                subtitle: Text(
                  'This auction ended without a sale. Switch it to a fixed price and '
                  'it goes back on sale immediately — or close this and use "Manage '
                  'auction" on the piece to run the auction again instead.',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.4),
                ),
                value: _sellAsFixedPrice,
                onChanged: _onSellAsFixedPriceChanged,
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('List for sale'),
              value: _isForSale,
              onChanged: _onListForSaleChanged,
            ),
            if (_isForSale) ...[
              const SizedBox(height: 8),
              _Field(label: 'Price (USD)', controller: _priceUsd),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _openShippingRegionPicker,
                child: Text(_shippingRegion ?? 'Set shipping region'),
              ),
              const SizedBox(height: 16),
              Text(
                'Shipping details',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Measure the packed crate or box, not the artwork.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 12),
              _Field(label: 'Packed weight (kg)', controller: _weightKg),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Field(label: 'L', controller: _packageLength)),
                  const SizedBox(width: 8),
                  Expanded(child: _Field(label: 'W', controller: _packageWidth)),
                  const SizedBox(width: 8),
                  Expanded(child: _Field(label: 'H', controller: _packageHeight)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _UnitChip(
                    label: 'in',
                    selected: _packageUnit == 'in',
                    onTap: () => _setPackageUnit('in'),
                  ),
                  const SizedBox(width: 8),
                  _UnitChip(
                    label: 'cm',
                    selected: _packageUnit == 'cm',
                    onTap: () => _setPackageUnit('cm'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Field(label: 'Declared value (USD)', controller: _declaredValueUsd),
            ],
            const SizedBox(height: 16),
            if (_statusIsEditable) ...[
              Text(
                'Status',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _status,
                items: [
                  for (final s in _editableStatuses)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ] else
              Text(
                'Status: ${widget.piece.status} (managed automatically by checkout)',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? HomeFeedTokens.neutral800
              : HomeFeedTokens.textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? HomeFeedTokens.textInverse
                : HomeFeedTokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.maxLines = 1});

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

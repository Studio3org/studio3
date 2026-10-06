import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/piece_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
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

  bool _isForSale = false;
  bool _aiDisclosed = false;
  String? _shippingRegion;
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
    super.dispose();
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
      if (_isForSale) ...{
        if (_priceUsd.text.trim().isNotEmpty)
          'priceCents': ((double.tryParse(_priceUsd.text.trim()) ?? 0) * 100).round(),
        if (_shippingRegion != null) 'shippingRegion': _shippingRegion,
      },
      if (_statusIsEditable) 'status': _status,
    };
    try {
      await PieceService.instance.update(widget.piece.id, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('List for sale'),
              value: _isForSale,
              onChanged: (v) => setState(() => _isForSale = v),
            ),
            if (_isForSale) ...[
              const SizedBox(height: 8),
              _Field(label: 'Price (USD)', controller: _priceUsd),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _openShippingRegionPicker,
                child: Text(_shippingRegion ?? 'Set shipping region'),
              ),
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

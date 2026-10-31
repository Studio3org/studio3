import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/piece_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../widgets/choose_location_sheet.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/studio/studio_chip.dart';
import '../widgets/studio/studio_field.dart';
import '../widgets/studio/studio_switch.dart';
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
      // The sheet closes itself after Done.
      onLocationSelected: (loc) => setState(() => _shippingRegion = loc.displayName),
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

  static String _statusLabel(String status) => switch (status) {
    'draft' => 'Draft',
    'live' => 'Live',
    'delisted' => 'Hidden',
    _ => status,
  };

  /// No board: a light Studio form — underline fields, Studio switches, the shipping city as
  /// a chevron row, status as chips, errors in Ink (never red).
  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget gap() => const SizedBox(height: 22);
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: StudioType.sans(16, color: c.textPrimary))),
          StudioSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
    return StudioLoadingGate(
      loading: _saving,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: 'Edit piece',
          actions: [StudioSaveAction(onPressed: _saving ? null : _save)],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            StudioUnderlineField(label: 'Title', controller: _title),
            gap(),
            StudioUnderlineField(
              label: 'Description',
              controller: _caption,
              maxLines: 5,
              minLines: 1,
            ),
            gap(),
            StudioUnderlineField(label: 'Medium', controller: _medium),
            gap(),
            StudioUnderlineField(
              label: 'Dimensions',
              controller: _dimensions,
              mono: true,
              valueSize: 18,
              hint: '24x36x1.5 in',
            ),
            gap(),
            StudioUnderlineField(
              label: 'Year created',
              controller: _yearCreated,
              mono: true,
              valueSize: 18,
              keyboardType: TextInputType.number,
            ),
            gap(),
            StudioUnderlineField(label: 'Framing', controller: _framingMounting),
            gap(),
            StudioUnderlineField(
              label: 'Provenance',
              controller: _provenance,
              maxLines: 4,
              minLines: 1,
            ),
            gap(),
            StudioUnderlineField(
              label: 'Handling notes',
              controller: _handlingNotes,
              maxLines: 4,
              minLines: 1,
            ),
            gap(),
            StudioUnderlineField(
              label: 'Materials and tools',
              controller: _materials,
              helper: 'Separate them with commas.',
            ),
            gap(),
            StudioUnderlineField(
              label: 'Style',
              controller: _styleTags,
              helper: 'Separate them with commas.',
            ),
            gap(),
            StudioUnderlineField(
              label: 'Alt text',
              controller: _altText,
              maxLines: 3,
              minLines: 1,
              helper: 'Describes the image for people using a screen reader.',
            ),
            const SizedBox(height: 14),
            toggle('Made with AI tools', _aiDisclosed, (v) => setState(() => _aiDisclosed = v)),
            toggle('List for sale', _isForSale, (v) => setState(() => _isForSale = v)),
            if (_isForSale) ...[
              const SizedBox(height: 14),
              StudioUnderlineField(
                label: 'Price',
                controller: _priceUsd,
                valueSize: 18,
                hint: r'$0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              PostChevronRow(
                label: 'Ships from',
                value: _shippingRegion,
                onTap: _openShippingRegionPicker,
              ),
            ],
            gap(),
            if (_statusIsEditable) ...[
              Text('Status', style: StudioType.label13(color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in _editableStatuses)
                    StudioChip(
                      label: _statusLabel(status),
                      selected: _status == status,
                      onTap: () => setState(() => _status = status),
                    ),
                ],
              ),
            ] else
              Text(
                'Status: ${_statusLabel(widget.piece.status ?? '')}. Checkout changes it.',
                style: StudioType.label13(color: c.textSecondary),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: StudioType.body14(color: c.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}

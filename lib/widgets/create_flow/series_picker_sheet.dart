import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/series_summary.dart';
import '../../services/series_service.dart';
import 'create_series_dialog.dart';

class SeriesPickerResult {
  const SeriesPickerResult({
    this.selectedSeriesId,
    this.newSeriesName,
    this.displayLabel,
  });

  final String? selectedSeriesId;
  final String? newSeriesName;
  final String? displayLabel;

  bool get hasSelection =>
      (selectedSeriesId != null && selectedSeriesId!.isNotEmpty) ||
      (newSeriesName != null && newSeriesName!.isNotEmpty);

  static const cleared = SeriesPickerResult();
}

/// Single-select series picker for the create-piece flow.
class SeriesPickerSheet extends StatefulWidget {
  const SeriesPickerSheet({
    super.key,
    this.selectedSeriesId,
    this.newSeriesName,
  });

  final String? selectedSeriesId;
  final String? newSeriesName;

  static Future<SeriesPickerResult?> show(
    BuildContext context, {
    String? selectedSeriesId,
    String? newSeriesName,
  }) {
    return showModalBottomSheet<SeriesPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => SeriesPickerSheet(
        selectedSeriesId: selectedSeriesId,
        newSeriesName: newSeriesName,
      ),
    );
  }

  @override
  State<SeriesPickerSheet> createState() => _SeriesPickerSheetState();
}

class _SeriesPickerSheetState extends State<SeriesPickerSheet> {
  static const _sheetBg = Color(0xFF231F1B);
  static const _textSecondary = Color(0xFF8C8880);
  static const _handleColor = Color(0xFF4A4843);

  List<SeriesSummary> _series = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;
  String? _pendingNewName;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedSeriesId;
    _pendingNewName = widget.newSeriesName;
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final series = await SeriesService.instance.getMySeries();
      if (!mounted) return;
      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createNewSeries() async {
    final name = await CreateSeriesDialog.show(context);
    if (name == null || !mounted) return;
    setState(() {
      _pendingNewName = name;
      _selectedId = null;
    });
    Navigator.pop(
      context,
      SeriesPickerResult(
        newSeriesName: name,
        displayLabel: name,
      ),
    );
  }

  void _selectNone() {
    Navigator.pop(context, SeriesPickerResult.cleared);
  }

  void _selectExisting(SeriesSummary series) {
    Navigator.pop(
      context,
      SeriesPickerResult(
        selectedSeriesId: series.id,
        displayLabel: series.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.32,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add to series',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _createNewSeries,
                      child: Text(
                        'New series',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Could not load series.\nYou can still publish without one.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset + 16),
                            children: [
                              _SeriesRadioTile(
                                title: 'None',
                                subtitle: 'Do not add to a series',
                                selected: _selectedId == null &&
                                    (_pendingNewName == null ||
                                        _pendingNewName!.isEmpty),
                                onTap: _selectNone,
                              ),
                              if (_pendingNewName != null &&
                                  _pendingNewName!.isNotEmpty)
                                _SeriesRadioTile(
                                  title: _pendingNewName!,
                                  subtitle: 'New series (created on publish)',
                                  selected: true,
                                  onTap: () {},
                                ),
                              for (final series in _series)
                                _SeriesRadioTile(
                                  title: series.name,
                                  subtitle:
                                      '${series.pieceCount} piece${series.pieceCount == 1 ? '' : 's'}',
                                  selected: _selectedId == series.id,
                                  onTap: () => _selectExisting(series),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeriesRadioTile extends StatelessWidget {
  const _SeriesRadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? Colors.white : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8C8880),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

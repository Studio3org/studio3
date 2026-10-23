import 'package:flutter/material.dart';

import '../../models/series_summary.dart';
import '../../services/series_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';
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

/// Single-select series picker for the create-piece flow. No board: a board sheet with
/// the picker rows of `PostMedium` (title 16, piece count under it, left-line selection),
/// None first, a pending new series when there is one, and "New series" as an action row.
class SeriesPickerSheet extends StatefulWidget {
  const SeriesPickerSheet({
    super.key,
    this.selectedSeriesId,
    this.newSeriesName,
    this.debugSeries,
  });

  final String? selectedSeriesId;
  final String? newSeriesName;

  /// Series to show instead of loading them, for tests.
  @visibleForTesting
  final List<SeriesSummary>? debugSeries;

  static Future<SeriesPickerResult?> show(
    BuildContext context, {
    String? selectedSeriesId,
    String? newSeriesName,
  }) {
    return showStudioSheet<SeriesPickerResult>(
      context: context,
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
  List<SeriesSummary> _series = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final given = widget.debugSeries;
    if (given != null) {
      _series = given;
      _loading = false;
    } else {
      _loadSeries();
    }
  }

  Future<void> _loadSeries() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final series = await SeriesService.instance.getMySeries();
      if (!mounted) return;
      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _createNewSeries() async {
    final name = await CreateSeriesDialog.show(context);
    if (name == null || !mounted) return;
    Navigator.pop(context, SeriesPickerResult(newSeriesName: name, displayLabel: name));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final pending = widget.newSeriesName;
    final noneSelected =
        (widget.selectedSeriesId == null || widget.selectedSeriesId!.isEmpty) &&
        (pending == null || pending.isEmpty);
    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      scrollable: true,
      children: [
        Text('Series', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'Group it with related pieces. A piece can be in one series.',
          style: StudioType.body14(height: 1.45, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
              ),
            ),
          )
        else ...[
          if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Couldn't load your series. You can still publish without one.",
                style: StudioType.body14(color: c.textSecondary),
              ),
            ),
          StudioListRow(
            title: 'None',
            subtitle: 'Not in a series',
            selected: noneSelected,
            onTap: () => Navigator.pop(context, SeriesPickerResult.cleared),
          ),
          if (pending != null && pending.isNotEmpty)
            StudioListRow(
              title: pending,
              subtitle: 'New series, made when you publish',
              selected: true,
              onTap: () => Navigator.pop(
                context,
                SeriesPickerResult(newSeriesName: pending, displayLabel: pending),
              ),
            ),
          for (final series in _series)
            StudioListRow(
              title: series.name,
              subtitle: '${series.pieceCount} ${series.pieceCount == 1 ? 'piece' : 'pieces'}',
              selected: series.id == widget.selectedSeriesId,
              onTap: () => Navigator.pop(
                context,
                SeriesPickerResult(selectedSeriesId: series.id, displayLabel: series.name),
              ),
            ),
        ],
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: _createNewSeries,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  StudioIcon(StudioIcons.addBold, size: 20, color: c.textPrimary),
                  const SizedBox(width: 12),
                  Text(
                    'New series',
                    style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/series_summary.dart';
import '../../services/series_service.dart';
import '../studio/studio.dart';

class SeriesPickerResult {
  const SeriesPickerResult({
    this.selectedSeriesId,
    this.newSeriesName,
    this.newSeriesDescription,
    this.displayLabel,
  });

  final String? selectedSeriesId;
  final String? newSeriesName;
  final String? newSeriesDescription;
  final String? displayLabel;

  bool get hasSelection =>
      (selectedSeriesId != null && selectedSeriesId!.isNotEmpty) ||
      (newSeriesName != null && newSeriesName!.isNotEmpty);

  static const cleared = SeriesPickerResult();
}

/// Series picker (`SeriesPicker`): opens from the Series row when posting a piece.
///
/// "Series" 22/500; None ("This piece stands alone"), then the artist's series as option
/// rows (16; the selected one 500 Ink with the left line, the piece count in Mono 11 caps);
/// a pending new series when there is one; "+ New series" opens [SeriesNewSheet]; Done.
class SeriesPickerSheet extends StatefulWidget {
  const SeriesPickerSheet({
    super.key,
    this.selectedSeriesId,
    this.newSeriesName,
    this.newSeriesDescription,
    this.debugSeries,
  });

  final String? selectedSeriesId;
  final String? newSeriesName;
  final String? newSeriesDescription;

  /// Series to show instead of loading them, for tests.
  @visibleForTesting
  final List<SeriesSummary>? debugSeries;

  static Future<SeriesPickerResult?> show(
    BuildContext context, {
    String? selectedSeriesId,
    String? newSeriesName,
    String? newSeriesDescription,
  }) {
    return showStudioSheet<SeriesPickerResult>(
      context: context,
      builder: (context) => SeriesPickerSheet(
        selectedSeriesId: selectedSeriesId,
        newSeriesName: newSeriesName,
        newSeriesDescription: newSeriesDescription,
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
  late SeriesPickerResult _choice;

  @override
  void initState() {
    super.initState();
    final pending = widget.newSeriesName;
    _choice = pending != null && pending.isNotEmpty
        ? SeriesPickerResult(
            newSeriesName: pending,
            newSeriesDescription: widget.newSeriesDescription,
            displayLabel: pending,
          )
        : SeriesPickerResult(selectedSeriesId: widget.selectedSeriesId);
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
        final id = _choice.selectedSeriesId;
        if (id != null) {
          for (final s in series) {
            if (s.id == id) _choice = SeriesPickerResult(selectedSeriesId: id, displayLabel: s.name);
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// "Create series makes it with this piece as the first one and goes back to posting."
  Future<void> _createNewSeries() async {
    final created = await SeriesNewSheet.show(context);
    if (created == null || !mounted) return;
    Navigator.pop(
      context,
      SeriesPickerResult(
        newSeriesName: created.name,
        newSeriesDescription: created.description,
        displayLabel: created.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final pending = widget.newSeriesName;
    final rows = <({String title, String subtitle, bool selected, VoidCallback onTap})>[
      (
        title: 'None',
        subtitle: 'This piece stands alone',
        selected: !_choice.hasSelection,
        onTap: () => setState(() => _choice = SeriesPickerResult.cleared),
      ),
      if (pending != null && pending.isNotEmpty)
        (
          title: pending,
          subtitle: 'NEW · MADE WHEN YOU PUBLISH',
          selected: _choice.newSeriesName == pending,
          onTap: () => setState(
            () => _choice = SeriesPickerResult(
              newSeriesName: pending,
              newSeriesDescription: widget.newSeriesDescription,
              displayLabel: pending,
            ),
          ),
        ),
      for (final series in _series)
        (
          title: series.name,
          subtitle: '${series.pieceCount} ${series.pieceCount == 1 ? 'PIECE' : 'PIECES'}',
          selected: series.id == _choice.selectedSeriesId,
          onTap: () => setState(
            () => _choice = SeriesPickerResult(
              selectedSeriesId: series.id,
              displayLabel: series.name,
            ),
          ),
        ),
    ];
    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      scrollable: true,
      children: [
        const SizedBox(height: 8),
        Text('Series', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 14),
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
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "Couldn't load your series. You can still publish without one.",
                style: StudioType.body14(color: c.textSecondary),
              ),
            ),
          // The board's sheet is a column with a 10 gap, rows included.
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SeriesOptionRow(
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              selected: rows[i].selected,
              onTap: rows[i].onTap,
              divider: i < rows.length - 1,
            ),
          ],
        ],
        const SizedBox(height: 10),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: _createNewSeries,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: StudioSize.tapTarget,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+ New series',
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StudioButton(label: 'Done', onPressed: () => Navigator.pop(context, _choice)),
      ],
    );
  }
}

/// 16 title (selected: 500 Ink with the left line and a 16 indent; others 400 Graphite) over
/// a Mono 11 grey line; 12 above and below; 1 px Line under unless [divider] is false.
class SeriesOptionRow extends StatelessWidget {
  const SeriesOptionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.divider = true,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
          ),
          child: Stack(
            children: [
              AnimatedPadding(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : StudioMotion.quick,
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(selected ? 16 : 0, 12, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: StudioType.sans(
                        16,
                        weight: selected ? StudioType.medium : StudioType.regular,
                        color: selected ? c.textPrimary : c.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: StudioType.mono(11, color: c.textTertiary)),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: 13,
                  bottom: 13,
                  child: Container(width: 2, color: c.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A new series' name and optional description.
class SeriesDraft {
  const SeriesDraft({required this.name, this.description});

  final String name;
  final String? description;
}

/// New series (`SeriesNew`): "New series" 22/500, an optional line ("This piece will be the
/// first in it." when posting), Name, Description (optional, up to 300 characters), and
/// Create series, off until there is a name. Also edits a name and description.
class SeriesNewSheet extends StatefulWidget {
  const SeriesNewSheet({
    super.key,
    this.subtitle = 'This piece will be the first in it.',
    this.title = 'New series',
    this.action = 'Create series',
    this.initial,
  });

  final String? subtitle;
  final String title;
  final String action;
  final SeriesDraft? initial;

  static const maxDescription = 300;

  static Future<SeriesDraft?> show(
    BuildContext context, {
    String? subtitle = 'This piece will be the first in it.',
    String title = 'New series',
    String action = 'Create series',
    SeriesDraft? initial,
  }) {
    return showStudioSheet<SeriesDraft>(
      context: context,
      builder: (context) =>
          SeriesNewSheet(subtitle: subtitle, title: title, action: action, initial: initial),
    );
  }

  @override
  State<SeriesNewSheet> createState() => _SeriesNewSheetState();
}

class _SeriesNewSheetState extends State<SeriesNewSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '')
    ..addListener(_changed);
  late final _description = TextEditingController(text: widget.initial?.description ?? '');

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final description = _description.text.trim();
    Navigator.pop(
      context,
      SeriesDraft(name: name, description: description.isEmpty ? null : description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 0,
      scrollable: true,
      children: [
        const SizedBox(height: 8),
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(widget.subtitle!, style: StudioType.body14(color: c.textSecondary)),
        ],
        const SizedBox(height: 18),
        StudioUnderlineField(
          label: 'Name',
          controller: _name,
          hint: 'Series name',
          autofocus: widget.initial == null,
          valueSize: 16,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        StudioUnderlineField(
          label: 'Description',
          controller: _description,
          hint: 'What ties these pieces together…',
          helper: 'Optional · up to ${SeriesNewSheet.maxDescription} characters',
          valueSize: 16,
          minLines: 1,
          maxLines: 4,
          maxLength: SeriesNewSheet.maxDescription,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 18),
        StudioButton(label: widget.action, onPressed: _name.text.trim().isEmpty ? null : _submit),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../models/series_summary.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/series_service.dart';
import '../theme/studio_type.dart';
import '../theme/studio_colors.dart';
import '../widgets/create_flow/link_piece_sheet.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/studio/studio_field.dart';
import '../widgets/studio/studio_sheet.dart';
import '../widgets/studio/studio_toast.dart';
import '../widgets/studio_loading.dart';
import '../widgets/studio/studio_tap_area.dart';

/// How Edit series closed, for the page that opened it: saved, or the series is gone.
/// Cancel closes with null.
enum SeriesEditResult { saved, deleted }

class SeriesEditorPage extends StatefulWidget {
  const SeriesEditorPage({
    super.key,
    required this.seriesId,
    this.debugSeries,
    this.debugPieces,
  });

  final String seriesId;

  /// For tests: the series and its pieces (newest first) instead of loading them.
  @visibleForTesting
  final SeriesSummary? debugSeries;
  @visibleForTesting
  final List<PieceSummary>? debugPieces;

  @override
  State<SeriesEditorPage> createState() => _SeriesEditorPageState();
}

class _SeriesEditorPageState extends State<SeriesEditorPage> {
  SeriesSummary? _series;
  List<PieceSummary> _piecesInSeries = [];
  bool _loading = true;
  bool _busy = false;
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    final series = widget.debugSeries;
    if (series != null) {
      _series = series;
      _piecesInSeries = widget.debugPieces ?? const [];
      _name.text = series.name;
      _description.text = series.description ?? '';
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final series = await SeriesService.instance.getById(widget.seriesId);
      final username = AuthSession.instance.user?.username;
      List<PieceSummary> allPieces = [];
      if (username != null) {
        allPieces = await PieceService.instance.getUserPieces(username);
      }
      // Newest first, as the profile lists them (`NoteSeriesEdit`).
      final inSeries = series.pieceIds.toSet();
      final ordered = [for (final p in allPieces) if (inSeries.contains(p.id)) p];
      if (!mounted) return;
      setState(() {
        if (_series == null) {
          _name.text = series.name;
          _description.text = series.description ?? '';
        }
        _series = series;
        _piecesInSeries = ordered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : e.toString();
    showStudioToast(context, message, icon: null);
  }

  /// Save: the name and description, then back to the series list.
  Future<void> _save() async {
    final series = _series;
    final name = _name.text.trim();
    if (series == null || name.isEmpty || _busy) return;
    final description = _description.text.trim();
    setState(() => _busy = true);
    try {
      await SeriesService.instance.update(
        widget.seriesId,
        name: name == series.name ? null : name,
        description: description == (series.description ?? '') ? null : description,
      );
      if (!mounted) return;
      Navigator.pop(context, SeriesEditResult.saved);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  /// Delete series (`NoteSeriesEdit`): asks first; the pieces stay on the profile, just not
  /// grouped (BACKEND_CHANGES B15).
  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showStudioConfirm(
      context,
      title: 'Delete this series?',
      message: 'The pieces stay on your profile, just not grouped.',
      confirmLabel: 'Delete series',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await SeriesService.instance.delete(widget.seriesId);
      if (!mounted) return;
      Navigator.pop(context, SeriesEditResult.deleted);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _removePiece(String pieceId) async {
    setState(() => _busy = true);
    try {
      await SeriesService.instance.removePiece(widget.seriesId, pieceId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<Set<String>> _assignedPieceIds() async {
    final all = await SeriesService.instance.getMySeries();
    final ids = <String>{};
    for (final series in all) {
      ids.addAll(series.pieceIds);
    }
    return ids;
  }

  Future<void> _addPieces() async {
    final username = AuthSession.instance.user?.username;
    if (username == null) return;

    setState(() => _busy = true);
    try {
      final allPieces = await PieceService.instance.getUserPieces(username);
      final assigned = await _assignedPieceIds();
      final inSeries = _piecesInSeries.map((p) => p.id).toSet();
      final available = allPieces
          .where((p) => !assigned.contains(p.id) && !inSeries.contains(p.id))
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _busy = false);

      if (available.isEmpty) {
        showStudioToast(context, 'No pieces available to add (each piece can belong to one series)', icon: null);
        return;
      }

      final picked = await LinkPieceSheet.show(
        context,
        pieces: available,
        selectedIds: const [],
        title: 'Add pieces',
        mark: 'Added',
      );
      final selected = picked?.map((p) => p.id).toSet();
      if (selected == null || selected.isEmpty || !mounted) return;
      setState(() => _busy = true);
      var added = 0;
      for (final pieceId in selected) {
        try {
          await SeriesService.instance.addPiece(widget.seriesId, pieceId);
          added++;
        } on ApiException catch (e) {
          if (!mounted) return;
          showStudioToast(context, e.message, icon: null);
        }
      }
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      if (added > 0) {
        showStudioToast(context, 'Added $added piece${added == 1 ? '' : 's'}', icon: null);
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  /// `SeriesEdit`: Cancel, "Edit series" and Save; Name and Description (optional, up to 300
  /// characters); "Pieces · newest first" with a 36 × 48 cover, the title 15 and Remove 13
  /// Graphite per row; "+ Add pieces" under the list; "Delete series" 14 Graphite, centred,
  /// 8 below (BACKEND_CHANGES B15).
  @override
  Widget build(BuildContext context) {
    final series = _series;
    final c = context.studio;

    return StudioLoadingGate(
      loading: _loading || _busy,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Edit series',
                        style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _HeaderAction(
                          label: 'Cancel',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ValueListenableBuilder(
                          valueListenable: _name,
                          builder: (context, value, _) => _HeaderAction(
                            label: 'Save',
                            bold: true,
                            onTap: value.text.trim().isEmpty ? null : _save,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: series == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                        children: [
                          StudioUnderlineField(
                            label: 'Name',
                            controller: _name,
                            valueSize: 16,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 20),
                          StudioUnderlineField(
                            label: 'Description',
                            controller: _description,
                            hint: 'What ties these pieces together…',
                            helper: 'Optional · up to ${SeriesNewSheet.maxDescription} characters',
                            valueSize: 16,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: SeriesNewSheet.maxDescription,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'Pieces · newest first',
                            style: StudioType.sans(13, color: c.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          if (_piecesInSeries.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No pieces in this series yet.',
                                style: StudioType.body14(color: c.textSecondary),
                              ),
                            )
                          else
                            for (final piece in _piecesInSeries)
                              _PieceRow(piece: piece, onRemove: () => _removePiece(piece.id)),
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: _addPieces,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 52,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '+ Add pieces',
                                    style: StudioType.sans(
                                      15,
                                      weight: StudioType.medium,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // A link on the board: 14 Graphite, underlined, centred (as Cancel
                          // event on Manage event).
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: _delete,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 44,
                                child: Center(
                                  child: Text(
                                    'Delete series',
                                    style: StudioType.body14(color: c.textSecondary).copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor: c.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
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

/// Cancel / Save in the header: 15, Save 500; 12 sides, 44 tall.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap, this.bold = false});

  final String label;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioTapArea(child: Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            label,
            style: StudioType.sans(
              15,
              weight: bold ? StudioType.medium : StudioType.regular,
              color: onTap == null ? c.textPlaceholder : c.textPrimary,
            ),
          ),
        ),
      ),
    ));
  }
}

/// 36 × 48 cover (radius 6), the title 15, Remove 13 Graphite; 10 above and below.
class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, required this.onRemove});

  final PieceSummary piece;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = piece.mediaUrl;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 48,
              child: url != null && url.isNotEmpty
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                  : ColoredBox(color: c.surface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              piece.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.sans(15, color: c.textPrimary),
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove ${piece.title}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Text('Remove', style: StudioType.sans(13, color: c.textSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

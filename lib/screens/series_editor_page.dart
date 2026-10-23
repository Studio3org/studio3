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
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../widgets/create_flow/create_series_dialog.dart';
import '../widgets/create_flow/link_piece_sheet.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/studio/studio_button.dart';
import '../widgets/studio/studio_toast.dart';
import '../widgets/studio_loading.dart';

class SeriesEditorPage extends StatefulWidget {
  const SeriesEditorPage({
    super.key,
    required this.seriesId,
  });

  final String seriesId;

  @override
  State<SeriesEditorPage> createState() => _SeriesEditorPageState();
}

class _SeriesEditorPageState extends State<SeriesEditorPage> {
  SeriesSummary? _series;
  List<PieceSummary> _piecesInSeries = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      final pieceMap = {for (final p in allPieces) p.id: p};
      final ordered = <PieceSummary>[];
      for (final id in series.pieceIds) {
        final piece = pieceMap[id];
        if (piece != null) ordered.add(piece);
      }
      if (!mounted) return;
      setState(() {
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

  Future<void> _renameSeries() async {
    final series = _series;
    if (series == null) return;
    final name = await CreateSeriesDialog.show(
      context,
      initialName: series.name,
      title: 'Rename series',
      action: 'Save',
    );
    if (name == null || name == series.name || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await SeriesService.instance.update(
        widget.seriesId,
        name: name,
      );
      if (!mounted) return;
      setState(() {
        _series = updated;
        _busy = false;
      });
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

  /// No board: the light Studio list — the count in Mono, an outline "Add pieces" button,
  /// pieces as 52 covers with title 15/500 and × to remove, a line between.
  @override
  Widget build(BuildContext context) {
    final series = _series;
    final c = context.studio;
    final count = _piecesInSeries.length;

    return StudioLoadingGate(
      loading: _loading || _busy,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: series?.name ?? 'Series',
          onBack: () => Navigator.pop(context, true),
          actions: [
            PostIconButton(icon: StudioIcons.edit, label: 'Rename series', onTap: _renameSeries),
          ],
        ),
        body: series == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$count', style: StudioType.mono(14, color: c.textSecondary)),
                        TextSpan(text: count == 1 ? ' piece in this series' : ' pieces in this series'),
                      ],
                    ),
                    style: StudioType.body14(color: c.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  StudioButton(
                    label: 'Add pieces',
                    variant: StudioButtonVariant.outline,
                    onPressed: _addPieces,
                  ),
                  const SizedBox(height: 12),
                  if (_piecesInSeries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No pieces yet. Add pieces from your profile.',
                        textAlign: TextAlign.center,
                        style: StudioType.body14(height: 1.45, color: c.textSecondary),
                      ),
                    )
                  else
                    ..._piecesInSeries.map(
                      (piece) => _PieceRow(piece: piece, onRemove: () => _removePiece(piece.id)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, required this.onRemove});

  final PieceSummary piece;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = piece.mediaUrl;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 52,
              child: url != null && url.isNotEmpty
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                  : ColoredBox(color: c.surface),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              piece.title,
              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
            ),
          ),
          PostIconButton(
            icon: StudioIcons.close,
            label: 'Remove ${piece.title}',
            color: c.textTertiary,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

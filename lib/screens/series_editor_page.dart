import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/piece_summary.dart';
import '../models/series_summary.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/series_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/create_flow/create_series_dialog.dart';
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renameSeries() async {
    final series = _series;
    if (series == null) return;
    final name = await CreateSeriesDialog.show(
      context,
      initialName: series.name,
      title: 'Rename series',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pieces available to add (each piece can belong to one series)'),
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: HomeFeedTokens.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _AddPiecesSheet(pieces: available),
      );

      if (selected == null || selected.isEmpty || !mounted) return;
      setState(() => _busy = true);
      var added = 0;
      for (final pieceId in selected) {
        try {
          await SeriesService.instance.addPiece(widget.seriesId, pieceId);
          added++;
        } on ApiException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      if (added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $added piece${added == 1 ? '' : 's'}')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;

    return StudioLoadingGate(
      loading: _loading || _busy,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            series?.name ?? 'Series',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: HomeFeedTokens.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context, true),
          ),
          actions: [
            IconButton(
              onPressed: _renameSeries,
              icon: Icon(Icons.edit_outlined,
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.75)),
            ),
          ],
        ),
        body: series == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${_piecesInSeries.length} piece${_piecesInSeries.length == 1 ? '' : 's'} in this series',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addPieces,
                    icon: const Icon(Icons.add),
                    label: const Text('Add pieces'),
                  ),
                  const SizedBox(height: 16),
                  if (_piecesInSeries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No pieces yet. Tap Add pieces to include artwork from your profile.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                    )
                  else
                    ..._piecesInSeries.map(
                      (piece) => _PieceRow(
                        piece: piece,
                        onRemove: () => _removePiece(piece.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.onRemove,
  });

  final PieceSummary piece;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: piece.mediaUrl != null && piece.mediaUrl!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: piece.mediaUrl!, fit: BoxFit.cover)
                  : ColoredBox(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              piece.title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close,
              size: 20,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPiecesSheet extends StatefulWidget {
  const _AddPiecesSheet({required this.pieces});

  final List<PieceSummary> pieces;

  @override
  State<_AddPiecesSheet> createState() => _AddPiecesSheetState();
}

class _AddPiecesSheetState extends State<_AddPiecesSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add pieces',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.pieces.length,
                itemBuilder: (context, index) {
                  final piece = widget.pieces[index];
                  final checked = _selected.contains(piece.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(piece.id);
                        } else {
                          _selected.remove(piece.id);
                        }
                      });
                    },
                    title: Text(
                      piece.title,
                      style: GoogleFonts.inter(fontSize: 15),
                    ),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: piece.mediaUrl != null
                            ? CachedNetworkImage(imageUrl: piece.mediaUrl!, fit: BoxFit.cover)
                            : ColoredBox(color: Colors.grey.shade300),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, Set<String>.from(_selected)),
              child: Text(
                _selected.isEmpty
                    ? 'Select pieces'
                    : 'Add ${_selected.length} piece${_selected.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

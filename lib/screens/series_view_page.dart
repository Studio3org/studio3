import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../models/series_summary.dart';
import '../services/piece_service.dart';
import '../services/series_service.dart';
import '../utils/series_share.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/studio/studio.dart';
import 'profile/profile_constants.dart';
import 'profile/widgets/profile_masonry_grid.dart';
import 'series_editor_page.dart';

/// A series, from the profile Series tab (no board): the cover full width with the white
/// on-image icons (back, share, and more for the owner) and the piece count in Mono; the name
/// 22, the author 13 Graphite and the description 14 centred; a Line; then the pieces grid.
class SeriesViewPage extends StatefulWidget {
  const SeriesViewPage({
    super.key,
    required this.seriesId,
    this.initialName,
    this.initialPieceCount,
    this.initialCoverUrl,
    this.authorName,
    this.authorUsername,
    this.isOwner = false,
  });

  final String seriesId;
  final String? initialName;
  final int? initialPieceCount;
  final String? initialCoverUrl;
  final String? authorName;
  final String? authorUsername;
  final bool isOwner;

  @override
  State<SeriesViewPage> createState() => _SeriesViewPageState();
}

class _SeriesViewPageState extends State<SeriesViewPage> {
  static const _heroHeight = 322.0;

  SeriesSummary? _series;
  List<PieceSummary> _piecesInSeries = const <PieceSummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final series = await SeriesService.instance.getById(widget.seriesId);
      final username = series.authorUsername ?? widget.authorUsername;
      List<PieceSummary> allPieces = const <PieceSummary>[];
      if (username != null) {
        allPieces = await PieceService.instance.getUserPieces(username);
      }
      final pieceMap = {for (final p in allPieces) p.id: p};
      final ordered = <PieceSummary>[
        for (final id in series.pieceIds)
          if (pieceMap[id] != null) pieceMap[id]!,
      ];
      if (!mounted) return;
      setState(() {
        _series = series;
        _piecesInSeries = ordered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _name => _series?.name ?? widget.initialName ?? 'Series';

  int get _pieceCount =>
      _series?.pieceCount ?? widget.initialPieceCount ?? 0;

  String? get _coverUrl {
    final series = _series;
    if (series?.coverUrl != null && series!.coverUrl!.isNotEmpty) {
      return series.coverUrl;
    }
    if (_piecesInSeries.isNotEmpty) {
      return _piecesInSeries.first.mediaUrl;
    }
    return widget.initialCoverUrl;
  }

  String? get _authorName => _series?.authorName ?? widget.authorName;

  String? get _authorUsername =>
      _series?.authorUsername ?? widget.authorUsername;

  List<PieceSummary> get _pieces => _piecesInSeries;

  Future<void> _onMore() async {
    if (!widget.isOwner) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SeriesEditorPage(seriesId: widget.seriesId),
      ),
    );
    if (changed == true) await _load();
  }

  void _onShare() {
    final series = _series;
    if (series == null) return;
    ShareSheet.show(context, shareText: buildSeriesShareText(series));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final pieces = _pieces;
    final description = _series?.description?.trim();
    final cover = _coverUrl;
    final author = [
      if (_authorName?.trim().isNotEmpty == true) _authorName!.trim(),
      if (_authorUsername?.trim().isNotEmpty == true) '@${_authorUsername!.trim()}',
    ].join(' · ');

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: _heroHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => ColoredBox(color: c.surface),
                    )
                  else
                    ColoredBox(color: c.surface),
                  // A soft shade at the bottom for the white count.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.6, 1],
                        colors: [Color(0x00111111), Color(0x8C111111)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: StudioTopIconBar(
                      leading: [
                        StudioTopIcon(
                          icon: StudioIcons.back,
                          onTap: () => Navigator.pop(context),
                          semanticLabel: 'Back',
                        ),
                      ],
                      trailing: [
                        StudioTopIcon(
                          icon: StudioIcons.share,
                          onTap: _series == null ? null : _onShare,
                          semanticLabel: 'Share',
                        ),
                        if (widget.isOwner)
                          StudioTopIcon(icon: StudioIcons.more, onTap: _onMore, semanticLabel: 'Edit series'),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: StudioImageLabel('$_pieceCount ${_pieceCount == 1 ? 'piece' : 'pieces'}', size: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 18, StudioSpace.marginForm, 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Column(
                children: [
                  Text(_name, textAlign: TextAlign.center, style: StudioType.title22(color: c.textPrimary)),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(author, textAlign: TextAlign.center, style: StudioType.label13(color: c.textSecondary)),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: StudioType.body14(height: 1.5, color: c.textBody),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading && pieces.isEmpty)
            const SliverToBoxAdapter(child: ProfileGridSkeleton())
          else if (pieces.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: StudioEmptyState(title: 'No pieces in this series yet'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(kProfileHorizontalPad, 16, kProfileHorizontalPad, 40),
              sliver: ProfileContentGrid.fromPieces(pieces, onPieceTap: (piece) => openProfilePiece(context, piece)),
            ),
        ],
      ),
    );
  }
}

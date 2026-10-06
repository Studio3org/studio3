import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/piece_summary.dart';
import '../models/series_summary.dart';
import '../services/piece_service.dart';
import '../services/series_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/series_share.dart';
import '../widgets/share/share_sheet.dart';
import 'profile/profile_constants.dart';
import 'profile/widgets/profile_masonry_grid.dart';
import 'series_editor_page.dart';
import '../widgets/feed_skeleton.dart';

/// Figma 2725:9434 — series view from the profile Series tab.
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
  static const _backAsset = 'assets/profile/icon_back.svg';
  static const _moreAsset = 'assets/profile/icon_more.svg';
  static const _shareAsset = 'assets/piece/hero_share.svg';

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
    final topInset = MediaQuery.paddingOf(context).top;
    final pieces = _pieces;
    final description = _series?.description?.trim();

    return Scaffold(
      backgroundColor: kProfilePageBackground,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: _heroHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_coverUrl != null && _coverUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: _coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const ColoredBox(color: Color(0xFFE8E6E1)),
                    )
                  else
                    const ColoredBox(color: Color(0xFFE8E6E1)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x6B231F1B),
                          Color(0x00231F1B),
                          Color(0x00231F1B),
                          Color(0xCC231F1B),
                        ],
                        stops: [0, 0.22, 0.62, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: topInset + 19.75 - 16,
                    left: kProfileHorizontalPad - 16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(),
                      icon: SvgPicture.asset(
                        _backAsset,
                        width: 9,
                        height: 16.5,
                      ),
                    ),
                  ),
                  Positioned(
                    top: topInset + 26.8 - 16,
                    right: kProfileHorizontalPad - 16,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _series == null ? null : _onShare,
                          padding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(),
                          icon: SvgPicture.asset(
                            _shareAsset,
                            width: 18,
                            height: 22,
                          ),
                        ),
                        if (widget.isOwner)
                          IconButton(
                            onPressed: _onMore,
                            padding: const EdgeInsets.all(16),
                            constraints: const BoxConstraints(),
                            icon: SvgPicture.asset(
                              _moreAsset,
                              width: 16,
                              height: 2.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      '$_pieceCount ${_pieceCount == 1 ? 'piece' : 'pieces'}',
                      style: kProfileGeist(
                        fontSize: 13,
                        color: HomeFeedTokens.textInverse.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: kProfileTabRule),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                    child: Column(
                      children: [
                        Text(
                          _name,
                          textAlign: TextAlign.center,
                          style: kProfileGeist(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_authorName != null &&
                            _authorName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _authorName!,
                            textAlign: TextAlign.center,
                            style: kProfileGeist(
                              fontSize: 13,
                              color: kProfileTextMuted,
                            ),
                          ),
                        ],
                        if (_authorUsername != null &&
                            _authorUsername!.trim().isNotEmpty)
                          Text(
                            '@$_authorUsername',
                            textAlign: TextAlign.center,
                            style: kProfileGeist(
                              fontSize: 13,
                              color: kProfileTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: kProfileGeist(fontSize: 13, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loading && pieces.isEmpty)
            const SliverToBoxAdapter(child: ProfileGridSkeleton())
          else if (pieces.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No pieces in this series yet',
                    style: kProfileGeist(
                      fontSize: 13,
                      color: kProfileTextMuted,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                kProfileHorizontalPad,
                16,
                kProfileHorizontalPad,
                40,
              ),
              sliver: ProfileContentGrid.fromPieces(
                pieces,
                onPieceTap: (piece) => openProfilePiece(context, piece),
              ),
            ),
        ],
      ),
    );
  }
}

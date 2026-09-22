import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/post_media_assets.dart';
import '../../models/series_summary.dart';
import '../../screens/profile/profile_constants.dart';
import '../../screens/series_view_page.dart';
import '../../services/auth_session.dart';
import '../../services/series_service.dart';
import '../../theme/home_feed_tokens.dart';
import 'create_flow_widgets.dart';
import 'create_series_dialog.dart';
import '../loading/app_skeletons.dart';
import '../../theme/app_fonts.dart';

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

/// Full-screen series picker for the piece Details tab.
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
    return Navigator.of(context).push<SeriesPickerResult>(
      MaterialPageRoute(
        builder: (_) => SeriesPickerSheet(
          selectedSeriesId: selectedSeriesId,
          newSeriesName: newSeriesName,
        ),
      ),
    );
  }

  @override
  State<SeriesPickerSheet> createState() => _SeriesPickerSheetState();
}

class _SeriesPickerSheetState extends State<SeriesPickerSheet> {
  static const _textSecondary = Color(0xFF8C8880);
  static const _disabledFill = Color(0xFFC8C5BC);

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

  bool get _canSubmit =>
      (_selectedId != null && _selectedId!.isNotEmpty) ||
      (_pendingNewName != null && _pendingNewName!.isNotEmpty);

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
  }

  void _selectExisting(SeriesSummary series) {
    setState(() {
      _selectedId = series.id;
      _pendingNewName = null;
    });
  }

  void _selectPending() {
    if (_pendingNewName == null || _pendingNewName!.isEmpty) return;
    setState(() => _selectedId = null);
  }

  void _submit() {
    if (!_canSubmit) return;
    if (_pendingNewName != null &&
        _pendingNewName!.isNotEmpty &&
        _selectedId == null) {
      Navigator.pop(
        context,
        SeriesPickerResult(
          newSeriesName: _pendingNewName,
          displayLabel: _pendingNewName,
        ),
      );
      return;
    }
    final series = _series.where((s) => s.id == _selectedId).firstOrNull;
    Navigator.pop(
      context,
      SeriesPickerResult(
        selectedSeriesId: _selectedId,
        displayLabel: series?.name,
      ),
    );
  }

  void _viewSeries(SeriesSummary series) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesViewPage(
          seriesId: series.id,
          initialName: series.name,
          initialPieceCount: series.pieceCount,
          initialCoverUrl: series.coverUrl,
          authorName: series.authorName,
          authorUsername:
              series.authorUsername ?? AuthSession.instance.user?.username,
          isOwner: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          _PickerBanner(
            topInset: topInset,
            title: 'Add to a series',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: _loading
                ? const OptionListSkeleton()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load series.\nYou can still publish without one.',
                            textAlign: TextAlign.center,
                            style: kProfileGeist(
                              fontSize: 14,
                              color: _textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          if (_pendingNewName != null &&
                              _pendingNewName!.isNotEmpty)
                            _SeriesRow(
                              title: _pendingNewName!,
                              pieceCountLabel: 'New series',
                              selected: _selectedId == null,
                              onTap: _selectPending,
                            ),
                          for (final series in _series)
                            _SeriesRow(
                              title: series.name,
                              pieceCountLabel:
                                  '${series.pieceCount} piece${series.pieceCount == 1 ? '' : 's'}',
                              imageUrl: series.coverUrl ??
                                  (series.previewPieces.isNotEmpty
                                      ? series.previewPieces.first.mediaUrl
                                      : null),
                              selected: _selectedId == series.id,
                              onTap: () => _selectExisting(series),
                              onViewSeries: () => _viewSeries(series),
                            ),
                          _CreateSeriesRow(onTap: _createNewSeries),
                        ],
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 16),
            child: CreateFlowBottomButton(
              label: 'Done',
              height: 40,
              backgroundColor:
                  _canSubmit ? HomeFeedTokens.neutral800 : _disabledFill,
              textColor: HomeFeedTokens.textInverse,
              onTap: _canSubmit ? _submit : null,
              child: Text(
                'Done',
                style: AppFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textInverse,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerBanner extends StatelessWidget {
  const _PickerBanner({
    required this.topInset,
    required this.title,
    required this.onBack,
  });

  final double topInset;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 53,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      PostMediaAssets.createBannerBack,
                      width: 7,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        HomeFeedTokens.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: kProfileGeist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.title,
    required this.pieceCountLabel,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.onViewSeries,
  });

  final String title;
  final String pieceCountLabel;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onViewSeries;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: Color(0xFFE2DED6),
                        ),
                      )
                    : const ColoredBox(color: Color(0xFFE2DED6)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: kProfileGeist(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pieceCountLabel,
                    style: kProfileGeist(
                      fontSize: 12,
                      color: const Color(0xFF8C8880),
                    ),
                  ),
                  if (onViewSeries != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: onViewSeries,
                      child: Text(
                        'View series',
                        style: kProfileGeist(
                          fontSize: 12,
                          color: HomeFeedTokens.sky600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CreateSeriesRow extends StatelessWidget {
  const _CreateSeriesRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CustomPaint(
              painter: _DashedRRectPainter(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Create a new series',
              style: kProfileGeist(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8C8880), width: 1.5),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: HomeFeedTokens.textPrimary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8C5BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          const Radius.circular(8),
        ),
      );
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

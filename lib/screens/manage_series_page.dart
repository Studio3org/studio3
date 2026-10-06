import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/series_summary.dart';
import '../services/api_exception.dart';
import '../services/series_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/create_flow/create_series_dialog.dart';
import '../widgets/studio_loading.dart';
import 'profile/models/profile_series_data.dart';
import 'profile/profile_constants.dart';
import 'series_editor_page.dart';

class ManageSeriesPage extends StatefulWidget {
  const ManageSeriesPage({super.key});

  @override
  State<ManageSeriesPage> createState() => _ManageSeriesPageState();
}

class _ManageSeriesPageState extends State<ManageSeriesPage> {
  List<SeriesSummary> _series = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    setState(() => _loading = true);
    try {
      final series = await SeriesService.instance.getMySeries();
      if (!mounted) return;
      setState(() {
        _series = series;
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

  Future<void> _createSeries() async {
    final name = await CreateSeriesDialog.show(context);
    if (name == null || !mounted) return;
    try {
      await SeriesService.instance.create(name: name);
      await _loadSeries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Series "$name" created')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openEditor(SeriesSummary series) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SeriesEditorPage(seriesId: series.id),
      ),
    );
    if (changed == true) await _loadSeries();
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading && _series.isEmpty,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Manage series',
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
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : _createSeries,
          backgroundColor: HomeFeedTokens.textPrimary,
          foregroundColor: HomeFeedTokens.textInverse,
          icon: const Icon(Icons.add),
          label: Text(
            'New series',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadSeries,
          child: _series.isEmpty && !_loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 48),
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 56,
                      color: HomeFeedTokens.textPrimary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Group related pieces into a series. Series appear on your profile once they have more than one piece.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        color: kProfileTextMuted,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: _series.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final series = _series[index];
                    final card = ProfileSeriesData.fromSeries(series);
                    return _ManageSeriesCard(
                      data: card,
                      onTap: () => _openEditor(series),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ManageSeriesCard extends StatelessWidget {
  const _ManageSeriesCard({
    required this.data,
    required this.onTap,
  });

  final ProfileSeriesData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urls = data.stackUrls;
    final previewUrl = urls.isNotEmpty ? urls.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: previewUrl != null
                      ? CachedNetworkImage(
                          imageUrl: previewUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => ColoredBox(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_outlined),
                          ),
                        )
                      : ColoredBox(
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.collections_outlined,
                            color: Colors.grey.shade500,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.pieceCount} piece${data.pieceCount == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kProfileTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

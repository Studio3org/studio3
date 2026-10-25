import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../services/api_exception.dart';
import '../services/series_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../widgets/create_flow/series_picker_sheet.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/studio/studio_empty_state.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_toast.dart';
import '../widgets/studio_loading.dart';
import 'profile/models/profile_series_data.dart';
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
    showStudioToast(context, message, icon: null);
  }

  Future<void> _createSeries() async {
    final draft = await SeriesNewSheet.show(context, subtitle: null);
    if (draft == null || !mounted) return;
    final name = draft.name;
    try {
      await SeriesService.instance.create(name: name, description: draft.description);
      await _loadSeries();
      if (!mounted) return;
      showStudioToast(context, 'Series "$name" created');
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

  /// No board: the light Studio list — 56 cover, name 16/500, Mono count, chevron, a
  /// line between; "New series" in the top bar; the shared empty state.
  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioLoadingGate(
      loading: _loading && _series.isEmpty,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: 'Manage series',
          onBack: () => Navigator.pop(context, true),
          actions: [
            PostIconButton(
              icon: StudioIcons.addBold,
              label: 'New series',
              onTap: _loading ? () {} : _createSeries,
            ),
          ],
        ),
        body: RefreshIndicator(
          color: c.textPrimary,
          onRefresh: _loadSeries,
          child: _series.isEmpty && !_loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  children: [
                    StudioEmptyState(
                      title: 'No series yet',
                      message:
                          'Group related pieces into a series. A series shows on your profile '
                          'once it has more than one piece.',
                      actionLabel: 'New series',
                      onAction: _createSeries,
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  itemCount: _series.length,
                  itemBuilder: (context, index) {
                    final series = _series[index];
                    return _SeriesRow(
                      data: ProfileSeriesData.fromSeries(series),
                      onTap: () => _openEditor(series),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.data, required this.onTap});

  final ProfileSeriesData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final urls = data.stackUrls;
    final previewUrl = urls.isNotEmpty ? urls.first : null;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 56,
                  child: previewUrl != null
                      ? CachedNetworkImage(
                          imageUrl: previewUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => ColoredBox(color: c.surface),
                        )
                      : ColoredBox(color: c.surface),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.pieceCount} ${data.pieceCount == 1 ? 'piece' : 'pieces'}',
                      style: StudioType.mono(12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

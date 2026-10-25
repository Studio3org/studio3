import '../config/app_link_config.dart';
import '../models/series_summary.dart';

String buildSeriesShareText(SeriesSummary series) {
  final byline = series.authorName != null && series.authorName!.isNotEmpty
      ? ' by ${series.authorName}'
      : '';
  final lines = <String>[
    '${series.name}$byline on Studio',
    if (series.description != null && series.description!.trim().isNotEmpty)
      series.description!.trim(),
    AppLinkConfig.seriesUrl(series.id),
  ];
  return lines.join('\n\n');
}

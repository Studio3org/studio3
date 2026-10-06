import 'piece_summary.dart';

class SeriesPreviewPiece {
  const SeriesPreviewPiece({
    required this.id,
    this.mediaUrl,
    this.title,
  });

  final String id;
  final String? mediaUrl;
  final String? title;

  factory SeriesPreviewPiece.fromJson(Map<String, dynamic> json) {
    return SeriesPreviewPiece(
      id: json['id'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (title != null) 'title': title,
      };
}

/// Series row from `GET /api/users/:username/series` or `GET /api/series/:id`.
class SeriesSummary {
  const SeriesSummary({
    required this.id,
    required this.name,
    required this.pieceCount,
    this.previewPieces = const [],
    this.pieceIds = const [],
  });

  final String id;
  final String name;
  final int pieceCount;
  final List<SeriesPreviewPiece> previewPieces;
  final List<String> pieceIds;

  factory SeriesSummary.fromJson(Map<String, dynamic> json) {
    final previews = json['previewPieces'];
    final pieceIds = json['pieceIds'];
    return SeriesSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pieceCount: _intFrom(json['pieceCount']) ??
          (pieceIds is List ? pieceIds.length : previews is List ? previews.length : 0),
      previewPieces: previews is List
          ? previews
              .whereType<Map<String, dynamic>>()
              .map(SeriesPreviewPiece.fromJson)
              .toList(growable: false)
          : const [],
      pieceIds: pieceIds is List
          ? pieceIds.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }

  static int? _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

/// Series embedded on piece detail (`GET /api/pieces/:id`).
class PieceSeriesInfo {
  const PieceSeriesInfo({
    required this.id,
    required this.name,
    this.pieceIds = const [],
    this.previewPieces = const [],
  });

  final String id;
  final String name;
  final List<String> pieceIds;
  final List<SeriesPreviewPiece> previewPieces;

  factory PieceSeriesInfo.fromJson(Map<String, dynamic> json) {
    final previews = json['previewPieces'];
    final pieceIds = json['pieceIds'];
    return PieceSeriesInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pieceIds: pieceIds is List
          ? pieceIds.map((e) => e.toString()).toList(growable: false)
          : const [],
      previewPieces: previews is List
          ? previews
              .whereType<Map<String, dynamic>>()
              .map(SeriesPreviewPiece.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  List<PieceSummary> get previewPieceSummaries => previewPieces
      .map(
        (preview) => PieceSummary(
          id: preview.id,
          title: preview.title ?? '',
          mediaUrl: preview.mediaUrl,
        ),
      )
      .toList(growable: false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pieceIds': pieceIds,
        'previewPieces': previewPieces.map((p) => p.toJson()).toList(),
      };
}

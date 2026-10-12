import 'api_client.dart';

/// What a report points at — mirrors the backend's report target types.
enum ReportTargetType { piece, post, comment, user }

class ReportTarget {
  const ReportTarget.piece(this.id) : type = ReportTargetType.piece;
  const ReportTarget.post(this.id) : type = ReportTargetType.post;
  const ReportTarget.comment(this.id) : type = ReportTargetType.comment;

  /// Users are addressed by username, not id, on the backend.
  const ReportTarget.user(String username)
      : id = username,
        type = ReportTargetType.user;

  final ReportTargetType type;
  final String id;

  /// Noun shown in the UI ("Report scene").
  String get noun => switch (type) {
        ReportTargetType.piece => 'piece',
        ReportTargetType.post => 'scene',
        ReportTargetType.comment => 'comment',
        ReportTargetType.user => 'account',
      };

  String get _path => switch (type) {
        ReportTargetType.piece => '/api/pieces/$id/report',
        ReportTargetType.post => '/api/posts/$id/report',
        ReportTargetType.comment => '/api/comments/$id/report',
        ReportTargetType.user => '/api/users/$id/report',
      };
}

/// Reasons accepted by the backend (`REPORT_REASONS`), with UI labels.
enum ReportReason {
  inappropriate('inappropriate', 'Nudity, violence, or other objectionable content'),
  harassment('harassment', 'Harassment, hate, or bullying'),
  spam('spam', 'Spam or scam'),
  stolenWork('stolen_work', 'Stolen or copied artwork'),
  other('other', 'Something else');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _api = ApiClient.instance;

  /// Flags [target] for moderation review. Repeat reports of the same target
  /// while one is still open are absorbed server-side.
  Future<void> report(
    ReportTarget target, {
    required ReportReason reason,
    String? details,
  }) async {
    final trimmed = details?.trim();
    await _api.post(
      target._path,
      body: {
        'reason': reason.apiValue,
        if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
      },
      auth: true,
    );
  }
}

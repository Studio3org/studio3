/// Reasons a piece, scene, or artist can be reported for — kept in sync with the
/// backend's `REPORT_REASONS` (src/shared/models/report.py).
class ReportReason {
  const ReportReason(this.value, this.label);

  final String value;
  final String label;

  static const spam = ReportReason('spam', 'Spam');
  static const stolenWork = ReportReason('stolen_work', 'Stolen work or copyright');
  static const inappropriate = ReportReason('inappropriate', 'Inappropriate content');
  static const harassment = ReportReason('harassment', 'Harassment or hate speech');
  static const other = ReportReason('other', 'Something else');

  static const all = [spam, stolenWork, inappropriate, harassment, other];
}

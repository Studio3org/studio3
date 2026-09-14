/// One row from `GET /api/reports/mine`.
class UserReport {
  const UserReport({
    required this.id,
    required this.targetType,
    required this.targetLabel,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String targetType;
  final String targetLabel;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory UserReport.fromJson(Map<String, dynamic> json) {
    return UserReport(
      id: json['id'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetLabel: json['targetLabel'] as String? ?? 'Unknown',
      reason: json['reason'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

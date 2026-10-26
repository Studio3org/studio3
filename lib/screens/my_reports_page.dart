import 'package:flutter/material.dart';

import '../models/report_reason.dart';
import '../models/user_report.dart';
import '../services/social_service.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/offline_state.dart';
import '../widgets/studio/studio.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key, this.debugReports});

  /// For tests: the reports, instead of asking the server.
  @visibleForTesting
  final List<UserReport>? debugReports;

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<UserReport> _reports = [];
  bool _loading = true;
  bool _showOfflineState = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final given = widget.debugReports;
    if (given != null) {
      setState(() {
        _reports = given;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final reports = await SocialService.instance.listMyReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _showOfflineState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _showOfflineState = _reports.isEmpty;
      });
    }
  }

  String _reasonLabel(String value) {
    return ReportReason.all
        .firstWhere(
          (r) => r.value == value,
          orElse: () => ReportReason.other,
        )
        .label;
  }

  /// Pending in Ink; Resolved and Dismissed grey (status is the one place colour changes).
  Color _statusColor(StudioColors c, String status) => switch (status) {
    'resolved' || 'dismissed' => c.textTertiary,
    _ => c.textPrimary,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(context: context, title: 'My reports'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final c = context.studio;
    if (_showOfflineState) {
      return OfflineState(onRetry: _load);
    }
    if (_loading && _reports.isEmpty) {
      return const CardListSkeleton(height: 108);
    }
    if (_reports.isEmpty) {
      return const Center(
        child: StudioEmptyState(
          title: 'No reports submitted',
          message: 'Reports you send show up here with what happened to them.',
        ),
      );
    }
    return RefreshIndicator(
      color: c.textPrimary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 4, StudioSpace.marginPage, 40),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          // What was reported 15/500 over the reason 13 Graphite, the status 13/500 on the right;
          // 14 above and below, a Line under (the order rows).
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.targetLabel,
                        style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(_reasonLabel(report.reason), style: StudioType.label13(color: c.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  report.status.isEmpty ? '' : report.status[0].toUpperCase() + report.status.substring(1),
                  style: StudioType.label13(weight: StudioType.medium, color: _statusColor(c, report.status)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/report_reason.dart';
import '../models/user_report.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/offline_state.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

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

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
      case 'dismissed':
        return AppColors.slate500;
      default:
        return const Color(0xFFC47B2B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        title: Text(
          'My reports',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_showOfflineState) {
      return OfflineState(onRetry: _load);
    }
    if (_loading && _reports.isEmpty) {
      return const CardListSkeleton(height: 108);
    }
    if (_reports.isEmpty) {
      return Center(
        child: Text(
          'No reports submitted',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.targetLabel,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _reasonLabel(report.reason),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(report.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      report.status[0].toUpperCase() + report.status.substring(1),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _statusColor(report.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

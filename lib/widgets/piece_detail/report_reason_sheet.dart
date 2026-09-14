import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/report_reason.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/home_feed_tokens.dart';

/// Result of [ReportReasonSheet.show]: the chosen reason value, plus optional
/// free-text details (only ever set for [ReportReason.other]).
class ReportReasonResult {
  const ReportReasonResult(this.reason, {this.details});

  final String reason;
  final String? details;
}

/// Reusable reason picker for reporting a piece, scene, or artist. Returns
/// `null` if the user backs out without picking a reason.
class ReportReasonSheet extends StatefulWidget {
  const ReportReasonSheet({super.key, required this.title});

  final String title;

  static Future<ReportReasonResult?> show(
    BuildContext context, {
    required String title,
  }) {
    return showModalBottomSheet<ReportReasonResult>(
      context: context,
      backgroundColor: HomeFeedTokens.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ReportReasonSheet(title: title),
        ),
      ),
    );
  }

  @override
  State<ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<ReportReasonSheet> {
  ReportReason? _pendingOther;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingOther != null) {
      return _buildDetailsStep(context);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.title,
              style: GoogleFonts.geist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CollectDetailTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final reason in ReportReason.all)
            ListTile(
              onTap: () {
                if (reason == ReportReason.other) {
                  setState(() => _pendingOther = reason);
                  return;
                }
                Navigator.pop(context, ReportReasonResult(reason.value));
              },
              title: Text(
                reason.label,
                style: GoogleFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tell us more',
            style: GoogleFonts.geist(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CollectDetailTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            autofocus: true,
            maxLength: 1000,
            maxLines: 4,
            style: GoogleFonts.geist(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'What\'s going on? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _pendingOther = null),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  ReportReasonResult(
                    _pendingOther!.value,
                    details: _detailsController.text.trim().isEmpty
                        ? null
                        : _detailsController.text.trim(),
                  ),
                ),
                child: Text(
                  'Submit report',
                  style: GoogleFonts.geist(color: const Color(0xFFC45C4A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

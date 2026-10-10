import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_session.dart';
import '../services/report_service.dart';
import '../services/social_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/require_login.dart';

const _danger = Color(0xFFE05252);

/// "•••" menu for someone else's piece, scene, comment, or profile: Report
/// it, and Block the account behind it (App Store guideline 1.2). Both need an
/// account, so a guest is asked to log in first.
///
/// [onBlocked] runs after a successful block — e.g. a detail page pops
/// itself, since everything from that account is now hidden.
Future<void> showContentActionsSheet(
  BuildContext context, {
  required ReportTarget target,
  String? authorUsername,
  VoidCallback? onBlocked,
}) {
  final me = AuthSession.instance.user?.username;
  final canBlock = authorUsername != null &&
      authorUsername.isNotEmpty &&
      authorUsername.toLowerCase() != me?.toLowerCase();

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: HomeFeedTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: _danger),
            title: Text(
              'Report ${target.noun}',
              style: const TextStyle(
                color: _danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              showReportSheet(context, target: target);
            },
          ),
          if (canBlock)
            ListTile(
              leading: const Icon(Icons.block_outlined, color: _danger),
              title: Text(
                'Block @$authorUsername',
                style: const TextStyle(
                  color: _danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmBlockUser(
                  context,
                  username: authorUsername,
                  onBlocked: onBlocked,
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Confirms, then blocks [username]. Their content disappears from feeds
/// immediately (see `BlockedAuthorsStore`) and they can't message the user.
Future<void> confirmBlockUser(
  BuildContext context, {
  required String username,
  VoidCallback? onBlocked,
}) async {
  if (!await requireLogin(
    context,
    message: 'Log in to block accounts you don\'t want to see.',
  )) {
    return;
  }
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block @$username?'),
      content: const Text(
        "You won't see their pieces, scenes, or comments, and they can't "
        "message you. They won't be notified. You can unblock anytime from "
        'Settings → Blocked accounts.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block', style: TextStyle(color: _danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await SocialService.instance.blockUser(username);
    messenger.showSnackBar(SnackBar(content: Text('Blocked @$username')));
    onBlocked?.call();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to block user: $e')),
    );
  }
}

/// Reason picker + optional details, then files the report.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
}) async {
  if (!await requireLogin(
    context,
    message: 'Log in to report content that breaks our Terms of Use.',
  )) {
    return;
  }
  if (!context.mounted) return;
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: HomeFeedTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportSheet(target: target),
  );
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Thanks — we received your report and will review it within '
          '24 hours.',
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target});

  final ReportTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _detailsController = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ReportService.instance.report(
        widget.target,
        reason: reason,
        details: _detailsController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report ${widget.target.noun}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Why are you reporting this? Your report is anonymous.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: HomeFeedTokens.textPrimary,
                        title: Text(
                          reason.label,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _detailsController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add details (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 12, color: _danger),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _reason == null || _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_sending ? 'Sending…' : 'Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/report_service.dart';
import '../services/social_service.dart';
import '../utils/require_login.dart';
import 'studio/studio.dart';

/// "•••" menu for someone else's piece, scene, comment, or profile: Report
/// it, and Block the account behind it (App Store guideline 1.2). Both need an
/// account, so a guest is asked to log in first.
///
/// No board of its own: built as `ConvMenu` (Ink rows with outline icons, no red).
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

  return showStudioSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => StudioSheet(
      horizontalPadding: 24,
      gap: 6,
      children: [
        const SizedBox(height: 2),
        if (canBlock)
          StudioActionRow(
            icon: StudioIcons.block,
            title: 'Block @$authorUsername',
            onTap: () {
              Navigator.pop(sheetContext);
              confirmBlockUser(context, username: authorUsername, onBlocked: onBlocked);
            },
          ),
        StudioActionRow(
          icon: StudioIcons.report,
          title: 'Report ${target.noun}',
          onTap: () {
            Navigator.pop(sheetContext);
            showReportSheet(context, target: target);
          },
        ),
      ],
    ),
  );
}

/// Conversation options (`ConvMenu`): opened from the three dots in a conversation.
///
/// Person header (40 avatar, name, handle), then Mute notifications (a switch: "You will
/// still get messages, just no alerts"), View profile, Block [name] ("They will not be able to
/// message you"; confirms first) and Report ("Tell Studio 3 about a message or this person";
/// a short list of reasons).
///
/// Mute shows only with [onMuteChanged] (a chat that exists yet). It is called with the new
/// state and returns the state the server kept; the switch follows it.
Future<void> showConversationMenu(
  BuildContext context, {
  required String username,
  required String name,
  String? avatarUrl,
  required VoidCallback onViewProfile,
  VoidCallback? onBlocked,
  bool muted = false,
  Future<bool> Function(bool muted)? onMuteChanged,
}) {
  final shown = name.trim().isEmpty ? username : name.trim();
  var mutedNow = muted;
  return showStudioSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => StudioSheet(
      horizontalPadding: 24,
      gap: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: StudioActionSheetPerson(
            name: shown,
            handle: '@$username',
            avatarUrl: avatarUrl,
          ),
        ),
        if (onMuteChanged != null)
          StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> change(bool next) async {
                setSheetState(() => mutedNow = next);
                final kept = await onMuteChanged(next);
                if (context.mounted) setSheetState(() => mutedNow = kept);
              }

              return StudioActionRow(
                icon: StudioIcons.bellOff,
                title: 'Mute notifications',
                subtitle: 'You will still get messages, just no alerts',
                onTap: () => change(!mutedNow),
                trailing: StudioSwitch(
                  value: mutedNow,
                  onChanged: change,
                  semanticLabel: 'Mute notifications',
                ),
              );
            },
          ),
        StudioActionRow(
          icon: StudioIcons.profile,
          title: 'View profile',
          onTap: () {
            Navigator.pop(sheetContext);
            onViewProfile();
          },
        ),
        StudioActionRow(
          icon: StudioIcons.block,
          title: 'Block $shown',
          subtitle: 'They will not be able to message you',
          onTap: () {
            Navigator.pop(sheetContext);
            confirmBlockUser(context, username: username, name: shown, onBlocked: onBlocked);
          },
        ),
        StudioActionRow(
          icon: StudioIcons.report,
          title: 'Report',
          subtitle: 'Tell Studio 3 about a message or this person',
          onTap: () {
            Navigator.pop(sheetContext);
            showReportSheet(
              context,
              target: ReportTarget.user(username),
              title: 'Report $shown',
              reasons: conversationReportReasons,
            );
          },
        ),
      ],
    ),
  );
}

/// The reasons offered from a conversation (`NoteConvMenu`: spam, scam or fraud,
/// harassment, something else), plus inappropriate content.
const conversationReportReasons = [
  ReportReason.spam,
  ReportReason.harassment,
  ReportReason.inappropriate,
  ReportReason.other,
];

/// Confirms, then blocks [username]. Their content disappears from feeds
/// immediately (see `BlockedAuthorsStore`) and they can't message the user.
Future<void> confirmBlockUser(
  BuildContext context, {
  required String username,
  String? name,
  VoidCallback? onBlocked,
}) async {
  if (!await requireLogin(
    context,
    title: 'Sign in to block',
    message: 'Log in to block accounts you don\'t want to see.',
  )) {
    return;
  }
  if (!context.mounted) return;
  final confirmed = await showStudioSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _BlockConfirmSheet(name: name ?? '@$username'),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await SocialService.instance.blockUser(username);
    if (context.mounted) showStudioToast(context, 'Blocked ${name ?? '@$username'}');
    onBlocked?.call();
  } catch (e) {
    if (context.mounted) showStudioToast(context, 'Could not block. Try again.', icon: null);
  }
}

/// "Block [name]?", what blocking does, then Block (Ink) and Cancel.
class _BlockConfirmSheet extends StatelessWidget {
  const _BlockConfirmSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Block $name?', style: StudioType.title22(color: c.textPrimary)),
        Text(
          "They can't message you, and you won't see their pieces, scenes or comments. "
          "They won't be told. You can unblock them in Settings, Blocked accounts.",
          style: StudioType.body14(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        StudioButton(label: 'Block', onPressed: () => Navigator.pop(context, true)),
        StudioButton(
          label: 'Cancel',
          variant: StudioButtonVariant.text,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );
  }
}

/// Reason picker + optional details, then files the report.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  String? title,
  List<ReportReason> reasons = ReportReason.values,
}) async {
  if (!await requireLogin(
    context,
    title: 'Sign in to report',
    message: 'Log in to report content that breaks our Terms of Use.',
  )) {
    return;
  }
  if (!context.mounted) return;
  final submitted = await showStudioSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => ReportSheet(
      target: target,
      title: title ?? 'Report ${target.noun}',
      reasons: reasons,
    ),
  );
  if (submitted == true && context.mounted) {
    showStudioToast(context, 'Thanks. We will review it within 24 hours.');
  }
}

/// Title, "The person is not told who reported them.", the reasons as list rows, optional
/// details, then Send report.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.target,
    required this.title,
    this.reasons = ReportReason.values,
  });

  final ReportTarget target;
  final String title;
  final List<ReportReason> reasons;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
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
        _error = 'Could not send the report. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 8,
      scrollable: true,
      children: [
        const SizedBox(height: 4),
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        Text(
          'Why are you reporting this? The person is not told who reported them.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final reason in widget.reasons)
              StudioListRow(
                title: reason.label,
                selected: _reason == reason,
                onTap: () => setState(() => _reason = reason),
                divider: reason != widget.reasons.last,
              ),
          ],
        ),
        const SizedBox(height: 4),
        StudioUnderlineField(
          label: 'Details',
          hint: 'Add details (optional)',
          controller: _detailsController,
          maxLength: 1000,
          minLines: 1,
          maxLines: 4,
          valueSize: 15,
          errorText: _error,
        ),
        const SizedBox(height: 8),
        StudioButton(
          label: 'Send report',
          loading: _sending,
          onPressed: _reason == null || _sending ? null : _submit,
        ),
      ],
    );
  }
}

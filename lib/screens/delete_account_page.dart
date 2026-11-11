import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/user_service.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';

/// Delete account (`SettingsDelete`, Flow 12; Apple requires it). While anything is in
/// progress: "Finish these first", "Your account can be deleted once nothing is in progress.",
/// a row for each of the server's blockers (`/api/user/me/deletion-check`, B34: its message,
/// inert), what deleting removes, and Delete account grey at the bottom. Once nothing is:
/// Delete account in Ink, which asks them to type DELETE (and, as the server still requires,
/// their password; decision D8 keeps both).
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.debugCheck});

  /// For tests: the server's check, instead of loading it.
  @visibleForTesting
  final DeletionCheck? debugCheck;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  DeletionCheck _check = const DeletionCheck(canDelete: true);
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final given = widget.debugCheck;
    if (given != null) {
      _check = given;
      _loading = false;
      return;
    }
    _load();
  }

  /// Reads the server's check. If it can't be read, Delete stays on: the server still refuses
  /// while anything is in progress and says why.
  Future<void> _load() async {
    if (widget.debugCheck != null) return;
    DeletionCheck check;
    try {
      check = await UserService.instance.getDeletionCheck();
    } catch (_) {
      check = const DeletionCheck(canDelete: true);
    }
    if (!mounted) return;
    setState(() {
      _check = check;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final password = await showStudioSheet<String>(context: context, builder: (_) => const _ConfirmDeleteSheet());
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount(password);
      // Only once the account is gone: a refused delete keeps this phone's notifications.
      await DeviceService.instance.unregisterCurrentDevice();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on ApiException catch (e) {
      // A wrong password, or something in progress this page didn't see: the server says which.
      if (!mounted) return;
      setState(() => _deleting = false);
      showStudioToast(context, e.message, icon: null);
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showStudioToast(context, 'Could not delete your account. Please try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final blocked = !_check.canDelete;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Delete account'),
      body: _loading
          ? const SettingsListSkeleton()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    children: [
                      Text(
                        blocked ? 'Finish these first' : 'Delete your account?',
                        style: StudioType.sans(
                          24,
                          weight: StudioType.medium,
                          letterSpacing: -0.4,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        blocked
                            ? 'Your account can be deleted once nothing is in progress.'
                            : "Nothing is in progress, so your account can be deleted. This can't be undone.",
                        style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
                      ),
                      if (blocked) ...[
                        const SizedBox(height: 14),
                        for (final blocker in _check.blockers)
                          SettingsRow(label: blocker.message, chevron: false),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Removes your profile, pieces, Scenes and messages. Sale records are kept as '
                        'the law requires.',
                        style: StudioType.sans(13, height: 1.5, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: StudioButton(
                    label: 'Delete account',
                    loading: _deleting,
                    onPressed: blocked || _deleting ? null : _delete,
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Delete your account?", type DELETE, then the password (the server asks for it), Delete
/// account (on once both are in) and Cancel. Pops the password, or null.
class _ConfirmDeleteSheet extends StatefulWidget {
  const _ConfirmDeleteSheet();

  @override
  State<_ConfirmDeleteSheet> createState() => _ConfirmDeleteSheetState();
}

class _ConfirmDeleteSheetState extends State<_ConfirmDeleteSheet> {
  final _word = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _word.text.trim().toUpperCase() == 'DELETE' && _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Delete your account?', style: StudioType.title22(color: c.textPrimary)),
        Text('Type DELETE to confirm.', style: StudioType.body14(color: c.textSecondary)),
        StudioUnderlineField(
          label: 'Type DELETE',
          controller: _word,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        StudioUnderlineField(
          label: 'Your password',
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Delete account',
          onPressed: _ready ? () => Navigator.pop(context, _password.text) : null,
        ),
        StudioButton(label: 'Cancel', variant: StudioButtonVariant.text, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

/// Settings' Delete account row: the page above.
Future<void> openDeleteAccount(BuildContext context) =>
    Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const DeleteAccountPage()));

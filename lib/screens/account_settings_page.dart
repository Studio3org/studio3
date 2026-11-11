import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/user_service.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';

/// Account (`SettingsAccount`, Flow 12): Name, Email, Phone (Add when there is none), Password
/// (Change), and Log out of all devices (asks first); under them "Changing your email sends a
/// code to the new address first." Email and password open the existing pages; name and phone
/// change in a sheet.
///
/// Log out of all devices signs every other device out and keeps this phone signed in (B34): the
/// page stays and toasts the server's message. A password change by
/// emailed code (`NoteSettingsAccount`) waits on B30.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, this.debugProfile, this.debugLogoutAll});

  /// For tests: the account instead of loading it.
  @visibleForTesting
  final UserProfile? debugProfile;

  /// For tests: called instead of the server's log out of all devices; returns its message.
  @visibleForTesting
  final Future<String> Function()? debugLogoutAll;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  String _name = '';
  String _email = '';
  String? _phone;

  @override
  void initState() {
    super.initState();
    final given = widget.debugProfile;
    if (given != null) {
      _apply(given);
      return;
    }
    final user = AuthSession.instance.user;
    _name = user?.name ?? '';
    _email = user?.email ?? '';
    _load();
  }

  void _apply(UserProfile profile) {
    _name = profile.name;
    _email = profile.email ?? _email;
    _phone = profile.phone;
  }

  Future<void> _load() async {
    try {
      final profile = await UserService.instance.getMe();
      if (mounted) setState(() => _apply(profile));
    } catch (_) {
      // The session's name and email stay.
    }
  }

  /// One field in a sheet: [label], prefilled with [initial], Save on once it changed (and, if
  /// [required], isn't empty). Pops the new text, or null.
  Future<String?> _editField({
    required String title,
    required String label,
    required String initial,
    bool required = true,
    TextInputType? keyboard,
    List<String>? autofill,
    String? helper,
  }) {
    return showStudioSheet<String>(
      context: context,
      builder: (_) => _FieldSheet(
        title: title,
        label: label,
        initial: initial,
        required: required,
        keyboard: keyboard,
        autofill: autofill,
        helper: helper,
      ),
    );
  }

  Future<void> _editName() async {
    final next = await _editField(
      title: 'Name',
      label: 'Name',
      initial: _name,
      autofill: const [AutofillHints.name],
    );
    if (next == null || !mounted) return;
    try {
      final profile = await UserService.instance.updateMe(name: next);
      final user = AuthSession.instance.user;
      if (user != null) await AuthSession.instance.updateUser(user.copyWith(name: profile.name));
      if (!mounted) return;
      setState(() => _name = profile.name);
      showStudioToast(context, 'Name updated');
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save your name.', icon: null);
    }
  }

  Future<void> _editPhone() async {
    final next = await _editField(
      title: 'Phone',
      label: 'Phone',
      initial: _phone ?? '',
      required: false,
      keyboard: TextInputType.phone,
      autofill: const [AutofillHints.telephoneNumber],
      helper: 'Optional. Leave it empty to remove it.',
    );
    if (next == null || !mounted) return;
    try {
      final profile = await UserService.instance.updateMe(phone: next);
      if (!mounted) return;
      setState(() => _phone = profile.phone);
      showStudioToast(context, next.isEmpty ? 'Phone removed' : 'Phone updated');
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save your phone.', icon: null);
    }
  }

  Future<void> _openEmail() async {
    await Navigator.pushNamed(context, '/change-email');
    if (!mounted) return;
    final email = AuthSession.instance.user?.email;
    if (email != null && email.isNotEmpty) setState(() => _email = email);
  }

  Future<void> _logOutEverywhere() async {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Log out of all devices?',
      message: "You'll be signed out everywhere else you're logged in. This phone stays signed in.",
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    try {
      final message = await (widget.debugLogoutAll ?? AuthService.instance.logoutAllDevices)();
      if (mounted) showStudioToast(context, message);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not log out of your other devices.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final phone = _phone?.trim();
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          SettingsRow(label: 'Name', value: _name.isEmpty ? null : _name, onTap: _editName),
          SettingsRow(label: 'Email', value: _email.isEmpty ? null : _email, onTap: _openEmail),
          SettingsRow(
            label: 'Phone',
            value: phone == null || phone.isEmpty ? 'Add' : phone,
            onTap: _editPhone,
          ),
          SettingsRow(
            label: 'Password',
            value: 'Change',
            onTap: () => Navigator.pushNamed(context, '/change-password'),
          ),
          SettingsRow(label: 'Log out of all devices', chevron: false, onTap: _logOutEverywhere),
          const SizedBox(height: 14),
          Text(
            'Changing your email sends a code to the new address first.',
            style: StudioType.caption12(height: 1.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A title 22, one underline field, Save and Cancel (the sheets on the Settings pages).
class _FieldSheet extends StatefulWidget {
  const _FieldSheet({
    required this.title,
    required this.label,
    required this.initial,
    required this.required,
    this.keyboard,
    this.autofill,
    this.helper,
  });

  final String title;
  final String label;
  final String initial;
  final bool required;
  final TextInputType? keyboard;
  final List<String>? autofill;
  final String? helper;

  @override
  State<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends State<_FieldSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSave {
    final value = _text.text.trim();
    if (value == widget.initial.trim()) return false;
    return !widget.required || value.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        StudioUnderlineField(
          label: widget.label,
          controller: _text,
          autofocus: true,
          keyboardType: widget.keyboard,
          autofillHints: widget.autofill,
          helper: widget.helper,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Save',
          onPressed: _canSave ? () => Navigator.pop(context, _text.text.trim()) : null,
        ),
        StudioButton(label: 'Cancel', variant: StudioButtonVariant.text, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/auth_ui.dart' show AuthPillInput;
import '../widgets/studio/studio.dart';
import '../utils/auth_validators.dart';
import '../widgets/studio_loading.dart';

/// Authenticated password change, distinct from the unauthenticated
/// forgot/reset-password flow — reached from Settings > Password & security.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitted = false;
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? get _currentError {
    if (!_submitted) return null;
    if (_currentController.text.isEmpty) return 'Current password is required';
    return _serverError;
  }

  String? get _newError =>
      _submitted ? AuthValidators.password(_newController.text) : null;

  String? get _confirmError => _submitted
      ? AuthValidators.confirmPassword(_confirmController.text, _newController.text)
      : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_currentController.text.isEmpty ||
        AuthValidators.password(_newController.text) != null ||
        AuthValidators.confirmPassword(_confirmController.text, _newController.text) != null) {
      return;
    }
    setState(() => _loading = true);
    try {
      await UserService.instance.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      showStudioToast(context, 'Password updated. Your other devices were logged out.');
      Navigator.pop(context);
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      if (!mounted) return;
      setState(() => _serverError = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading,
      child: Scaffold(
        backgroundColor: context.studio.background,
        appBar: StudioTopBar(context: context, title: 'Change password'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40),
          children: [
            AuthPillInput(
              controller: _currentController,
              placeholder: 'Current password',
              obscureText: _obscureCurrent,
              onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
              errorText: _currentError,
            ),
            const SizedBox(height: 22),
            AuthPillInput(
              controller: _newController,
              placeholder: 'New password, at least 8 characters',
              obscureText: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              errorText: _newError,
            ),
            const SizedBox(height: 22),
            AuthPillInput(
              controller: _confirmController,
              placeholder: 'Confirm new password',
              obscureText: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
              errorText: _confirmError,
            ),
            const SizedBox(height: 32),
            StudioButton(label: 'Update password', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

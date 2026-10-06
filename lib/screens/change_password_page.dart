import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/pill_input.dart';
import '../widgets/primary_button.dart';
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Password updated. You have been logged out of your other devices.',
        ),
      ));
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
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            'Change password',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Current password'),
            const SizedBox(height: 6),
            PillInput(
              controller: _currentController,
              placeholder: 'Enter current password',
              obscureText: _obscureCurrent,
              onToggleVisibility: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              errorText: _currentError,
            ),
            const SizedBox(height: 20),
            _label('New password'),
            const SizedBox(height: 6),
            PillInput(
              controller: _newController,
              placeholder: 'At least 8 characters',
              obscureText: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              errorText: _newError,
            ),
            const SizedBox(height: 20),
            _label('Confirm new password'),
            const SizedBox(height: 6),
            PillInput(
              controller: _confirmController,
              placeholder: 'Re-enter new password',
              obscureText: _obscureConfirm,
              onToggleVisibility: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              errorText: _confirmError,
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Update password', onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
        ),
      );
}

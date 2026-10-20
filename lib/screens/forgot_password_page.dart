import 'package:flutter/material.dart';
import '../utils/auth_validators.dart';
import '../services/auth_service.dart';
import '../theme/auth_palette.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio_loading.dart';

enum _ForgotStep { email, sent, reset, done }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _ForgotStep _step = _ForgotStep.email;
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    setState(() => _submitted = true);
    if (AuthValidators.email(_emailController.text) != null) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.forgetPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _submitted = false;
        _step = _ForgotStep.sent;
      });
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _submitted = true);
    final token = _tokenController.text.trim();
    final passErr = AuthValidators.password(_newPasswordController.text);
    final confirmErr = AuthValidators.confirmPassword(
      _confirmPasswordController.text,
      _newPasswordController.text,
    );
    if (token.isEmpty || passErr != null || confirmErr != null) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.resetPassword(
        token: token,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _step = _ForgotStep.done);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading,
      dark: true,
      child: AuthScaffold(
        compact: true,
        showBackButton: true,
        child: AuthFormBody(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _ForgotStep.email => _buildEmailStep(key: const ValueKey('email')),
      _ForgotStep.sent => _buildSentStep(key: const ValueKey('sent')),
      _ForgotStep.reset => _buildResetStep(key: const ValueKey('reset')),
      _ForgotStep.done => _buildDoneStep(key: const ValueKey('done')),
    };
  }

  Widget _buildEmailStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthPageTitle(
          title: 'Forgot login?',
          subtitle: 'Enter your email and we\'ll send a reset link',
        ),
        const SizedBox(height: 24),
        AuthIconInput(
          controller: _emailController,
          placeholder: 'Email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          errorText: _submitted ? AuthValidators.email(_emailController.text) : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendResetLink(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Send reset link', onPressed: _sendResetLink),
      ],
    );
  }

  Widget _buildSentStep({required Key key}) {
    final c = context.authColors;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, color: c.textPrimary, size: 48),
        const SizedBox(height: 16),
        AuthPageTitle(
          title: 'Check your email',
          subtitle:
              'If an account exists for ${_emailController.text.trim()}, you\'ll receive a password reset link.',
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Enter reset token',
          onPressed: () => setState(() => _step = _ForgotStep.reset),
        ),
        const SizedBox(height: 10),
        AuthGhostButton(
          label: 'Back to login',
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ],
    );
  }

  Widget _buildResetStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthPageTitle(
          title: 'Reset password',
          subtitle: 'Paste the token from your reset email',
        ),
        const SizedBox(height: 24),
        AuthIconInput(
          controller: _tokenController,
          placeholder: 'Reset token',
          prefixIcon: Icons.key_outlined,
          errorText: _submitted && _tokenController.text.trim().isEmpty ? 'Token is required' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _newPasswordController,
          placeholder: 'New password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureNew,
          errorText: _submitted ? AuthValidators.password(_newPasswordController.text) : null,
          onChanged: (_) => setState(() {}),
          onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _confirmPasswordController,
          placeholder: 'Confirm new password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirm,
          errorText: _submitted
              ? AuthValidators.confirmPassword(_confirmPasswordController.text, _newPasswordController.text)
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
          onChanged: (_) => setState(() {}),
          onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Reset Password', onPressed: _resetPassword),
      ],
    );
  }

  Widget _buildDoneStep({required Key key}) {
    final c = context.authColors;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: c.success, size: 56),
        const SizedBox(height: 16),
        const AuthPageTitle(
          title: 'Password updated',
          subtitle: 'Your password has been reset. You can now sign in.',
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Back to Sign In',
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ],
    );
  }
}

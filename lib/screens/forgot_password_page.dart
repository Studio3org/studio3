import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/app_routes.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';

enum _ResetStep { email, sent, reset }

/// Forgot password, on the log-in boards' frame (`LoginReset`).
///
/// The board sends a 6-digit code to the code screen, then "Set a new password" with Save and
/// log in. The server emails a reset link instead (a code is BACKEND_CHANGES B30), so: from
/// Welcome back the email is sent straight away and "Check your email" says to open the link;
/// "Have a reset code?" opens Set a new password, where the code from the email goes above the
/// new password. Save and log in sets it and logs in, then the home feed.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.email});

  /// Known when it opens from Welcome back: the email is sent without asking again.
  final String? email;

  static Future<void> open(BuildContext context, {String? email}) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => ForgotPasswordPage(email: email)));

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late _ResetStep _step;
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final known = widget.email?.trim() ?? '';
    if (AuthValidators.email(known) == null) {
      _email.text = known;
      _step = _ResetStep.sent;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    } else {
      _step = _ResetStep.email;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _address => _email.text.trim();

  Future<void> _send() async {
    if (AuthValidators.email(_address) != null || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.forgetPassword(_address);
      if (!mounted) return;
      setState(() => _step = _ResetStep.sent);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canReset => _code.text.trim().isNotEmpty && AuthValidators.password(_password.text) == null;

  Future<void> _saveAndLogIn() async {
    if (!_canReset || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await AuthService.instance.resetPassword(token: _code.text.trim(), newPassword: _password.text);
      await AuthService.instance.login(identifier: _address, password: _password.text);
      await AuthSession.instance.saveRememberedLoginIdentifier(_address);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, resolvePostAuthRoute(), (_) => false);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (_step == _ResetStep.reset) {
      setState(() => _step = _ResetStep.sent);
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignInStepScaffold(
      bodyTop: 24,
      onBack: _back,
      bottom: switch (_step) {
        _ResetStep.email => AuthPrimaryButton(
          label: 'Send the email',
          enabled: AuthValidators.email(_address) == null,
          loading: _loading,
          onPressed: _send,
        ),
        _ResetStep.sent => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(label: 'Back to log in', onPressed: () => Navigator.maybePop(context)),
            const SizedBox(height: 4),
            _TextAction(label: 'Send it again', onTap: _loading ? null : _send),
          ],
        ),
        _ResetStep.reset => AuthPrimaryButton(
          label: 'Save and log in',
          enabled: _canReset,
          loading: _loading,
          onPressed: _saveAndLogIn,
        ),
      },
      body: switch (_step) {
        _ResetStep.email => _emailStep(),
        _ResetStep.sent => _sentStep(),
        _ResetStep.reset => _resetStep(),
      },
    );
  }

  Widget _heading(String title, String line) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: StudioType.sans(28, weight: StudioType.medium, letterSpacing: -0.5, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text(line, style: StudioType.sans(15, height: 1.5, color: c.textSecondary)),
      ],
    );
  }

  Widget _emailStep() {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Forgot your password?', "We'll email you a link to set a new one."),
        const SizedBox(height: 22),
        StudioUnderlineField(
          label: 'Email',
          controller: _email,
          hint: 'you@email.com',
          valueSize: 18,
          labelColor: c.textTertiary,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _sentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Check your email',
          'We sent a link to $_address. Open it to set a new password, then log in here.',
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: _TextAction(
            label: 'Have a reset code?',
            underline: true,
            onTap: () => setState(() => _step = _ResetStep.reset),
          ),
        ),
      ],
    );
  }

  Widget _resetStep() {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Set a new password', 'For $_address'),
        const SizedBox(height: 22),
        StudioUnderlineField(
          label: 'Reset code',
          controller: _code,
          hint: 'From the email',
          valueSize: 18,
          labelColor: c.textTertiary,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        StudioUnderlineField(
          label: 'New password',
          controller: _password,
          obscureText: _obscure,
          valueSize: 18,
          labelGap: 8,
          underlineGap: 10,
          labelColor: c.textTertiary,
          helper: 'At least 8 characters',
          helperColor: c.textTertiary,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveAndLogIn(),
          onChanged: (_) => setState(() {}),
          trailing: AuthEyeButton(obscured: _obscure, onPressed: () => setState(() => _obscure = !_obscure)),
        ),
      ],
    );
  }
}

/// A 14 text action with a 44 tall tap area: Ink and 500 ("Send it again"), or Graphite and
/// underlined ("Have a reset code?").
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.underline = false});

  final String label;
  final VoidCallback? onTap;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = underline
        ? StudioType.body14(color: c.textSecondary).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: c.textSecondary,
          )
        : StudioType.body14(weight: StudioType.medium, color: onTap == null ? c.textTertiary : c.textPrimary);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Center(widthFactor: 1, child: Text(label, style: style)),
      ),
    );
  }
}

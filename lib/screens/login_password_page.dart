import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/app_routes.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

/// Welcome back (`LoginPassword`): "Welcome back" 28/500, the email 15 Graphite, Password (dots,
/// the eye shows or hides it), "Forgot password?" 14 Graphite, then Log in at the bottom.
///
/// The board's "Email me a login code instead" and the 15-minute lock after five wrong
/// passwords need the server (BACKEND_CHANGES B30). Until then the line under Log in is
/// "New to Studio 3? Create an account", because the first screen can't yet tell a new email
/// from a known one.
class LoginPasswordPage extends StatefulWidget {
  const LoginPasswordPage({super.key, required this.email});

  final String email;

  static Future<void> open(BuildContext context, String email) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => LoginPasswordPage(email: email)));

  @override
  State<LoginPasswordPage> createState() => _LoginPasswordPageState();
}

class _LoginPasswordPageState extends State<LoginPasswordPage> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    if (_loading || _password.text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(identifier: widget.email, password: _password.text);
      await AuthSession.instance.saveRememberedLoginIdentifier(widget.email);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, resolvePostAuthRoute(), (_) => false);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createAccount() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SignUpPage(initialEmail: widget.email, startAtCode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SignInStepScaffold(
      bodyTop: 24,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Log in',
            enabled: _password.text.isNotEmpty,
            loading: _loading,
            onPressed: _logIn,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: StudioSize.tapTarget,
            child: Center(
              child: GestureDetector(
                onTap: _createAccount,
                behavior: HitTestBehavior.opaque,
                child: Text.rich(
                  TextSpan(
                    style: StudioType.body14(color: c.textSecondary),
                    children: [
                      const TextSpan(text: 'New to Studio 3? '),
                      TextSpan(
                        text: 'Create an account',
                        style: TextStyle(fontWeight: StudioType.medium, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: StudioType.sans(28, weight: StudioType.medium, letterSpacing: -0.5, color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(widget.email, style: StudioType.sans(15, color: c.textSecondary)),
          const SizedBox(height: 22),
          StudioUnderlineField(
            label: 'Password',
            controller: _password,
            obscureText: _obscure,
            valueSize: 18,
            labelGap: 8,
            underlineGap: 10,
            labelColor: c.textTertiary,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _logIn(),
            onChanged: (_) => setState(() {}),
            trailing: AuthEyeButton(obscured: _obscure, onPressed: () => setState(() => _obscure = !_obscure)),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => ForgotPasswordPage.open(context, email: widget.email),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    'Forgot password?',
                    style: StudioType.body14(color: c.textSecondary).copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

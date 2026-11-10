import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/app_routes.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';
import 'email_code_page.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

/// Welcome back (`LoginPassword`): "Welcome back" 28/500, the email 15 Graphite, Password (dots,
/// the eye shows or hides it), "Forgot password?" 14 Graphite, then Log in at the bottom.
///
/// For an email the server knows ([accountKnown], BACKEND_CHANGES B30) the line under Log in is
/// "Email me a login code instead", Forgot password? sends a reset code to the same code screen,
/// and after five wrong passwords the server stops password tries for 15 minutes: the field and
/// Log in turn off and only the code is offered. When the server couldn't say (one without the
/// check), the line is "New to Studio 3? Create an account" and the reset is by emailed link.
class LoginPasswordPage extends StatefulWidget {
  const LoginPasswordPage({super.key, required this.email, this.accountKnown = false});

  final String email;

  /// The server said this email has an account (B30).
  final bool accountKnown;

  static Future<void> open(BuildContext context, String email, {bool accountKnown = false}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => LoginPasswordPage(email: email, accountKnown: accountKnown)),
      );

  @override
  State<LoginPasswordPage> createState() => _LoginPasswordPageState();
}

class _LoginPasswordPageState extends State<LoginPasswordPage> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  /// The server's line after five wrong passwords (B30): password log-in is off for now.
  String? _lockedMessage;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    if (_loading || _password.text.isEmpty || _lockedMessage != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(identifier: widget.email, password: _password.text);
      await AuthSession.instance.saveRememberedLoginIdentifier(widget.email);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, resolvePostAuthRoute(), (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429 && widget.accountKnown && _isAccountLock(e)) {
        // Locked: only the emailed code from here (`NoteLoginPassword`).
        setState(() {
          _lockedMessage = e.message;
          _password.clear();
        });
      } else {
        showAuthError(context, e);
      }
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The five-wrong-passwords lock (B30), not the per-network limit ("Too many requests…",
  /// FRONTEND_HANDOFF 1.1), which also answers 429 but only means "wait a moment".
  static bool _isAccountLock(ApiException e) => e.message.toLowerCase().contains('wrong password');

  void _emailCode() => EmailCodePage.open(context, email: widget.email, purpose: EmailCodePurpose.login);

  void _forgotPassword() => widget.accountKnown
      ? EmailCodePage.open(context, email: widget.email, purpose: EmailCodePurpose.reset)
      : ForgotPasswordPage.open(context, email: widget.email);

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
            enabled: _password.text.isNotEmpty && _lockedMessage == null,
            loading: _loading,
            onPressed: _logIn,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: StudioSize.tapTarget,
            child: Center(
              child: StudioTapArea(
                child: GestureDetector(
                onTap: widget.accountKnown ? _emailCode : _createAccount,
                behavior: HitTestBehavior.opaque,
                child: widget.accountKnown
                    ? Text(
                        'Email me a login code instead',
                        style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                      )
                    : Text.rich(
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
            enabled: _lockedMessage == null,
            errorText: _lockedMessage,
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
              onTap: _forgotPassword,
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

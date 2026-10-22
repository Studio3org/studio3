import 'package:flutter/material.dart';

import '../utils/app_routes.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _submitted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final remembered = AuthSession.instance.rememberedLoginIdentifier;
    if (remembered != null) {
      _usernameController.text = remembered;
      _rememberMe = true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _usernameError => _submitted
      ? AuthValidators.loginIdentifier(_usernameController.text)
      : null;

  String? get _passwordError => _submitted && _passwordController.text.isEmpty
      ? 'Password is required'
      : null;

  bool get _canSubmit =>
      AuthValidators.loginIdentifier(_usernameController.text) == null &&
      _passwordController.text.isNotEmpty;

  Future<void> _signIn() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitted = true);
    if (!_canSubmit) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        identifier: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (_rememberMe) {
        await AuthSession.instance.saveRememberedLoginIdentifier(
          _usernameController.text.trim(),
        );
      } else {
        await AuthSession.instance.clearRememberedUsername();
      }
      if (!mounted) return;
      // Clear the whole stack: login may have been pushed on top of a guest
      // MainShell, which must not survive underneath the signed-in one.
      Navigator.pushNamedAndRemoveUntil(
        context,
        resolvePostAuthRoute(),
        (_) => false,
      );
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No login board exists. This is the first sign-in screen (`SignInFirst`),
    // with the fields and links this page already has.
    return SignInLaunchScaffold(
      showBackButton: Navigator.of(context).canPop(),
      form: AbsorbPointer(
        absorbing: _loading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthIconInput(
              controller: _usernameController,
              placeholder: 'Username or email',
              errorText: _usernameError,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AuthIconInput(
              controller: _passwordController,
              placeholder: 'Password',
              obscureText: _obscurePassword,
              errorText: _passwordError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              onChanged: (_) => setState(() {}),
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            AuthRememberRow(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v),
              onForgot: () => Navigator.pushNamed(context, '/forgot-password'),
            ),
            const SizedBox(height: 14),
            AuthPrimaryButton(
              label: 'Login',
              enabled: _canSubmit,
              loading: _loading,
              onPressed: _signIn,
            ),
            AuthLinkFooter(
              prompt: "Don't have an account? ",
              actionLabel: 'Sign Up',
              onTap: () => Navigator.pushNamed(context, '/signup'),
            ),
            const AuthGuestLink(label: 'Look around first'),
            const SizedBox(height: 14),
            const AuthLegalLine(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';
import 'login_password_page.dart';

/// The first screen (`SignInFirst` / `SignInFirstDark`): the haze, the large logo, and at the
/// bottom an Email field (placeholder you@email.com) and Continue, grey until the email is
/// valid. An account is required, so there is no "Look around first" and no legal line; the
/// Terms agreement happens in profile setup.
///
/// Continue should check the email: a new one goes to the code and profile steps, a known one
/// to Welcome back. The server can't say which yet (BACKEND_CHANGES B30), so Continue opens
/// Welcome back, which links to creating an account.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final remembered = AuthSession.instance.rememberedLoginIdentifier;
    if (remembered != null && AuthValidators.email(remembered) == null) {
      _emailController.text = remembered;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _valid => AuthValidators.email(_emailController.text) == null;

  void _continue() {
    if (!_valid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    LoginPasswordPage.open(context, _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SignInLaunchScaffold(
      showBackButton: Navigator.of(context).canPop(),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioUnderlineField(
            label: 'Email',
            controller: _emailController,
            hint: 'you@email.com',
            valueSize: 16,
            labelColor: c.textTertiary,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _continue(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          AuthPrimaryButton(label: 'Continue', enabled: _valid, onPressed: _continue),
        ],
      ),
    );
  }
}

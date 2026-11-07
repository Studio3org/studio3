import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/app_routes.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio_loading.dart';
import 'forgot_password_page.dart';

/// What an emailed code is for on [EmailCodePage].
enum EmailCodePurpose {
  /// "Email me a login code instead" (`NoteLoginPassword`): the code signs the account in.
  login,

  /// "Forgot password?" (`NoteLoginReset`): the code opens Set a new password.
  reset,
}

/// The code screen for an existing account (`SignIn2Code`, no progress bar: that is for new
/// accounts only), after "Email me a login code instead" or "Forgot password?" on Welcome back
/// (BACKEND_CHANGES B30). Sends the code on open; the sixth digit submits. A login code signs
/// in and opens the app; a reset code opens Set a new password. Wrong email? goes back.
class EmailCodePage extends StatefulWidget {
  const EmailCodePage({super.key, required this.email, required this.purpose});

  final String email;
  final EmailCodePurpose purpose;

  static Future<void> open(BuildContext context, {required String email, required EmailCodePurpose purpose}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => EmailCodePage(email: email, purpose: purpose)),
      );

  @override
  State<EmailCodePage> createState() => _EmailCodePageState();
}

class _EmailCodePageState extends State<EmailCodePage> {
  /// The same wait as sign-up's code step.
  static const _resendSeconds = 120;

  String _code = '';
  String? _error;
  bool _loading = false;
  int _cooldown = 0;
  Timer? _timer;

  String get _purpose => widget.purpose.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  Future<void> _send({bool again = false}) async {
    if (again) setState(() => _loading = true);
    try {
      if (again) {
        await AuthService.instance.resendOtp(widget.email, purpose: _purpose);
      } else {
        await AuthService.instance.generateOtp(widget.email, purpose: _purpose);
      }
      if (!mounted) return;
      setState(() {
        _code = '';
        _error = null;
      });
      _startCooldown();
      showAuthSnackBar(context, again ? 'Code resent' : 'Code sent to your email');
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted && again) setState(() => _loading = false);
    }
  }

  Future<void> _submit(String code) async {
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.purpose) {
        case EmailCodePurpose.login:
          await AuthService.instance.loginWithCode(widget.email, code);
          await AuthSession.instance.saveRememberedLoginIdentifier(widget.email);
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, resolvePostAuthRoute(), (_) => false);
        case EmailCodePurpose.reset:
          final token = await AuthService.instance.resetTokenFromCode(widget.email, code);
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ForgotPasswordPage(email: widget.email, resetToken: token),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Could not verify the code');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading,
      child: SignInStepScaffold(
        onBack: () => Navigator.maybePop(context),
        bottom: AuthPrimaryButton(
          label: 'Verify',
          enabled: _code.length == 6,
          loading: _loading,
          onPressed: () => _submit(_code),
        ),
        body: AuthCodeStepBody(
          email: widget.email,
          errorText: _error,
          onChanged: (v) => setState(() => _code = v),
          onCompleted: _submit,
          // Back to the email screen, where the address is typed.
          onWrongEmail: () => Navigator.of(context).popUntil((route) => route.isFirst),
          resendCooldown: _cooldown,
          onResend: _loading ? null : () => _send(again: true),
        ),
      ),
    );
  }
}

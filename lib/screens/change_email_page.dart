import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/ghost_button.dart';
import '../widgets/light_otp_input.dart';
import '../widgets/pill_input.dart';
import '../widgets/primary_button.dart';
import '../widgets/studio_loading.dart';

enum _Step { request, confirm }

/// Two-step authenticated email change (request OTP -> confirm) — reached
/// from Settings > Change email.
class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  _Step _step = _Step.request;
  bool _submitted = false;
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? get _emailError =>
      _submitted && _step == _Step.request
          ? AuthValidators.email(_emailController.text)
          : null;

  Future<void> _requestChange() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (AuthValidators.email(_emailController.text) != null) return;
    setState(() => _loading = true);
    try {
      await UserService.instance.requestEmailChange(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _Step.confirm;
        _submitted = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmChange() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_otpController.text.trim().length != 6) return;
    setState(() => _loading = true);
    try {
      final email = await UserService.instance.confirmEmailChange(
        newEmail: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Email updated to $email')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e is ApiException ? e.message : e.toString());
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
            'Change email',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == _Step.request ? _requestView() : _confirmView(),
          ),
        ),
      ),
    );
  }

  Widget _requestView() {
    return ListView(
      key: const ValueKey('request'),
      children: [
        _label('New email address'),
        const SizedBox(height: 6),
        PillInput(
          controller: _emailController,
          placeholder: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError ?? _serverError,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Send code', onPressed: _requestChange),
      ],
    );
  }

  Widget _confirmView() {
    return ListView(
      key: const ValueKey('confirm'),
      children: [
        Text(
          'Enter the 6-digit code we sent to ${_emailController.text.trim()}.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        LightOtpInput(controller: _otpController),
        if (_serverError != null) ...[
          const SizedBox(height: 8),
          Text(
            _serverError!,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE05252)),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(label: 'Confirm', onPressed: _confirmChange),
        const SizedBox(height: 12),
        GhostButton(label: 'Resend code', onPressed: _requestChange),
      ],
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

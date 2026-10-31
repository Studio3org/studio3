import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/auth_ui.dart' show AuthPillInput, StudioOtpSlots;
import '../widgets/studio/studio.dart';
import '../utils/auth_validators.dart';
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
      showStudioToast(context, 'Email updated to $email');
      Navigator.pop(context, true);
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
        backgroundColor: context.studio.background,
        appBar: StudioTopBar(context: context, title: 'Change email'),
        body: AnimatedSwitcher(
          duration: StudioMotion.quick,
          child: _step == _Step.request ? _requestView() : _confirmView(),
        ),
      ),
    );
  }

  static const _padding = EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40);

  Widget _requestView() {
    return ListView(
      key: const ValueKey('request'),
      padding: _padding,
      children: [
        AuthPillInput(
          controller: _emailController,
          placeholder: 'New email address',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError ?? _serverError,
        ),
        const SizedBox(height: 32),
        StudioButton(label: 'Send code', onPressed: _requestChange),
      ],
    );
  }

  Widget _confirmView() {
    final c = context.studio;
    final otpError = _submitted && _otpController.text.trim().length != 6 ? 'Enter the 6-digit code' : null;
    return ListView(
      key: const ValueKey('confirm'),
      padding: _padding,
      children: [
        Text(
          'Enter the 6-digit code we sent to ${_emailController.text.trim()}.',
          style: StudioType.body15(color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        StudioOtpSlots(controller: _otpController, autofocus: true, errorText: _serverError ?? otpError),
        const SizedBox(height: 32),
        StudioButton(label: 'Confirm', onPressed: _confirmChange),
        const SizedBox(height: 4),
        StudioButton(label: 'Resend code', variant: StudioButtonVariant.text, onPressed: _requestChange),
      ],
    );
  }
}

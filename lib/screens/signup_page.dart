import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio_loading.dart';

enum _SignUpStep {
  name,
  email,
  emailVerify,
  username,
  phone,
  password,
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  _SignUpStep _step = _SignUpStep.name;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitted = false;
  bool _loading = false;
  String _otp = '';
  String? _otpError;

  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _usernameApiMessage;
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounce;

  int _resendCooldown = 0;
  Timer? _resendCooldownTimer;
  static const _resendCooldownSeconds = 120;

  static const _formSteps = 6;

  int get _progressStep => switch (_step) {
        _SignUpStep.name => 1,
        _SignUpStep.email => 2,
        _SignUpStep.emailVerify => 3,
        _SignUpStep.username => 4,
        _SignUpStep.phone => 5,
        _SignUpStep.password => 6,
      };

  String get _fullName =>
      '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

  double get _passwordStrength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    var score = 0.0;
    if (p.length >= 8) score += 0.25;
    if (p.length >= 12) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) score += 0.2;
    if (RegExp(r'[a-z]').hasMatch(p)) score += 0.15;
    if (RegExp(r'[0-9]').hasMatch(p)) score += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p)) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _resendCooldownTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step == _SignUpStep.name) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _submitted = false;
      _loading = false;
      _step = switch (_step) {
        _SignUpStep.email => _SignUpStep.name,
        _SignUpStep.emailVerify => _SignUpStep.email,
        _SignUpStep.username => _SignUpStep.emailVerify,
        _SignUpStep.phone => _SignUpStep.username,
        _SignUpStep.password => _SignUpStep.phone,
        _SignUpStep.name => _SignUpStep.name,
      };
    });
  }

  String? _nameError() {
    if (!_submitted) return null;
    if (_firstNameController.text.trim().isEmpty) return 'First name is required';
    if (_lastNameController.text.trim().isEmpty) return 'Last name is required';
    return null;
  }

  Future<void> _continueName() async {
    setState(() => _submitted = true);
    if (_nameError() != null) return;
    setState(() {
      _submitted = false;
      _step = _SignUpStep.email;
    });
  }

  Future<void> _continueEmail() async {
    setState(() => _submitted = true);
    if (AuthValidators.email(_emailController.text) != null) return;

    // Navigate immediately rather than waiting on the network — sending
    // the code is inherently slow (backend cold start, SMTP delivery) and
    // the user shouldn't have to wait through that just to see the entry
    // screen. The actual send happens in the background; a failure is
    // surfaced via SnackBar once it resolves, with "Resend code" already
    // available on this next screen to retry.
    final email = _emailController.text.trim();
    setState(() {
      _submitted = false;
      _otp = '';
      _otpError = null;
      _step = _SignUpStep.emailVerify;
    });

    try {
      await AuthService.instance.generateOtp(email);
      if (!mounted) return;
      _startResendCooldown();
      showAuthSnackBar(context, 'Verification code sent to your email');
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String _formatCooldown(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _resendOtp() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.resendOtp(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _otp = '';
          _otpError = null;
        });
        _startResendCooldown();
        showAuthSnackBar(context, 'Verification code resent');
      }
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueOtp(String code) async {
    if (code.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit code');
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _otpError = null;
    });
    try {
      await AuthService.instance.verifyOtp(_emailController.text.trim(), code);
      if (!mounted) return;
      setState(() {
        _otp = code;
        _step = _SignUpStep.username;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not verify the code';
      setState(() => _otpError = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onUsernameChanged(String value) {
    setState(() {
      _usernameAvailable = null;
      _usernameApiMessage = null;
      _usernameSuggestions = [];
    });
    _usernameDebounce?.cancel();
    final localError = AuthValidators.username(value);
    if (localError != null || value.trim().length < 3) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _checkingUsername = true);
      try {
        final result = await AuthService.instance.checkUsername(value);
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = result.available;
          _usernameApiMessage = result.message;
          _usernameSuggestions = result.suggestions;
        });
      } catch (e) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _continueUsername() async {
    setState(() => _submitted = true);
    if (AuthValidators.username(_usernameController.text) != null) return;

    setState(() => _loading = true);
    try {
      final result = await AuthService.instance.checkUsername(_usernameController.text);
      if (!result.available) {
        setState(() {
          _usernameAvailable = false;
          _usernameApiMessage = result.message ?? 'Username is not available';
          _usernameSuggestions = result.suggestions;
        });
        return;
      }
      setState(() {
        _submitted = false;
        _step = _SignUpStep.phone;
      });
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continuePhone({bool skip = false}) {
    if (!skip) {
      setState(() => _submitted = true);
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty && AuthValidators.phone(phone) != null) return;
    }
    setState(() {
      _submitted = false;
      _step = _SignUpStep.password;
    });
  }

  Future<void> _createAccount() async {
    setState(() => _submitted = true);
    final passErr = AuthValidators.password(_passwordController.text);
    final confirmErr = AuthValidators.confirmPassword(
      _confirmPasswordController.text,
      _passwordController.text,
    );
    if (passErr != null || confirmErr != null) return;

    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.register(
        username: _usernameController.text.trim(),
        name: _fullName,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        otp: _otp,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome', arguments: user);
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
        onBackPressed: _goBack,
        child: Column(
        children: [
          AuthFormBody(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: _buildStep(),
            ),
          ),
          if (_step == _SignUpStep.name) ...[
            const SizedBox(height: 24),
            AuthLinkFooter(
              prompt: 'Already have an account? ',
              actionLabel: 'Sign in',
              onTap: () => Navigator.pushNamed(context, '/login'),
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _SignUpStep.name => _buildNameStep(key: const ValueKey('name')),
      _SignUpStep.email => _buildEmailStep(key: const ValueKey('email')),
      _SignUpStep.emailVerify => _buildOtpStep(key: const ValueKey('otp')),
      _SignUpStep.username => _buildUsernameStep(key: const ValueKey('username')),
      _SignUpStep.phone => _buildPhoneStep(key: const ValueKey('phone')),
      _SignUpStep.password => _buildPasswordStep(key: const ValueKey('password')),
    };
  }

  Widget _buildNameStep({required Key key}) {
    return _stepBody(
      key: key,
      title: 'Your name',
      subtitle: 'How should we address you?',
      children: [
        AuthIconInput(
          controller: _firstNameController,
          placeholder: 'First name',
          prefixIcon: Icons.badge_outlined,
          errorText: _submitted && _firstNameController.text.trim().isEmpty ? 'First name is required' : null,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _lastNameController,
          placeholder: 'Last name',
          prefixIcon: Icons.badge_outlined,
          errorText: _submitted && _lastNameController.text.trim().isEmpty ? 'Last name is required' : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueName(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Continue',
          enabled: _firstNameController.text.trim().isNotEmpty && _lastNameController.text.trim().isNotEmpty,
          onPressed: _continueName,
        ),
      ],
    );
  }

  Widget _buildEmailStep({required Key key}) {
    return _stepBody(
      key: key,
      title: 'Your email',
      subtitle: 'We\'ll send a verification code',
      children: [
        AuthIconInput(
          controller: _emailController,
          placeholder: 'Email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          errorText: _submitted ? AuthValidators.email(_emailController.text) : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueEmail(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Send code',
          enabled: AuthValidators.email(_emailController.text) == null,
          loading: _loading,
          onPressed: _continueEmail,
        ),
      ],
    );
  }

  Widget _buildOtpStep({required Key key}) {
    return _stepBody(
      key: key,
      title: 'Verify email',
      subtitle: 'Enter the 6-digit code sent to ${_emailController.text.trim()}',
      children: [
        AuthOtpInput(
          errorText: _otpError,
          onChanged: (v) => setState(() => _otp = v),
          onCompleted: _continueOtp,
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Verify',
          enabled: _otp.length == 6,
          loading: _loading,
          onPressed: () => _continueOtp(_otp),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: (_loading || _resendCooldown > 0) ? null : _resendOtp,
              child: Text(
                'Resend code',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _resendCooldown > 0
                      ? AuthColors.textMuted.withValues(alpha: 0.5)
                      : AuthColors.textMuted,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (_resendCooldown > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(${_formatCooldown(_resendCooldown)})',
                style: GoogleFonts.inter(fontSize: 13, color: AuthColors.textMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUsernameStep({required Key key}) {
    final localValid = AuthValidators.username(_usernameController.text) == null;
    return _stepBody(
      key: key,
      title: 'Pick a username',
      subtitle: 'This is how others will find you',
      children: [
        AuthIconInput(
          controller: _usernameController,
          placeholder: 'Username',
          prefixIcon: Icons.alternate_email_rounded,
          errorText: _submitted ? AuthValidators.username(_usernameController.text) : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueUsername(),
          onChanged: _onUsernameChanged,
        ),
        if (_checkingUsername)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Checking availability…', style: GoogleFonts.inter(fontSize: 12, color: AuthColors.textDim)),
          )
        else if (_usernameAvailable == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _usernameApiMessage ?? 'Username is available',
              style: GoogleFonts.inter(fontSize: 12, color: AuthColors.success),
            ),
          )
        else if (_usernameAvailable == false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _usernameApiMessage ?? 'Username is taken',
              style: GoogleFonts.inter(fontSize: 12, color: AuthColors.error),
            ),
          ),
        if (_usernameSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _usernameSuggestions.map((s) {
              return ActionChip(
                label: Text(s, style: GoogleFonts.inter(fontSize: 12, color: AuthColors.textPrimary)),
                backgroundColor: AuthColors.surfaceElevated,
                side: BorderSide(color: AuthColors.border),
                onPressed: () {
                  _usernameController.text = s;
                  _onUsernameChanged(s);
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Continue',
          enabled: localValid && _usernameAvailable != false,
          loading: false,
          onPressed: _continueUsername,
        ),
      ],
    );
  }

  Widget _buildPhoneStep({required Key key}) {
    return _stepBody(
      key: key,
      title: 'Phone number',
      subtitle: 'Optional — for account recovery',
      children: [
        AuthIconInput(
          controller: _phoneController,
          placeholder: 'Phone number (optional)',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _submitted && _phoneController.text.trim().isNotEmpty
              ? AuthValidators.phone(_phoneController.text)
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continuePhone(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Continue', onPressed: () => _continuePhone()),
        const SizedBox(height: 10),
        AuthGhostButton(label: 'Skip for now', onPressed: () => _continuePhone(skip: true)),
      ],
    );
  }

  Widget _buildPasswordStep({required Key key}) {
    return _stepBody(
      key: key,
      title: 'Set password',
      subtitle: 'Create a strong password for your account',
      children: [
        AuthIconInput(
          controller: _passwordController,
          placeholder: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          errorText: _submitted ? AuthValidators.password(_passwordController.text) : null,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _passwordStrength,
              minHeight: 3,
              backgroundColor: AuthColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                _passwordStrength < 0.4
                    ? AuthColors.error
                    : _passwordStrength < 0.7
                        ? const Color(0xFFFFB347)
                        : AuthColors.success,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _confirmPasswordController,
          placeholder: 'Confirm password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirm,
          errorText: _submitted
              ? AuthValidators.confirmPassword(_confirmPasswordController.text, _passwordController.text)
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createAccount(),
          onChanged: (_) => setState(() {}),
          onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Create Account',
          enabled: AuthValidators.password(_passwordController.text) == null &&
              AuthValidators.confirmPassword(_confirmPasswordController.text, _passwordController.text) == null,
          loading: false,
          onPressed: _createAccount,
        ),
      ],
    );
  }

  Widget _stepBody({
    required Key key,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_progressStep > 0) ...[
          AuthStepProgress(current: _progressStep, total: _formSteps),
          const SizedBox(height: 24),
        ],
        AuthPageTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

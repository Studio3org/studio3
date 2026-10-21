import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';
import '../widgets/studio_loading.dart';
import 'terms_page.dart';

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

  bool _agreedToTerms =
      AuthSession.instance.termsAgreedOnDevice == kTermsVersion;
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
    if (_nameError() != null || !_agreedToTerms) return;
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
      await AuthSession.instance.saveTermsAgreedOnDevice(kTermsVersion);
      if (!mounted) return;
      // Clear the whole stack so a guest MainShell that pushed login/sign-up
      // doesn't survive underneath the new account's shell.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/welcome',
        (_) => false,
        arguments: user,
      );
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _buildStep();
    if (_step == _SignUpStep.name) {
      return StudioLoadingGate(
        loading: _loading,
        child: SignInLaunchScaffold(
          showBackButton: true,
          onBackPressed: _goBack,
          form: step,
        ),
      );
    }
    final progress = switch (_step) {
      _SignUpStep.emailVerify => 1,
      _SignUpStep.username || _SignUpStep.phone => 2,
      _ => null,
    };
    return StudioLoadingGate(
      loading: _loading,
      child: SignInStepScaffold(
        onBack: _goBack,
        progressCurrent: progress,
        bottom: _stepBottom(),
        body: step,
      ),
    );
  }

  Widget? _stepBottom() {
    return switch (_step) {
      _SignUpStep.emailVerify => AuthPrimaryButton(
          label: 'Verify',
          enabled: _otp.length == 6,
          loading: _loading,
          onPressed: () => _continueOtp(_otp),
        ),
      _SignUpStep.username => AuthPrimaryButton(
          label: 'Continue',
          enabled: AuthValidators.username(_usernameController.text) == null &&
              _usernameAvailable != false,
          onPressed: _continueUsername,
        ),
      _SignUpStep.phone => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(label: 'Continue', onPressed: () => _continuePhone()),
            const SizedBox(height: 4),
            AuthGhostButton(label: 'Skip for now', onPressed: () => _continuePhone(skip: true)),
          ],
        ),
      _SignUpStep.password => AuthPrimaryButton(
          label: 'Create Account',
          enabled: AuthValidators.password(_passwordController.text) == null &&
              AuthValidators.confirmPassword(
                    _confirmPasswordController.text,
                    _passwordController.text,
                  ) ==
                  null,
          onPressed: _createAccount,
        ),
      _ => null,
    };
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
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthPageTitle(title: 'Your name', subtitle: 'How should we address you?'),
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _firstNameController,
          placeholder: 'First name',
          errorText: _submitted && _firstNameController.text.trim().isEmpty ? 'First name is required' : null,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _lastNameController,
          placeholder: 'Last name',
          errorText: _submitted && _lastNameController.text.trim().isEmpty ? 'Last name is required' : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueName(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthTermsCheckbox(
          value: _agreedToTerms,
          showError: _submitted,
          onChanged: (v) => setState(() => _agreedToTerms = v),
        ),
        const SizedBox(height: 14),
        AuthPrimaryButton(
          label: 'Continue',
          enabled: _firstNameController.text.trim().isNotEmpty &&
              _lastNameController.text.trim().isNotEmpty &&
              _agreedToTerms,
          onPressed: _continueName,
        ),
        AuthLinkFooter(
          prompt: 'Already have an account? ',
          actionLabel: 'Sign in',
          onTap: () => Navigator.pushNamed(context, '/login'),
        ),
        const AuthGuestLink(),
        const SizedBox(height: 14),
        const AuthLegalLine(),
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
    final c = context.studio;
    final email = _emailController.text.trim();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter your code', style: StudioType.title32(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: StudioType.body16(color: c.textSecondary),
            children: [
              TextSpan(text: 'We sent it to $email. '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: _goBack,
                  child: Text(
                    'Wrong email?',
                    style: StudioType.body16(color: c.textPrimary).copyWith(fontWeight: StudioType.medium),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        AuthOtpInput(
          errorText: _otpError,
          onChanged: (v) => setState(() => _otp = v),
          onCompleted: _continueOtp,
        ),
        const SizedBox(height: 48),
        if (_resendCooldown > 0)
          Text.rich(
            TextSpan(
              style: StudioType.body14(color: c.textSecondary),
              children: [
                const TextSpan(text: "Didn't get it? You can resend in "),
                TextSpan(
                  text: _formatCooldown(_resendCooldown),
                  style: StudioType.mono13(color: c.textPrimary),
                ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loading ? null : _resendOtp,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Resend code',
                style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          "Check your inbox and spam folder. On iPhone the code can fill in straight from Mail, and we'll keep going as soon as it's in.",
          style: StudioType.label13(color: c.textPlaceholder).copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _buildUsernameStep({required Key key}) {
    final c = context.studio;
    final taken = _usernameAvailable == false;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set up your profile', style: StudioType.title32(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text(
          "How you'll show up when you save or share work.",
          style: StudioType.body16(color: c.textSecondary),
        ),
        const SizedBox(height: 40),
        StudioUnderlineField(
          label: 'Username',
          controller: _usernameController,
          valueSize: 19,
          labelGap: 8,
          underlineGap: 10,
          labelColor: c.textTertiary,
          errorText: taken
              ? (_usernameApiMessage ?? 'Username is taken')
              : (_submitted ? AuthValidators.username(_usernameController.text) : null),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueUsername(),
          onChanged: _onUsernameChanged,
          trailing: _usernameAvailable == true
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StudioIcon(StudioIcons.check, size: 14, color: c.textPrimary),
                    const SizedBox(width: 4),
                    Text('available', style: StudioType.mono(12, color: c.textPrimary)),
                  ],
                )
              : null,
          helper: _checkingUsername ? 'Checking availability…' : null,
        ),
        if (_usernameSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _usernameSuggestions)
                StudioChip(
                  label: s,
                  selected: false,
                  onTap: () {
                    _usernameController.text = s;
                    _onUsernameChanged(s);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneStep({required Key key}) {
    final c = context.studio;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set up your profile', style: StudioType.title32(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text(
          'For shipping and delivery updates. You can add it later.',
          style: StudioType.body16(color: c.textSecondary),
        ),
        const SizedBox(height: 40),
        StudioUnderlineField(
          label: 'Phone',
          controller: _phoneController,
          mono: true,
          valueSize: 18,
          labelGap: 8,
          underlineGap: 10,
          labelColor: c.textTertiary,
          labelTrailing: Text(' · optional', style: StudioType.label13(color: c.textPlaceholder)),
          hint: '(000) 000-0000',
          helper: 'For shipping and delivery updates. You can add it later.',
          keyboardType: TextInputType.phone,
          errorText: _submitted && _phoneController.text.trim().isNotEmpty
              ? AuthValidators.phone(_phoneController.text)
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continuePhone(),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildPasswordStep({required Key key}) {
    final c = context.studio;
    final strength = _passwordStrength;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthPageTitle(
          title: 'Set password',
          subtitle: 'Create a strong password for your account',
        ),
        const SizedBox(height: 28),
        AuthIconInput(
          controller: _passwordController,
          placeholder: 'Password',
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
              value: strength,
              minHeight: 3,
              backgroundColor: c.line,
              color: strength < 0.4
                  ? c.alert
                  : strength < 0.7
                      ? c.textSecondary
                      : c.positive,
            ),
          ),
        ],
        const SizedBox(height: 14),
        AuthIconInput(
          controller: _confirmPasswordController,
          placeholder: 'Confirm password',
          obscureText: _obscureConfirm,
          errorText: _submitted
              ? AuthValidators.confirmPassword(_confirmPasswordController.text, _passwordController.text)
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createAccount(),
          onChanged: (_) => setState(() {}),
          onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
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
        AuthPageTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

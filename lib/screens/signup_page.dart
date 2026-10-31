import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_ui.dart';
import '../widgets/studio/studio.dart';
import '../widgets/studio_loading.dart';
import 'terms_page.dart';

/// Choices collected on the profile screen that register does not accept: the photo path,
/// uploaded once the account exists. (Marketing texts are not asked here: `NoteSignIn3Profile`
/// puts text preferences in notification settings.)
class SignupExtras {
  static String? photoPath;
  static bool marketingTexts = false;
}

enum _SignUpStep {
  email,
  emailVerify,
  profile,
}

/// Sign-up for a new email (Flow 1): the code (`SignIn2Code`), then profile setup
/// (`SignIn3Profile`: photo, name, username, password, phone, the Terms and Privacy box and
/// Continue, which creates the account). The email step is only for a direct `/signup`; from
/// Welcome back the email is known and it starts at the code.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, this.initialStepIndex = 0, this.initialEmail, this.startAtCode = false});

  /// 0 email, 1 code, 2 profile.
  final int initialStepIndex;

  /// The email already entered on the first screen.
  final String? initialEmail;

  /// Send the code to [initialEmail] straight away and open on the code step.
  final bool startAtCode;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  late _SignUpStep _step;

  @override
  void initState() {
    super.initState();
    _step = _SignUpStep.values[widget.initialStepIndex.clamp(0, _SignUpStep.values.length - 1)];
    final email = widget.initialEmail?.trim();
    if (email != null && email.isNotEmpty) _emailController.text = email;
    if (widget.startAtCode && AuthValidators.email(_emailController.text) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _continueEmail());
    }
  }
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Unticked until they tick it (`NoteSignIn3Profile`: its own action, nothing bundled).
  bool _agreedToTerms = false;
  bool _obscurePassword = true;
  bool _submitted = false;
  bool _loading = false;
  String _otp = '';
  String? _otpError;

  String? _photoPath;
  final _picker = ImagePicker();

  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _usernameApiMessage;
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounce;

  int _resendCooldown = 0;
  Timer? _resendCooldownTimer;
  static const _resendCooldownSeconds = 120;

  String get _fullName => _nameController.text.trim();

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _resendCooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goBack() {
    // Started from Welcome back: back from the code returns there, not to an email step.
    if (_step == _SignUpStep.email || (widget.startAtCode && _step == _SignUpStep.emailVerify)) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _submitted = false;
      _loading = false;
      _step = switch (_step) {
        _SignUpStep.emailVerify => _SignUpStep.email,
        _SignUpStep.profile => _SignUpStep.emailVerify,
        _SignUpStep.email => _SignUpStep.email,
      };
    });
  }

  String? _nameError() {
    if (!_submitted) return null;
    if (_nameController.text.trim().isEmpty) return 'Name is required';
    return null;
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
        _step = _SignUpStep.profile;
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

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() => _photoPath = picked.path);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  bool get _profileReady =>
      _nameController.text.trim().isNotEmpty &&
      AuthValidators.username(_usernameController.text) == null &&
      _usernameAvailable != false &&
      AuthValidators.password(_passwordController.text) == null &&
      (_phoneController.text.trim().isEmpty || AuthValidators.phone(_phoneController.text) == null) &&
      _agreedToTerms;

  /// Continue on profile setup: the username is checked once more, then the account is made.
  Future<void> _continueProfile() async {
    setState(() => _submitted = true);
    if (_nameError() != null) return;
    if (AuthValidators.username(_usernameController.text) != null) return;
    if (AuthValidators.password(_passwordController.text) != null || !_agreedToTerms) return;
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && AuthValidators.phone(phone) != null) return;

    setState(() => _loading = true);
    try {
      final result = await AuthService.instance.checkUsername(_usernameController.text);
      if (!result.available) {
        setState(() {
          _loading = false;
          _usernameAvailable = false;
          _usernameApiMessage = result.message ?? 'Username is not available';
          _usernameSuggestions = result.suggestions;
        });
        return;
      }
    } catch (e) {
      if (mounted) showAuthError(context, e);
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _createAccount();
  }

  Future<void> _createAccount() async {
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
      SignupExtras.photoPath = _photoPath;
      SignupExtras.marketingTexts = false;
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
    if (_step == _SignUpStep.email) {
      return StudioLoadingGate(
        loading: _loading,
        child: SignInLaunchScaffold(
          showBackButton: true,
          onBackPressed: _goBack,
          form: _buildEmailStep(key: const ValueKey('email')),
        ),
      );
    }
    final step = _buildStep();
    final progress = switch (_step) {
      _SignUpStep.emailVerify => 1,
      _SignUpStep.profile => 2,
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
      _SignUpStep.profile => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTermsCheckbox(
              value: _agreedToTerms,
              showError: _submitted,
              onChanged: (v) => setState(() => _agreedToTerms = v),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Continue',
              enabled: _profileReady,
              loading: _loading,
              onPressed: _continueProfile,
            ),
          ],
        ),
      _ => null,
    };
  }

  Widget _buildStep() {
    return switch (_step) {
      _SignUpStep.emailVerify => _buildOtpStep(key: const ValueKey('otp')),
      _SignUpStep.profile => _buildProfileStep(key: const ValueKey('profile')),
      _SignUpStep.email => const SizedBox.shrink(),
    };
  }

  Widget _buildEmailStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioUnderlineField(
          label: 'Email',
          controller: _emailController,
          hint: 'you@email.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _submitted ? AuthValidators.email(_emailController.text) : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueEmail(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthPrimaryButton(
          label: 'Continue',
          enabled: AuthValidators.email(_emailController.text) == null,
          loading: _loading,
          onPressed: _continueEmail,
        ),
        AuthLinkFooter(
          prompt: 'Already have an account? ',
          actionLabel: 'Log in',
          onTap: () => Navigator.pushNamed(context, '/login'),
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

  Widget _buildProfileStep({required Key key}) {
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
        GestureDetector(
          onTap: _pickPhoto,
          child: Row(
            children: [
              _photoPath == null
                  ? Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: StudioIcon(StudioIcons.post, size: 26, color: c.textTertiary),
                    )
                  : ClipOval(
                      child: Image.file(
                        File(_photoPath!),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _photoPath == null ? 'Add a photo' : 'Profile photo added',
                    style: StudioType.body15(color: c.textPrimary).copyWith(fontWeight: StudioType.medium),
                  ),
                  const SizedBox(height: 2),
                  Text('Optional', style: StudioType.label13(color: c.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        StudioUnderlineField(
          label: 'Name',
          controller: _nameController,
          valueSize: 20,
          labelGap: 8,
          underlineGap: 10,
          labelColor: c.textTertiary,
          errorText: _submitted ? _nameError() : null,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 28),
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
          textInputAction: TextInputAction.next,
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
        const SizedBox(height: 28),
        StudioUnderlineField(
          label: 'Password',
          controller: _passwordController,
          obscureText: _obscurePassword,
          hint: 'At least 8 characters',
          valueSize: 19,
          labelGap: 8,
          underlineGap: 10,
          labelColor: c.textTertiary,
          errorText: _submitted ? AuthValidators.password(_passwordController.text) : null,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          trailing: AuthEyeButton(
            obscured: _obscurePassword,
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 28),
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
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

}

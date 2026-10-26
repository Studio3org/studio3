import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../theme/auth_palette.dart';
import 'studio/studio.dart';

/// Thin wrapper so auth screens use the brand's Geist family with an honest
/// system fallback — matches every `.dc.html` sign-in screen in the design
/// handoff, which sets `font-family: 'Geist', ... sans-serif` throughout.
TextStyle geistText({
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  try {
    return GoogleFonts.getFont(
      'Geist',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  } catch (_) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
}

/// Geist Mono — used only for the OTP digits, matching the design's
/// `font-family: 'Geist Mono', ui-monospace, Menlo, monospace`.
TextStyle geistMono({
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) {
  try {
    return GoogleFonts.getFont(
      'Geist Mono',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  } catch (_) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// Black/grey background with sweeping curved lines (reference-inspired).
/// Deliberately NOT theme-aware — this is the immersive "login in progress"
/// loader (`StudioLoginLoadingOverlay`), always forced dark regardless of
/// the device's light/dark setting, so it keeps its own literal colors.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF121212),
                Color(0xFF0A0A0A),
                Color(0xFF000000),
                Color(0xFF1A1A1A),
              ],
              stops: [0.0, 0.3, 0.65, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _AuthCurvePainter()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawCurve({
      required Color color,
      required double stroke,
      required Path path,
    }) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final curve1 = Path()
      ..moveTo(-w * 0.1, h * 0.15)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w * 1.1, h * 0.35)
      ..quadraticBezierTo(w * 0.7, h * 0.55, w * 1.2, h * 0.75);
    drawCurve(color: const Color(0xFF2E2E2E), stroke: 1.2, path: curve1);

    final curve2 = Path()
      ..moveTo(-w * 0.05, h * 0.45)
      ..quadraticBezierTo(w * 0.4, h * 0.3, w * 0.95, h * 0.5)
      ..quadraticBezierTo(w * 0.55, h * 0.7, w * 1.15, h * 0.6);
    drawCurve(color: const Color(0xFF3A3A3A).withValues(alpha: 0.7), stroke: 0.8, path: curve2);

    final curve3 = Path()
      ..moveTo(w * 0.1, h * 0.85)
      ..quadraticBezierTo(w * 0.55, h * 0.65, w * 1.0, h * 0.9);
    drawCurve(color: const Color(0xFF252525), stroke: 1.0, path: curve3);

    canvas.drawCircle(
      Offset(w * 0.85, h * 0.12),
      w * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF404040).withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.85, h * 0.12), radius: w * 0.35)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
    this.compact = false,
    this.showLogo = true,
  });

  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool compact;

  /// Hide the logo mark — matches the design, where the brand mark only
  /// appears on the very first sign-in screen; deeper steps (code, profile,
  /// intention) show only the back button and progress bar.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final showBack = showBackButton || onBackPressed != null;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (showLogo) const StudioLogo.mark(markWidth: 76),
                          if (showBack)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _AuthBackButton(
                                onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      Text(
                        'Discover art and the people who make it.',
                        textAlign: TextAlign.center,
                        style: StudioType.label13(color: c.textSecondary),
                      ),
                      const SizedBox(height: 28),
                    ] else
                      SizedBox(height: showLogo ? 28 : 12),
                    child,
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthFormBody extends StatelessWidget {
  const AuthFormBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child],
    );
  }
}

class AuthPageTitle extends StatelessWidget {
  const AuthPageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: StudioType.title32(color: c.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: StudioType.body16(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// Back-compat alias.
typedef AuthModalTitle = AuthPageTitle;

class AuthIconInput extends StatelessWidget {
  const AuthIconInput({
    super.key,
    this.controller,
    this.placeholder,
    this.prefixIcon, // ignored: underline fields have no leading icon
    this.obscureText = false,
    this.onChanged,
    this.onToggleVisibility,
    this.keyboardType,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final IconData? prefixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    // [prefixIcon] stays on the constructor for existing call sites. Underline
    // fields on the boards have no leading icon.
    assert(prefixIcon == null || prefixIcon is IconData);
    return StudioUnderlineField(
      label: placeholder ?? '',
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      errorText: errorText,
      valueSize: 16,
      labelColor: c.textTertiary,
      trailing: onToggleVisibility == null
          ? null
          : _ShowHide(
              obscured: obscureText,
              onPressed: onToggleVisibility!,
            ),
    );
  }
}

/// Back-compat alias used by signup/forgot flows.
typedef AuthPillInput = AuthIconInput;

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return StudioButton(
      label: label,
      loading: loading,
      onPressed: enabled && !loading ? onPressed : null,
    );
  }
}

/// A plain text link, no border — matches the design's "Look around first" /
/// "Skip for now" treatment. Kept at the same height as [AuthPrimaryButton]
/// so call sites that stack the two don't need to change spacing.
class AuthGhostButton extends StatelessWidget {
  const AuthGhostButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return StudioButton(
      label: label,
      variant: StudioButtonVariant.text,
      onPressed: onPressed,
    );
  }
}

class AuthRememberRow extends StatelessWidget {
  const AuthRememberRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.onForgot,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onForgot;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SizedBox(
      height: StudioSize.tapTarget,
      child: Row(
        children: [
        SizedBox(
          width: StudioSize.tapTarget,
          height: StudioSize.tapTarget,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Center(
              child: IgnorePointer(
                child: Checkbox(
                  value: value,
                  onChanged: (_) {},
                  activeColor: c.textPrimary,
                  checkColor: c.background,
                  side: BorderSide(color: c.lineStrong),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Text(
                'Remember me',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.caption12(color: c.textSecondary),
              ),
            ),
          ),
          if (onForgot != null)
            TextButton(
              onPressed: onForgot,
              style: TextButton.styleFrom(
                foregroundColor: c.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot login?',
                style: StudioType.caption12(color: c.textPrimary).copyWith(fontWeight: StudioType.medium),
              ),
            ),
        ],
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.authColors;
    return Row(
      children: [
        Expanded(child: Divider(color: c.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: geistText(fontSize: 12, color: c.textDim)),
        ),
        Expanded(child: Divider(color: c.border)),
      ],
    );
  }
}

class AuthLinkFooter extends StatelessWidget {
  const AuthLinkFooter({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Center(
          child: Text.rich(
            TextSpan(
              style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
              children: [
                TextSpan(text: prompt),
                TextSpan(
                  text: actionLabel,
                  style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class AuthStepProgress extends StatelessWidget {
  const AuthStepProgress({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.authColors;
    return Column(
      children: [
        Row(
          children: List.generate(total, (i) {
            final filled = i < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: filled ? c.textPrimary : c.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $current of $total',
          style: geistText(fontSize: 11, color: c.textDim),
        ),
      ],
    );
  }
}

class AuthOtpInput extends StatefulWidget {
  const AuthOtpInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.errorText,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<AuthOtpInput> createState() => _AuthOtpInputState();
}

class _AuthOtpInputState extends State<AuthOtpInput> {
  static const _length = 6;
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioOtpSlots(
      controller: _controller,
      focusNode: _focusNode,
      errorText: widget.errorText,
      autofocus: true,
      onChanged: (value) {
        widget.onChanged?.call(value);
        if (value.length == _length) widget.onCompleted(value);
      },
    );
  }
}

void showAuthSnackBar(BuildContext context, String message, {bool isError = false}) {
  showStudioToast(context, message, icon: isError ? null : StudioIcons.check);
}

void showAuthError(BuildContext context, Object error) {
  final message = switch (error) {
    ApiException(statusCode: 429) =>
        'Too many attempts — please wait a moment before trying again.',
    // Prefer the server's own message (now specific and useful — e.g.
    // "Could not send the verification email...", "OTP service is
    // temporarily unavailable...") over a blanket generic one, even for
    // 5xx, so failures are actually diagnosable instead of a dead end.
    ApiException(:final message) when message.isNotEmpty => message,
    _ => 'Something went wrong',
  };
  showAuthSnackBar(context, message, isError: true);
}

/// Required Terms of Use (EULA) agreement on the sign-up and login forms
/// (App Store guideline 1.2). "Terms of Use" opens the full text in-app.
class AuthTermsCheckbox extends StatelessWidget {
  const AuthTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.showError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Highlights the row after a submit attempt without the box ticked.
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final base = StudioType.caption12(
      height: 1.45,
      color: showError && !value ? c.textPrimary : c.textSecondary,
    );
    InlineSpan link(String label) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/terms'),
        child: Text(
          label,
          style: base.copyWith(
            color: c.textPrimary,
            decoration: TextDecoration.underline,
            decorationColor: c.textPrimary,
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: StudioSize.tapTarget,
          height: StudioSize.tapTarget,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Center(
              child: IgnorePointer(
                child: Checkbox(
                  value: value,
                  onChanged: (_) {},
                  activeColor: c.textPrimary,
                  checkColor: c.background,
                  side: BorderSide(
                    color: showError && !value ? c.textPrimary : c.lineStrong,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  link('Terms of Service'),
                  const TextSpan(text: ' and '),
                  // No separate policy page yet: both open the in-app Terms.
                  link('Privacy Policy'),
                  // Kept for App Store review (guideline 1.2): the agreement covers this.
                  const TextSpan(
                    text: '. Studio 3 has zero tolerance for objectionable content or abusive users.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Browse without an account" — App Store guideline 5.1.1(v): browsing
/// isn't an account feature, so the auth screens always offer a way out.
class AuthGuestLink extends StatelessWidget {
  const AuthGuestLink({super.key, this.label = 'Browse without an account'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return StudioButton(
      label: label,
      variant: StudioButtonVariant.text,
      onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
    );
  }
}

/// 11 px legal line on `SignInFirst` (1.5, centered). Terms open the in-app page.
class AuthLegalLine extends StatelessWidget {
  const AuthLegalLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final base = StudioType.sans(11, height: 1.5, color: c.textPlaceholder);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/terms'),
              child: Text(
                'Terms',
                style: base.copyWith(color: c.textTertiary),
              ),
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: base.copyWith(color: c.textTertiary)),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// First screen (`SignInFirst` / `SignInFirstDark`): haze, large centred logo, form pinned
/// at the bottom (24 margins, 28 above the safe area). Login uses this same frame — there
/// is no separate login board — with the login fields inside [form].
class SignInLaunchScaffold extends StatelessWidget {
  const SignInLaunchScaffold({
    super.key,
    required this.form,
    this.showBackButton = false,
    this.onBackPressed,
  });

  final Widget form;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final showBack = showBackButton || onBackPressed != null;
    return Scaffold(
      backgroundColor: c.signInBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: StudioHaze()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoHeight = (constraints.maxHeight * 0.42).clamp(120.0, 309.0);
                final back = SizedBox(
                  height: 44,
                  child: showBack
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: _AuthBackButton(onPressed: onBackPressed ?? () => Navigator.maybePop(context)),
                        )
                      : null,
                );
                final formBlock = Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 28), child: form);
                // With room to spare, the logo sits in the middle of the space above the form
                // (`SignInFirst`) and shrinks if it must. With the keyboard up or large text, the
                // whole screen scrolls instead. (The form is about 260 tall at normal text size.)
                final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
                if (constraints.maxHeight >= 44 + logoHeight + 260 * textScale) {
                  return Column(
                    children: [
                      back,
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: logoHeight),
                            child: const FittedBox(fit: BoxFit.contain, child: StudioLogo.signIn()),
                          ),
                        ),
                      ),
                      formBlock,
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            back,
                            SizedBox(
                              height: logoHeight,
                              child: const FittedBox(fit: BoxFit.contain, child: StudioLogo.signIn()),
                            ),
                          ],
                        ),
                        formBlock,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Later sign-in steps (`SignIn2Code`, `SignIn3Profile`, `SignIn4Intention`): flat background,
/// 44 back, optional 3-segment bar, scrolling body, optional bar pinned 40 from the bottom.
class SignInStepScaffold extends StatelessWidget {
  const SignInStepScaffold({
    super.key,
    required this.body,
    this.onBack,
    this.progressCurrent,
    this.progressTotal = 3,
    this.bottom,
    this.bodyTop = 40,
  });

  final Widget body;
  final VoidCallback? onBack;

  /// 1-based. Null hides the bar (steps the board doesn't number).
  final int? progressCurrent;
  final int progressTotal;
  final Widget? bottom;

  /// Space above the body: 40 on the sign-up steps, 24 on the log-in boards (`LoginPassword`,
  /// `LoginReset`).
  final double bodyTop;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  _AuthBackButton(onPressed: onBack ?? () => Navigator.maybePop(context)),
                  if (progressCurrent != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: StudioProgressSegments(
                        current: progressCurrent!,
                        total: progressTotal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, bodyTop, 28, 24),
                child: body,
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      icon: StudioIcon(StudioIcons.backBold, size: 22, color: context.studio.textPrimary),
    );
  }
}

/// The eye on a password field (`LoginPassword`, `LoginReset`, `SignIn3Profile`): 20 Graphite in a
/// 44 tap area; crossed out while the password shows.
class AuthEyeButton extends StatelessWidget {
  const AuthEyeButton({super.key, required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 32),
        minimumSize: const Size(44, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      icon: StudioIcon(
        obscured ? StudioIcons.eye : StudioIcons.eyeOff,
        size: 20,
        color: context.studio.textSecondary,
      ),
    );
  }
}

class _ShowHide extends StatelessWidget {
  const _ShowHide({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        obscured ? 'Show' : 'Hide',
        style: StudioType.label13(weight: StudioType.medium, color: context.studio.textSecondary),
      ),
    );
  }
}

/// Six Geist Mono 32 slots on underlines, 56 tall (`SignIn2Code`). The active slot has a
/// 2 px underline and a 2 × 30 cursor. Submit is the caller's job on the sixth digit.
class StudioOtpSlots extends StatefulWidget {
  const StudioOtpSlots({
    super.key,
    this.controller,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.length = 6,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int length;
  final bool autofocus;

  @override
  State<StudioOtpSlots> createState() => _StudioOtpSlotsState();
}

class _StudioOtpSlotsState extends State<StudioOtpSlots> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(StudioOtpSlots old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_rebuild);
      _focus.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _focusField() {
    if (_focus.hasFocus) {
      _focus.unfocus();
      Future.microtask(() => _focus.requestFocus());
    } else {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final code = _controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _focusField,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _slot(c, i, code)),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 0,
          width: 0,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            autofillHints: const [AutofillHints.oneTimeCode],
            keyboardType: TextInputType.number,
            maxLength: widget.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(counterText: '', border: InputBorder.none),
            onChanged: widget.onChanged,
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(widget.errorText!, style: StudioType.caption12(height: 1.45, color: c.textPrimary)),
        ],
      ],
    );
  }

  Widget _slot(StudioColors c, int i, String code) {
    final char = i < code.length ? code[i] : '';
    final active = _focus.hasFocus && i == code.length;
    final filled = char.isNotEmpty;
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: filled || active ? c.textPrimary : c.lineStrong,
              width: active ? 2 : 1.5,
            ),
          ),
        ),
        child: Center(
          child: char.isNotEmpty
              ? Text(char, style: StudioType.mono(32, color: c.textPrimary))
              : active
                  ? Container(width: 2, height: 30, color: c.textPrimary)
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

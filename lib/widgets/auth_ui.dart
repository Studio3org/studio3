import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../theme/auth_palette.dart';
import '../widgets/studio_logo.dart';

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
    final c = context.authColors;
    final showBack = showBackButton || onBackPressed != null;
    final brightness = Theme.of(context).brightness;

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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (showLogo)
                          Center(child: StudioAuthLogo(dark: brightness == Brightness.dark)),
                        if (showBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: c.textMuted,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ),
                      ],
                    ),
                    if (!compact) ...[
                      Text(
                        'Discover art and the people who make it.',
                        textAlign: TextAlign.center,
                        style: geistText(fontSize: 13, color: c.textMuted),
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
    final c = context.authColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: geistText(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: c.textPrimary,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: geistText(fontSize: 16, color: c.textMuted, height: 1.45),
          ),
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
    this.prefixIcon,
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
    final c = context.authColors;
    final lineColor = errorText != null ? c.error : c.border;
    final focusColor = errorText != null ? c.error : c.borderFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: geistText(fontSize: 16, color: c.textPrimary),
          cursorColor: c.textPrimary,
          decoration: InputDecoration(
            labelText: placeholder,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: geistText(fontSize: 13, color: c.textMuted),
            floatingLabelStyle: geistText(fontSize: 13, color: c.textMuted),
            isDense: true,
            contentPadding: const EdgeInsets.only(top: 18, bottom: 8),
            border: UnderlineInputBorder(borderSide: BorderSide(color: lineColor)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: lineColor)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: focusColor, width: 1.5)),
            suffixIcon: onToggleVisibility != null
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: c.textMuted,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: geistText(fontSize: 12, color: c.error)),
        ],
      ],
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
    final c = context.authColors;
    final canPress = enabled && !loading;
    final useAccentStyle = enabled;
    return SizedBox(
      height: AppDims.primaryButtonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: canPress ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: useAccentStyle ? c.accent : c.greyAccent,
          foregroundColor: useAccentStyle ? c.backgroundDeep : c.textDim,
          disabledBackgroundColor: useAccentStyle ? c.accent : c.greyAccent,
          disabledForegroundColor: useAccentStyle ? c.backgroundDeep : c.textDim,
          overlayColor: c.backgroundDeep.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: geistText(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.backgroundDeep),
              )
            : Text(label),
      ),
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
    final c = context.authColors;
    return SizedBox(
      height: AppDims.primaryButtonHeight,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: c.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: geistText(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
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
    final c = context.authColors;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: c.accent,
            checkColor: c.background,
            side: BorderSide(color: c.border),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text('Remember me', style: geistText(fontSize: 12, color: c.textMuted)),
        ),
        const Spacer(),
        if (onForgot != null)
          TextButton(
            onPressed: onForgot,
            style: TextButton.styleFrom(
              foregroundColor: c.textMuted,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Forgot login?', style: geistText(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ],
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
    final c = context.authColors;
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: geistText(fontSize: 14, color: c.textMuted),
          children: [
            TextSpan(text: prompt),
            TextSpan(
              text: actionLabel,
              style: geistText(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
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
    final c = context.authColors;
    final code = _controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            // A dismissed on-screen keyboard doesn't clear Flutter's
            // internal focus state, so requestFocus() alone is a no-op
            // once the node is already focused — force a focus transition
            // so the platform "show keyboard" call fires again.
            if (_focusNode.hasFocus) {
              _focusNode.unfocus();
              Future.microtask(() => _focusNode.requestFocus());
            } else {
              _focusNode.requestFocus();
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_length, (i) {
              final char = i < code.length ? code[i] : '';
              final active = i == code.length && _focusNode.hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: widget.errorText != null
                          ? c.error
                          : active
                              ? c.borderFocus
                              : c.border,
                      width: active ? 2 : 1.5,
                    ),
                  ),
                ),
                child: Text(
                  char,
                  style: geistMono(fontSize: 28, color: c.textPrimary),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 0,
          width: 0,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            maxLength: _length,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.transparent),
            decoration: const InputDecoration(counterText: '', border: InputBorder.none),
            onChanged: (value) {
              setState(() {});
              widget.onChanged?.call(value);
              if (value.length == _length) widget.onCompleted(value);
            },
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(widget.errorText!, style: geistText(fontSize: 12, color: c.error)),
        ],
      ],
    );
  }
}

void showAuthSnackBar(BuildContext context, String message, {bool isError = false}) {
  final c = context.authColors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: geistText(fontWeight: FontWeight.w500, color: c.backgroundDeep),
      ),
      backgroundColor: isError ? c.error : c.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );
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
    final c = context.authColors;
    final base = geistText(
      fontSize: 12,
      height: 1.45,
      color: showError && !value ? c.error : c.textMuted,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: c.accent,
            checkColor: c.background,
            side: BorderSide(
              color: showError && !value ? c.error : c.border,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
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
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/terms'),
                      child: Text(
                        'Terms of Use (EULA)',
                        style: base.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: '. Studio3 has zero tolerance for objectionable '
                        'content or abusive users.',
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
  const AuthGuestLink({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.authColors;
    return TextButton(
      onPressed: () =>
          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
      style: TextButton.styleFrom(foregroundColor: c.textMuted),
      child: Text(
        'Browse without an account',
        style: geistText(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: c.textMuted,
        ),
      ),
    );
  }
}

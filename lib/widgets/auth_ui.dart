import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/studio_logo.dart';

/// Dark premium palette — black & grey glass auth.
abstract final class AuthColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color backgroundDeep = Color(0xFF000000);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF2A2A2A);
  static const Color greyAccent = Color(0xFF3D3D3D);
  static const Color border = Color(0x26FFFFFF);
  static const Color borderFocus = Color(0x55FFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color textDim = Color(0x80FFFFFF);
  static const Color error = Color(0xFFFF6B6B);
  static const Color accent = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF4ADE80);
}

/// Black/grey background with sweeping curved lines (reference-inspired).
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
  });

  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showBack = showBackButton || onBackPressed != null;

    return Scaffold(
      backgroundColor: AuthColors.backgroundDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
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
                            const Center(child: StudioAuthLogo()),
                            if (showBack)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: AuthColors.textMuted,
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
                            'Discover Art. Collect Stories.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: AuthColors.textDim),
                          ),
                          const SizedBox(height: 28),
                        ] else
                          const SizedBox(height: 28),
                        child,
                        const SizedBox(height: 32),
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
            color: AuthColors.surface.withValues(alpha: 0.55),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: AuthColors.textPrimary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.inter(fontSize: 14, color: AuthColors.textDim),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppDims.pillInputHeight,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: GoogleFonts.inter(fontSize: 15, color: AuthColors.textPrimary),
            cursorColor: AuthColors.textPrimary,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: AuthColors.textDim),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AuthColors.textMuted, size: 20)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: errorText != null ? AuthColors.error : AuthColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: errorText != null ? AuthColors.error : AuthColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? AuthColors.error : AuthColors.borderFocus,
                  width: 1.2,
                ),
              ),
              suffixIcon: onToggleVisibility != null
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AuthColors.textMuted,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: GoogleFonts.inter(fontSize: 12, color: AuthColors.error)),
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
    final canPress = enabled && !loading;
    final useAccentStyle = enabled;
    return SizedBox(
      height: AppDims.primaryButtonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: canPress ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: useAccentStyle ? AuthColors.accent : AuthColors.surfaceElevated,
          foregroundColor: useAccentStyle ? AuthColors.backgroundDeep : AuthColors.textDim,
          disabledBackgroundColor: useAccentStyle ? AuthColors.accent : AuthColors.surfaceElevated,
          disabledForegroundColor: useAccentStyle ? AuthColors.backgroundDeep : AuthColors.textDim,
          overlayColor: AuthColors.backgroundDeep.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AuthColors.backgroundDeep),
              )
            : Text(label),
      ),
    );
  }
}

class AuthGhostButton extends StatelessWidget {
  const AuthGhostButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDims.primaryButtonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AuthColors.textPrimary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
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
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AuthColors.accent,
            checkColor: AuthColors.backgroundDeep,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text('Remember me', style: GoogleFonts.inter(fontSize: 12, color: AuthColors.textMuted)),
        ),
        const Spacer(),
        if (onForgot != null)
          TextButton(
            onPressed: onForgot,
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.textMuted,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Forgot login?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
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
    return Row(
      children: [
        Expanded(child: Divider(color: AuthColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AuthColors.textDim)),
        ),
        Expanded(child: Divider(color: AuthColors.border)),
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
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 14, color: AuthColors.textMuted),
          children: [
            TextSpan(text: prompt),
            TextSpan(
              text: actionLabel,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AuthColors.textPrimary,
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
                  color: filled ? AuthColors.textPrimary : AuthColors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $current of $total',
          style: GoogleFonts.inter(fontSize: 11, color: AuthColors.textDim),
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
                width: 44,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.errorText != null
                        ? AuthColors.error
                        : active
                            ? AuthColors.borderFocus
                            : AuthColors.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  char,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AuthColors.textPrimary),
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
          Text(widget.errorText!, style: GoogleFonts.inter(fontSize: 12, color: AuthColors.error)),
        ],
      ],
    );
  }
}

void showAuthSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.inter(color: AuthColors.textPrimary)),
      backgroundColor: isError ? const Color(0xFF3D2020) : AuthColors.surfaceElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

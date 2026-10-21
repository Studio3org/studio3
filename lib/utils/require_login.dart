import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../utils/auth_validators.dart';
import '../widgets/studio/studio.dart';

/// Gate for account-based actions (like, save, comment, follow, collect,
/// message, post…). Guests can browse everything public (App Store guideline
/// 5.1.1(v)); only when they try one of these does this ask them to log in.
///
/// Returns true when the caller may proceed (already signed in). For a guest
/// it shows the prompt and returns false — logging in rebuilds the app from a
/// fresh signed-in shell, so the original action is never resumed.
Future<bool> requireLogin(
  BuildContext context, {
  String? title,
  String message = 'Log in or create a free account to continue.',
}) async {
  if (AuthSession.instance.isLoggedIn) return true;
  await showStudioSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => _LoginPromptSheet(
      title: title ?? 'Sign in to continue',
      message: message,
    ),
  );
  return false;
}

class _LoginPromptSheet extends StatefulWidget {
  const _LoginPromptSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_LoginPromptSheet> createState() => _LoginPromptSheetState();
}

class _LoginPromptSheetState extends State<_LoginPromptSheet> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _go(String route, {String? email}) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamed(route, arguments: email);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final emailOk = AuthValidators.email(_emailController.text) == null;
    return StudioSheet(
      scrollable: true,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(widget.message, style: StudioType.body15(color: c.textSecondary)),
            ],
          ),
        ),
        StudioUnderlineField(
          label: 'Email',
          controller: _emailController,
          hint: 'you@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (emailOk) _go('/signup', email: _emailController.text.trim());
          },
        ),
        StudioButton(
          label: 'Continue',
          onPressed: emailOk ? () => _go('/signup', email: _emailController.text.trim()) : null,
        ),
        Text.rich(
          TextSpan(
            style: StudioType.caption12(height: 1.5, color: c.textSecondary),
            children: [
              const TextSpan(text: "We'll email you a code to sign in. By continuing, you agree to our "),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context, rootNavigator: true).pushNamed('/terms');
                  },
                  child: Text(
                    'Terms',
                    style: StudioType.caption12(height: 1.5, color: c.textPrimary),
                  ),
                ),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: StudioType.caption12(height: 1.5, color: c.textPrimary),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        StudioButton(label: 'Log in', onPressed: () => _go('/login')),
        StudioButton(
          label: 'Create account',
          variant: StudioButtonVariant.outline,
          onPressed: () => _go('/signup'),
        ),
        StudioButton(
          label: 'Not now',
          variant: StudioButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Full-page stand-in for a tab that only makes sense with an account
/// (Saved, own Profile) while browsing as a guest.
class GuestAccountPlaceholder extends StatelessWidget {
  const GuestAccountPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  // Kept so existing call sites still compile. The signed-out board has no icon.
  // ignore: unused_field
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: StudioType.sans(24, weight: StudioType.medium, height: 1.2, color: c.textPrimary)),
              const SizedBox(height: 8),
              Text(message, style: StudioType.body15(color: c.textSecondary)),
              const SizedBox(height: 18),
              StudioButton(
                label: 'Log in',
                height: 50,
                onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

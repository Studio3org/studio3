import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_session.dart';
import '../theme/home_feed_tokens.dart';

/// Gate for account-based actions (like, save, comment, follow, collect,
/// message, post…). Guests can browse everything public (App Store guideline
/// 5.1.1(v)); only when they try one of these does this ask them to log in.
///
/// Returns true when the caller may proceed (already signed in). For a guest
/// it shows the prompt and returns false — logging in rebuilds the app from a
/// fresh signed-in shell, so the original action is never resumed.
Future<bool> requireLogin(
  BuildContext context, {
  String message = 'Log in or create a free account to continue.',
}) async {
  if (AuthSession.instance.isLoggedIn) return true;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: HomeFeedTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _LoginPromptSheet(message: message),
  );
  return false;
}

class _LoginPromptSheet extends StatelessWidget {
  const _LoginPromptSheet({required this.message});

  final String message;

  void _go(BuildContext context, String route) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join Studio3',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: HomeFeedTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _go(context, '/login'),
              style: FilledButton.styleFrom(
                backgroundColor: HomeFeedTokens.textPrimary,
                foregroundColor: HomeFeedTokens.textInverse,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Log in'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _go(context, '/signup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeFeedTokens.textPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Create account'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: HomeFeedTokens.textSecondary,
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
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

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: HomeFeedTokens.textSecondary),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed('/login'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeFeedTokens.textPrimary,
                    foregroundColor: HomeFeedTokens.textInverse,
                    minimumSize: const Size(200, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Log in or sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

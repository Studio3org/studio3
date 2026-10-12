import '../services/auth_session.dart';

/// Resolves the initial route after app startup or auth.
String resolveInitialRoute() {
  final session = AuthSession.instance;
  // Guests land straight on the feed — browsing doesn't need an account
  // (App Store guideline 5.1.1(v)); account actions prompt to log in.
  if (!session.isLoggedIn) return '/';
  if (!session.isOnboarded) return '/onboarding';
  return '/';
}

/// After login/signup navigation target.
String resolvePostAuthRoute() {
  final session = AuthSession.instance;
  if (!session.isOnboarded) return '/onboarding';
  return '/';
}

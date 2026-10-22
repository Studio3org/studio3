import '../services/auth_session.dart';

/// Resolves the initial route after app startup or auth.
String resolveInitialRoute() {
  final session = AuthSession.instance;
  // First screen is sign-in. Look around on that page opens the feed.
  if (!session.isLoggedIn) return '/login';
  if (!session.isOnboarded) return '/onboarding';
  return '/';
}

/// After login/signup navigation target.
String resolvePostAuthRoute() {
  final session = AuthSession.instance;
  if (!session.isOnboarded) return '/onboarding';
  return '/';
}

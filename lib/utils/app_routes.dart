import '../services/auth_session.dart';

/// Resolves the initial route after app startup or auth.
/// An account is required before anything else (`HandoffAccount`, `NoteSignInFirst`): no
/// browsing signed out, and no "Look around first". The canvas archived the guest boards
/// (`SignIn1Sheet`, `ProfileSignedOut`, `SignIn5Done`). Set false to let guests browse again
/// (App Store guideline 5.1.1(v)) if review asks for it; the guest paths are still in place.
const bool kAccountRequired = true;

String resolveInitialRoute() {
  final session = AuthSession.instance;
  // First screen is sign-in (email first).
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

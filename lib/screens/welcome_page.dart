import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auth_user.dart';
import '../widgets/auth_ui.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.split(' ').first;

    return AuthScaffold(
      compact: true,
      child: AuthFormBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.celebration_outlined, color: AuthColors.textPrimary, size: 52),
            const SizedBox(height: 20),
            AuthPageTitle(
              title: 'Welcome, $firstName!',
              subtitle: 'Your Studio 3 account @${user.username} is ready.',
            ),
            const SizedBox(height: 12),
            Text(
              'Start discovering art, collecting stories, and sharing your creative journey.',
              style: GoogleFonts.inter(fontSize: 14, color: AuthColors.textDim, height: 1.5),
            ),
            const SizedBox(height: 32),
            AuthPrimaryButton(
              label: 'Get Started',
              onPressed: () {
                final route = user.onboardingComplete ? '/' : '/onboarding';
                Navigator.pushReplacementNamed(context, route);
              },
            ),
          ],
        ),
      ),
    );
  }
}

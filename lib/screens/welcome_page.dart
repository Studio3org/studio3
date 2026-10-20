import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../theme/auth_palette.dart';
import '../widgets/auth_ui.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.split(' ').first;
    final c = context.authColors;

    return AuthScaffold(
      compact: true,
      child: AuthFormBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.celebration_outlined, color: c.textPrimary, size: 52),
            const SizedBox(height: 20),
            AuthPageTitle(
              title: 'Welcome, $firstName!',
              subtitle: 'Your Studio 3 account @${user.username} is ready.',
            ),
            const SizedBox(height: 12),
            Text(
              'Start discovering art, collecting stories, and sharing your creative journey.',
              style: geistText(fontSize: 14, color: c.textDim, height: 1.5),
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

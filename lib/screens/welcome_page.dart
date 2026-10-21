import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/auth_ui.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.split(' ').first;
    final c = context.studio;

    return AuthScaffold(
      compact: true,
      showLogo: true,
      child: AuthFormBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPageTitle(
              title: 'Welcome, $firstName!',
              subtitle: 'Your Studio 3 account @${user.username} is ready.',
            ),
            const SizedBox(height: 12),
            Text(
              'Start discovering art, collecting stories, and sharing your creative journey.',
              style: StudioType.body14(height: 1.5, color: c.textSecondary),
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

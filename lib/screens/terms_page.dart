import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Version of the terms text below. Must match the backend's
/// `CURRENT_TERMS_VERSION` (src/shared/constants.py), which also serves the
/// same wording at `/terms` — if either copy changes, update both and bump
/// both versions so existing accounts are asked to agree again.
const kTermsVersion = '2026-10-10';

/// Terms of Use / EULA (App Store guideline 1.2), bundled in-app so agreeing
/// on the sign-up and login forms never depends on a network fetch.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _sections = <(String, String)>[
    (
      'Your account',
      'You must be at least 13 years old (or the minimum age in your country) '
          'to create an account. Keep your login details private; you are '
          'responsible for activity on your account. You can browse Studio3 '
          'without an account, and delete your account at any time from '
          'Settings.',
    ),
    (
      'Your content',
      'You keep ownership of what you post. You give Studio3 a non-exclusive, '
          'worldwide, royalty-free licence to host, display, and distribute it '
          'inside the service so others can see it. You confirm you have the '
          'rights to everything you post.',
    ),
    (
      'Reporting and blocking',
      'Every piece, scene, comment, and profile has a Report option, and you '
          'can block any user from their profile or from the ••• menu on '
          'their content. Blocking hides that person\'s content from you '
          'right away and stops them from messaging you. Our team reviews '
          'every report and acts on objectionable content within 24 hours, '
          'removing it and ejecting users who posted it.',
    ),
    (
      'Buying and selling',
      'Sellers are responsible for the accuracy of their listings and for '
          'shipping what they sell. Payments are processed by our payment '
          'provider; Studio3 may hold funds, issue refunds, or resolve disputes '
          'under its marketplace policies.',
    ),
    (
      'Ending your use',
      'We may suspend or terminate accounts that violate these terms. You may '
          'stop using Studio3 and delete your account at any time.',
    ),
    (
      'Disclaimers',
      'Studio3 is provided "as is". To the extent the law allows, we are not '
          'liable for content posted by users or for indirect or consequential '
          'losses. This licence is granted to you by Studio3, not Apple; Apple '
          'has no obligation to provide maintenance or support for the app.',
    ),
    (
      'Contact',
      'Questions or urgent safety concerns: support@studio-3.co',
    ),
  ];

  static const _prohibited = [
    'sexually explicit, pornographic, or exploits minors in any way',
    'hateful, discriminatory, or harassing toward any person or group',
    'violent, threatening, or encouraging self-harm or illegal activity',
    'bullying, stalking, impersonating, or intimidating another user',
    'spam, scams, or misleading listings',
    "someone else's work you don't have the right to share or sell",
  ];

  @override
  Widget build(BuildContext context) {
    final heading = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: HomeFeedTokens.textPrimary,
    );
    final body = GoogleFonts.inter(
      fontSize: 14,
      height: 1.55,
      color: HomeFeedTokens.neutral800,
    );

    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.detailBackground,
        foregroundColor: HomeFeedTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Terms of Use (EULA)',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'Effective $kTermsVersion. By creating an account, logging in, '
              'or posting on Studio3 you agree to these terms. If you do not '
              'agree, do not use the app.',
              style: body.copyWith(color: HomeFeedTokens.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3DDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zero tolerance for objectionable content and abusive users',
                    style: heading,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Studio3 has no tolerance for objectionable content or '
                    'abusive behaviour. You may not post, upload, comment, or '
                    'send anything that is:',
                    style: body,
                  ),
                  const SizedBox(height: 6),
                  for (final item in _prohibited)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: body),
                          Expanded(child: Text(item, style: body)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Anyone who breaks these rules will have the content '
                    'removed and may have their account suspended or '
                    'permanently terminated, without notice or refund.',
                    style: body,
                  ),
                ],
              ),
            ),
            for (final (title, text) in _sections) ...[
              const SizedBox(height: 24),
              Text(title, style: heading),
              const SizedBox(height: 8),
              Text(text, style: body),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/studio/studio.dart';

/// Studio 3's privacy policy, on the company site (App Store guideline 5.1.1(i): it must be
/// reachable inside the app). The same link goes in App Store Connect. Mind the spelling:
/// studio**s**three.com; studiothree.com is a different business.
const kPrivacyPolicyUrl = 'https://studiosthree.com/privacy';

/// Stands in for the browser in tests: set it to record the URL instead of opening it.
@visibleForTesting
Future<bool> Function(Uri url)? debugPrivacyPolicyLauncher;

/// Opens the privacy policy in the browser, or says why it couldn't.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final url = Uri.parse(kPrivacyPolicyUrl);
  try {
    final launched = await (debugPrivacyPolicyLauncher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(url);
    if (!launched && context.mounted) showStudioToast(context, 'Could not open the browser.', icon: null);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not open the privacy policy.', icon: null);
  }
}

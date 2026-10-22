import 'package:flutter/material.dart';

import '../../../widgets/studio/studio_toast.dart';

/// Bottom-center notice shown when previewing your own profile as a viewer.
///
/// No board: drawn as the toast box (`SignIn5Done`; Ink, radius 12, 14/500), without the
/// check icon since nothing was just done.
class ProfileViewerModeCapsule extends StatelessWidget {
  const ProfileViewerModeCapsule({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudioToastBox(message: 'Viewing your profile as others see it', icon: null);
  }
}

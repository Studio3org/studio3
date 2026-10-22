import 'package:flutter/material.dart';

import '../../../widgets/studio/studio_empty_state.dart';

/// Shown in place of the pieces/scenes/series tabs when viewing a private
/// profile the caller can't yet see (not the owner, not an accepted follower).
///
/// No board: drawn as the boards' empty state (`SavedEmpty`), with the same copy as before.
class ProfileLockedPlaceholder extends StatelessWidget {
  const ProfileLockedPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: StudioEmptyState(
        title: 'This account is private',
        message: 'Follow this account to see their pieces, scenes, and series.',
      ),
    );
  }
}

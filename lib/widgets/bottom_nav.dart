import 'package:flutter/material.dart';

import 'studio/studio_floating_nav.dart';
import 'studio/studio_icon.dart';

/// Bottom nav slots, in the `Main` board order: Home, Explore, Post, Events, Profile.
/// Saved stays on the home top bar. Reels opens from a video, not from this bar.
abstract final class BottomNavIndex {
  static const int home = 0;
  static const int explore = 1;
  static const int post = 2;
  static const int events = 3;
  static const int profile = 4;

  /// A page that is not one of the five slots (Saved, Reels).
  static const int none = -1;
}

/// Floating nav on the shell (`Main`). One 64 px pill, 16 from the sides and
/// 28 above the bottom safe area. Slots match the board: Home, Explore, Post
/// (26 px), Events, Profile.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedNavIndex,
    required this.onNavTap,
    this.avatarUrl,
  });

  final int selectedNavIndex;
  final ValueChanged<int> onNavTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final photo = (avatarUrl == null || avatarUrl!.isEmpty) ? null : avatarUrl;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: StudioFloatingNav(
        currentIndex: selectedNavIndex,
        onTap: onNavTap,
        items: [
          const StudioNavItem(label: 'Home', icon: StudioIcons.home),
          const StudioNavItem(label: 'Explore', icon: StudioIcons.explore),
          const StudioNavItem(label: 'Post', icon: StudioIcons.post, iconSize: 26),
          const StudioNavItem(label: 'Events', icon: StudioIcons.events),
          StudioNavItem(label: 'Profile', isProfile: true, avatarUrl: photo),
        ],
      ),
    );
  }
}

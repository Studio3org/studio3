import 'package:flutter/material.dart';

import 'studio/studio_floating_nav.dart';
import 'studio/studio_icon.dart';

/// Bottom nav slots. Order is the product order (not the board's Post / Events
/// slots): Home, Discover, Reels, Saved, Profile.
abstract final class BottomNavIndex {
  static const int home = 0;
  static const int discover = 1;
  static const int reels = 2;
  static const int bookmark = 3;
  static const int profile = 4;
}

/// Floating nav on the shell (`Main` and profiles). One 64 px pill, 16 from the
/// sides and 28 above the bottom safe area. The five current slots and their
/// tap behaviour stay; only the drawing changes to the board (24 px outlines,
/// stroke 1.8, active slot on a round pill).
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
          const StudioNavItem(label: 'Discover', icon: StudioIcons.explore),
          const StudioNavItem(label: 'Reels', icon: StudioIcons.reels),
          const StudioNavItem(label: 'Saved', icon: StudioIcons.save),
          StudioNavItem(label: 'Profile', isProfile: true, avatarUrl: photo),
        ],
      ),
    );
  }
}

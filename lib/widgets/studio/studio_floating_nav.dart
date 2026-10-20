import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import 'studio_avatar.dart';
import 'studio_icon.dart';

/// One slot of [StudioFloatingNav]: a board icon, or (for the profile slot) the user's
/// avatar — or the person icon when signed out.
class StudioNavItem {
  const StudioNavItem({
    required this.label,
    this.icon,
    this.iconSize = 24,
    this.isProfile = false,
    this.avatarUrl,
  }) : assert(icon != null || isProfile);

  final String label;
  final String? icon;

  /// 24 for most icons; the board's Post "+" is 26.
  final double iconSize;
  final bool isProfile;

  /// Signed-in profile photo; null with [isProfile] shows the person icon.
  final String? avatarUrl;
}

/// Floating nav (`Main`): a 64 tall round pill, Ink in light, 16 from the sides and
/// 28 above the bottom safe area. Slots are 52 × 48; the active one sits on a round
/// #2A2A2A pill with a Gallery White icon, others are #8E8E8E. Icons are 24 px outlines,
/// stroke 1.8. The profile slot is a 30 px avatar with a 1.5 px Gallery White ring.
///
/// Place it at the bottom of a [Stack] (it pads itself), e.g. `Positioned(left: 0,
/// right: 0, bottom: 0, child: StudioFloatingNav(...))`.
class StudioFloatingNav extends StatelessWidget {
  const StudioFloatingNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<StudioNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + StudioSize.navBottomGap;
    return Padding(
      padding: EdgeInsets.fromLTRB(StudioSize.navSideInset, 0, StudioSize.navSideInset, bottom),
      child: Container(
        height: StudioSize.navHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.navFill,
          borderRadius: BorderRadius.circular(StudioRadius.round),
          border: c.navBorder.a == 0 ? null : Border.all(color: c.navBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              _Slot(item: items[i], active: i == currentIndex, onTap: () => onTap(i)),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.item, required this.active, required this.onTap});

  final StudioNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final color = active ? c.navIconActive : c.navIconInactive;
    final Widget glyph;
    if (item.isProfile && item.avatarUrl != null) {
      glyph = StudioAvatar(
        url: item.avatarUrl,
        size: 30,
        ringWidth: 1.5,
        ringColor: StudioColors.galleryWhite,
      );
    } else {
      glyph = StudioIcon(
        item.isProfile ? StudioIcons.profile : item.icon!,
        size: item.iconSize,
        color: color,
      );
    }
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : StudioMotion.quick,
          width: 52,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c.navActive : c.navActive.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(StudioRadius.round),
          ),
          child: glyph,
        ),
      ),
    );
  }
}

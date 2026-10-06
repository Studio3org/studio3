import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/nav_assets.dart';
import '../widgets/profile_avatar.dart';

/// Bottom nav — Figma Home bar (home, explore, post, event, profile).
abstract final class BottomNavIndex {
  static const int home = 0;
  static const int discover = 1;
  static const int post = 2;
  static const int event = 3;
  static const int profile = 4;
}

const Color _kNavFill = Color(0xD9231F1B);
const Color _kNavSelected = Color(0xFFFAFAF7);
const Color _kNavInactive = Color(0xFF8C8880);

const double _kBarWidth = 342;
const double _kBarHeight = 64;
const double _kBarRadius = 32;
const double _kIconSize = 24;
const double _kIconHit = 48;
const double _kAvatarSize = 24;
const double _kBottomLift = 12;

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
    return Positioned(
      left: 10,
      right: 10,
      bottom: _kBottomLift,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _NavBar(
              selectedNavIndex: selectedNavIndex,
              onNavTap: onNavTap,
              avatarUrl: avatarUrl,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.selectedNavIndex,
    required this.onNavTap,
    this.avatarUrl,
  });

  final int selectedNavIndex;
  final ValueChanged<int> onNavTap;
  final String? avatarUrl;

  static const _slots = <({int index, String asset})>[
    (index: BottomNavIndex.home, asset: NavAssets.homeIcon),
    (index: BottomNavIndex.discover, asset: NavAssets.exploreIcon),
    (index: BottomNavIndex.post, asset: NavAssets.postIcon),
    (index: BottomNavIndex.event, asset: NavAssets.eventIcon),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kBarRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: _kBarWidth,
          height: _kBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kNavFill,
            borderRadius: BorderRadius.circular(_kBarRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final slot in _slots)
                _NavIconButton(
                  asset: slot.asset,
                  selected: selectedNavIndex == slot.index,
                  onTap: () => onNavTap(slot.index),
                ),
              _ProfileAvatar(
                selected: selectedNavIndex == BottomNavIndex.profile,
                avatarUrl: avatarUrl,
                onTap: () => onNavTap(BottomNavIndex.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _kNavSelected : _kNavInactive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kIconHit,
          height: _kIconHit,
          child: Center(
            child: SvgPicture.asset(
              asset,
              width: _kIconSize,
              height: _kIconSize,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.selected,
    required this.onTap,
    this.avatarUrl,
  });

  final bool selected;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kIconHit,
          height: _kIconHit,
          child: Center(
            child: Container(
              width: _kAvatarSize,
              height: _kAvatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? _kNavSelected.withValues(alpha: 0.7)
                      : Colors.transparent,
                  width: selected ? 1.5 : 0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ProfileAvatar(
                url: avatarUrl,
                size: _kAvatarSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

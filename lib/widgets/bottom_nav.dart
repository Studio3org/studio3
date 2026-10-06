import 'dart:ui';

import 'package:flutter/material.dart';

import '../widgets/profile_avatar.dart';

/// Bottom nav — Figma Nav/Bottom (4-icon pill + profile avatar).
abstract final class BottomNavIndex {
  static const int home = 0;
  static const int discover = 1;
  static const int reels = 2;
  static const int bookmark = 3;
  static const int profile = 4;
}

const Color _kNavGlassFill = Color(0x991A1A1A);
const Color _kNavGlassBorder = Color(0x26FFFFFF);

const double _kPillWidth = 275;
const double _kPillHeight = 52;
const double _kPillRadius = 100;
const double _kAvatarSize = 50;
const double _kPillAvatarGap = 8;
const double _kIconSize = 24;
const double _kIconHit = 48;
const double _kBottomLift = 12;
const double _kInactiveWhite = 0.4;

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NavPill(
                  selectedNavIndex: selectedNavIndex,
                  onNavTap: onNavTap,
                ),
                const SizedBox(width: _kPillAvatarGap),
                _ProfileAvatar(
                  selected: selectedNavIndex == BottomNavIndex.profile,
                  avatarUrl: avatarUrl,
                  onTap: () => onNavTap(BottomNavIndex.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: _kNavGlassFill,
            borderRadius: borderRadius,
            border: Border.all(color: _kNavGlassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.selectedNavIndex,
    required this.onNavTap,
  });

  final int selectedNavIndex;
  final ValueChanged<int> onNavTap;

  static const _slots = <({int index, IconData outline, IconData filled})>[
    (
      index: BottomNavIndex.home,
      outline: Icons.home_outlined,
      filled: Icons.home_rounded,
    ),
    (
      index: BottomNavIndex.discover,
      outline: Icons.explore_outlined,
      filled: Icons.explore_rounded,
    ),
    (
      index: BottomNavIndex.reels,
      outline: Icons.play_circle_outline,
      filled: Icons.play_circle_rounded,
    ),
    (
      index: BottomNavIndex.bookmark,
      outline: Icons.bookmark_border_rounded,
      filled: Icons.bookmark_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: BorderRadius.circular(_kPillRadius),
      child: SizedBox(
        width: _kPillWidth,
        height: _kPillHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final slot in _slots)
              _PillIconButton(
                selected: selectedNavIndex == slot.index,
                outline: slot.outline,
                filled: slot.filled,
                onTap: () => onNavTap(slot.index),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.selected,
    required this.outline,
    required this.filled,
    required this.onTap,
  });

  final bool selected;
  final IconData outline;
  final IconData filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? filled : outline;
    final color =
        selected ? Colors.white : Colors.white.withValues(alpha: _kInactiveWhite);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kIconHit,
          height: _kIconHit,
          child: Icon(
            icon,
            size: _kIconSize,
            color: color,
            applyTextScaling: false,
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
    final borderColor = selected
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: _GlassSurface(
          borderRadius: BorderRadius.circular(_kAvatarSize / 2),
          child: Container(
            width: _kAvatarSize,
            height: _kAvatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
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
    );
  }
}

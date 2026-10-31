import 'package:flutter/material.dart';

import '../../../theme/studio_colors.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/profile_cover_image.dart';
import '../../../widgets/studio/studio_icon.dart';
import '../profile_constants.dart';

/// Cover, overlapping avatar, and Figma chrome (back / more).
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.width,
    this.coverUrl,
    this.avatarUrl,
    this.showDefaultCover = true,
    this.onBack,
    this.onMore,
    this.onAvatarTap,
  });

  final double width;
  final String? coverUrl;
  final String? avatarUrl;
  final bool showDefaultCover;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final ring = context.studio.background;

    return SizedBox(
      height: kProfileHeroHeight,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: kProfileCoverHeight,
            child: ProfileCoverImage(
              url: coverUrl,
              height: kProfileCoverHeight,
              width: width,
              alignment: const Alignment(0, -0.2),
              showDefaultWhenEmpty: showDefaultCover,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 110,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x61111111), Color(0x00111111)],
                  ),
                ),
              ),
            ),
          ),
          if (onBack != null)
            Positioned(
              top: topInset + 12,
              left: 8,
              child: _CoverButton(
                onPressed: onBack!,
                semanticLabel: 'Back',
                icon: StudioIcons.backBold,
              ),
            ),
          if (onMore != null)
            Positioned(
              top: topInset + 12,
              right: 8,
              child: _CoverButton(
                onPressed: onMore!,
                semanticLabel: 'More options',
                icon: StudioIcons.more,
              ),
            ),
          Positioned(
            top: kProfileAvatarTop,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onAvatarTap,
                behavior: onAvatarTap != null
                    ? HitTestBehavior.opaque
                    : HitTestBehavior.deferToChild,
                child: Container(
                  width: kProfileAvatarSize,
                  height: kProfileAvatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: kProfileAvatarBorder),
                  ),
                  child: ProfileAvatar(
                    url: avatarUrl,
                    size: kProfileAvatarSize - kProfileAvatarBorder * 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    required this.onPressed,
    required this.semanticLabel,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String semanticLabel;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, 1),
                  child: StudioIcon(icon, size: 22, color: const Color(0x4D000000)),
                ),
                StudioIcon(icon, size: 22, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../widgets/profile_avatar.dart';
import '../../../widgets/profile_cover_image.dart';
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

  static const _backAsset = 'assets/profile/icon_back.svg';
  static const _moreAsset = 'assets/profile/icon_more.svg';

  /// Figma 2650:1894 — 56pt bar; back 9×16.5 at (10, 19.75), more 16×2.4 at right 10 / 26.8.
  static const _backTop = 19.75;
  static const _moreTop = 26.8;
  static const _hitPad = 16.0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

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
            height: topInset + 56,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x6B231F1B),
                      Color(0x29231F1B),
                      Color(0x00231F1B),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
            ),
          ),
          if (onBack != null)
            Positioned(
              top: topInset + _backTop - _hitPad,
              left: kProfileHorizontalPad - _hitPad,
              child: _ChromeHit(
                onPressed: onBack!,
                width: 9,
                height: 16.5,
                semanticLabel: 'Back',
                child: SvgPicture.asset(
                  _backAsset,
                  width: 9,
                  height: 16.5,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (onMore != null)
            Positioned(
              top: topInset + _moreTop - _hitPad,
              right: kProfileHorizontalPad - _hitPad,
              child: _ChromeHit(
                onPressed: onMore!,
                width: 16,
                height: 2.4,
                semanticLabel: 'More options',
                child: SvgPicture.asset(
                  _moreAsset,
                  width: 16,
                  height: 2.4,
                  fit: BoxFit.contain,
                ),
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
                    border: Border.all(
                      color: kProfilePageBackground,
                      width: kProfileAvatarBorder,
                    ),
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

class _ChromeHit extends StatelessWidget {
  const _ChromeHit({
    required this.onPressed,
    required this.width,
    required this.height,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final double width;
  final double height;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(ProfileHero._hitPad),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}

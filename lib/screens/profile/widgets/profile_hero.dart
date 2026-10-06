import 'dart:math' as math;

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

  /// Figma 2650:1894 — 56pt bar; back chevron 9×16.5 at (10, 19.75).
  static const _backWidth = 9.0;
  static const _backHeight = 16.5;

  /// The more icon's artboard is 17×3.4 (three 3.4pt dots). It used to be
  /// drawn into a 16×2.4 box, and because `BoxFit.contain` has to honour
  /// the source aspect it shrank the whole mark to 12×2.4 — dots barely
  /// 2.4pt across, noticeably slighter than the 16.5pt back chevron beside
  /// it. Drawn at 20×4 instead: same 5:1 aspect, so nothing is squashed,
  /// and the dots land at 4pt, which reads at the same weight as the back
  /// arrow.
  static const _moreWidth = 20.0;
  static const _moreHeight = 4.0;

  /// Both marks sit centred on the same line, this far below the
  /// safe-area inset: back is 19.75 + 16.5/2 = 28. Each icon's `top` is
  /// derived from this and its own hit box, so resizing one can't knock it
  /// off the other's baseline.
  static const _chromeCenter = 28.0;

  static const _hitPad = 16.0;

  /// Minimum tappable edge for the chrome buttons. The more icon is only
  /// 4pt tall, so padding alone would leave a 36pt target — under the
  /// platform minimum.
  static const _minHit = 44.0;

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
              top: topInset + _chromeCenter - _ChromeHit.boxFor(_backWidth, _backHeight).height / 2,
              left: kProfileHorizontalPad -
                  (_ChromeHit.boxFor(_backWidth, _backHeight).width -
                          _backWidth) /
                      2,
              child: _ChromeHit(
                onPressed: onBack!,
                width: _backWidth,
                height: _backHeight,
                semanticLabel: 'Back',
                child: SvgPicture.asset(
                  _backAsset,
                  width: _backWidth,
                  height: _backHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (onMore != null)
            Positioned(
              top: topInset +
                  _chromeCenter -
                  _ChromeHit.boxFor(_moreWidth, _moreHeight).height / 2,
              right: kProfileHorizontalPad -
                  (_ChromeHit.boxFor(_moreWidth, _moreHeight).width -
                          _moreWidth) /
                      2,
              child: _ChromeHit(
                onPressed: onMore!,
                width: _moreWidth,
                height: _moreHeight,
                semanticLabel: 'More options',
                child: SvgPicture.asset(
                  _moreAsset,
                  width: _moreWidth,
                  height: _moreHeight,
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

  /// Total tappable box for an icon of [w]×[h]: the icon plus
  /// [ProfileHero._hitPad] on every side, but never below
  /// [ProfileHero._minHit] in either direction. The more icon is 4pt tall,
  /// so padding alone would leave a 36pt-high target.
  static Size boxFor(double w, double h) => Size(
        math.max(w + ProfileHero._hitPad * 2, ProfileHero._minHit),
        math.max(h + ProfileHero._hitPad * 2, ProfileHero._minHit),
      );

  @override
  Widget build(BuildContext context) {
    final box = boxFor(width, height);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: box.width,
          height: box.height,
          // Centred, so the caller can position by the icon's own centre
          // and the box grows symmetrically around it.
          child: Center(
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    );
  }
}

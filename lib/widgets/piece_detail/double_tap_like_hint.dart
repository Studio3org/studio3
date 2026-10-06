import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_fonts.dart';

/// Centered heart + “Double tap to like”; slides up and dismisses.
class DoubleTapLikeHint extends StatelessWidget {
  const DoubleTapLikeHint({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 50),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 38,
      ),
    ]).animate(animation);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: const Offset(0, -0.32),
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return IgnorePointer(
      child: FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: slide,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/piece/like_heart.svg',
                  width: 48,
                  height: 44,
                ),
                const SizedBox(height: 8),
                Text(
                  'Double tap to like',
                  style: AppFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFFAFAF7),
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brief heart burst on the hero after a successful double-tap like.
class DoubleTapLikeBurst extends StatelessWidget {
  const DoubleTapLikeBurst({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(animation);
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 35),
    ]).animate(animation);

    return IgnorePointer(
      child: FadeTransition(
        opacity: opacity,
        child: ScaleTransition(
          scale: scale,
          child: Center(
            child: SvgPicture.asset(
              'assets/piece/like_heart.svg',
              width: 72,
              height: 66,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Gradient + back / bookmark / share / more (Figma 2707:3550).
class PieceHeroOverlay extends StatelessWidget {
  const PieceHeroOverlay({
    super.key,
    required this.saved,
    required this.onBack,
    required this.onSave,
    required this.onShare,
    required this.onMore,
  });

  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: top + 56,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCC231F1B),
              Color(0x00231F1B),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 10),
                _IconTap(
                  width: 24,
                  onTap: onBack,
                  child: SvgPicture.asset(
                    'assets/piece/hero_back.svg',
                    width: 11,
                    height: 20,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 100,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 32,
                        child: GestureDetector(
                          onTap: onSave,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: SvgPicture.asset(
                              saved
                                  ? 'assets/piece/hero_bookmark_fill.svg'
                                  : 'assets/piece/hero_bookmark.svg',
                              width: 16,
                              height: 20,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 38,
                        top: 0,
                        bottom: 0,
                        width: 32,
                        child: GestureDetector(
                          onTap: onShare,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/piece/hero_share.svg',
                              width: 18,
                              height: 22,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 72,
                        top: 0,
                        bottom: 0,
                        width: 28,
                        child: GestureDetector(
                          onTap: onMore,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/piece/hero_more.svg',
                              width: 21,
                              height: 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.onTap,
    required this.child,
    this.width = 28,
  });

  final VoidCallback onTap;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 56,
        child: Center(child: child),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/post_media_assets.dart';
import '../../theme/home_feed_tokens.dart';
import '../../theme/app_fonts.dart';

/// Close / Recents / Next bar (Figma 2757:10777).
class PostingBanner extends StatelessWidget {
  const PostingBanner({
    super.key,
    required this.topInset,
    required this.onClose,
    required this.hasSelection,
    required this.onNext,
    required this.albumName,
    required this.menuOpen,
  });

  static const double height = 53;

  final double topInset;
  final VoidCallback onClose;
  final bool hasSelection;
  final VoidCallback? onNext;
  final String albumName;
  final ValueNotifier<bool> menuOpen;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        PostMediaAssets.closeIcon,
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          HomeFeedTokens.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: hasSelection ? 1 : 0.3,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onNext,
                          child: Text(
                            'Next',
                            style: AppFonts.geist(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: menuOpen,
                  builder: (context, open, _) => GestureDetector(
                    onTap: () => menuOpen.value = !open,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          albumName,
                          style: AppFonts.geist(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: HomeFeedTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: SvgPicture.asset(
                            PostMediaAssets.chevronDown,
                            width: 9,
                            height: 5,
                            colorFilter: const ColorFilter.mode(
                              HomeFeedTokens.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
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

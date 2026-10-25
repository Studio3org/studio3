import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/post_media_assets.dart';
import '../theme/home_feed_tokens.dart';
import '../theme/app_fonts.dart';

/// Bottom sheet shown from the nav + button: Piece vs Scene (Figma 2714:5424).
class PostShareTypeSheet extends StatelessWidget {
  const PostShareTypeSheet({super.key});

  /// Returns `'piece'` or `'scene'`, or null if dismissed.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const PostShareTypeSheet(),
    );
  }

  /// Opens the chooser, then the gallery for the selected type.
  static Future<void> showAndOpenPost(BuildContext context) async {
    final type = await show(context);
    if (type == null || !context.mounted) return;
    await Navigator.pushNamed(context, '/post', arguments: type);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: const Color(0x66231F1B),
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: const _SheetBody(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeFeedTokens.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8C5BC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'What are you sharing?',
                    style: AppFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 23),
              _ShareTypeRow(
                iconAsset: PostMediaAssets.sharePieceIcon,
                title: 'Piece',
                subtitle: 'A finished work, up to 5 angles',
                onTap: () => Navigator.pop(context, 'piece'),
              ),
              const SizedBox(height: 23),
              _ShareTypeRow(
                iconAsset: PostMediaAssets.shareSceneIcon,
                title: 'Scene',
                subtitle: 'One photo or video',
                onTap: () => Navigator.pop(context, 'scene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareTypeRow extends StatelessWidget {
  const _ShareTypeRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 36,
            height: 36,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

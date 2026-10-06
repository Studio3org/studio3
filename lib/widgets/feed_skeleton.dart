import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/explore_tokens.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/image_aspect_ratio_resolver.dart';

/// Wraps a skeleton's placeholder blocks in an animated shimmer sweep —
/// shared by every skeleton below so first-load placeholders read as
/// "loading" rather than a static gray blob.
///
/// [highlightColor] must be visibly lighter than [baseColor] — the sweep
/// reads as a bright highlight crossing the placeholder shape, not a dimmer
/// version of the same faint tint (which just fades toward the page
/// background and stops looking like a shimmer at all).
Widget _shimmer(
  Widget child, {
  required Color baseColor,
  required Color highlightColor,
}) {
  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    period: const Duration(milliseconds: 1400),
    child: child,
  );
}

/// Two-column placeholder grid for feed first paint.
class FeedGridSkeleton extends StatelessWidget {
  const FeedGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.padding,
    this.aspectRatio = 0.75,
    this.color,
  });

  final int crossAxisCount;
  final int itemCount;
  final EdgeInsetsGeometry? padding;
  final double aspectRatio;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? HomeFeedTokens.skeletonBase;
    final highlight =
        color == null ? HomeFeedTokens.skeletonHighlight : Colors.white;

    return _shimmer(
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: HomeFeedTokens.sideMargin),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: aspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
            ),
          );
        },
      ),
      baseColor: fill,
      highlightColor: highlight,
    );
  }
}

/// Single-column placeholder list matching the real "For You" feed card —
/// dynamic-aspect image plus a bottom-left avatar/name overlay — instead of
/// the fixed-aspect two-column [FeedGridSkeleton] shape the feed doesn't
/// actually use.
class FeedListSkeleton extends StatelessWidget {
  const FeedListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final fill = HomeFeedTokens.skeletonBase;
    final overlayFill = Colors.white.withValues(alpha: 0.75);

    Widget line(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: overlayFill,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    Widget card() {
      return AspectRatio(
        aspectRatio: ImageAspectRatioResolver.portrait3x4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: HomeFeedTokens.avatarSize,
                    height: HomeFeedTokens.avatarSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: overlayFill,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        line(80, 10),
                        const SizedBox(height: 6),
                        line(56, 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _shimmer(
      ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: HomeFeedTokens.sideMargin,
        ),
        itemCount: itemCount,
        separatorBuilder: (_, __) =>
            const SizedBox(height: HomeFeedTokens.rowGap),
        itemBuilder: (_, __) => card(),
      ),
      baseColor: fill,
      highlightColor: HomeFeedTokens.skeletonHighlight,
    );
  }
}

/// Explore-style masonry placeholders (two columns, mixed heights).
class ExploreFeedSkeleton extends StatelessWidget {
  const ExploreFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = ExploreTokens.skeleton;

    Widget tile(double aspect) {
      return AspectRatio(
        aspectRatio: aspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(ExploreTokens.tileRadius),
          ),
        ),
      );
    }

    return _shimmer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: ExploreTokens.sideMargin),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      tile(3 / 4),
                      const SizedBox(height: ExploreTokens.gutter),
                      tile(1),
                    ],
                  ),
                ),
                const SizedBox(width: ExploreTokens.gutter),
                Expanded(
                  child: Column(
                    children: [
                      tile(1),
                      const SizedBox(height: ExploreTokens.gutter),
                      tile(3 / 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ExploreTokens.blockGap),
            tile(16 / 9),
          ],
        ),
      ),
      baseColor: fill,
      highlightColor: ExploreTokens.skeletonHighlight,
    );
  }
}

/// Profile tab grid placeholders.
class ProfileGridSkeleton extends StatelessWidget {
  const ProfileGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = HomeFeedTokens.skeletonBase;

    Widget tile(double height) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return _shimmer(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                tile(180),
                const SizedBox(height: 8),
                tile(120),
                const SizedBox(height: 8),
                tile(200),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                tile(140),
                const SizedBox(height: 8),
                tile(220),
                const SizedBox(height: 8),
                tile(130),
              ],
            ),
          ),
        ],
      ),
      baseColor: fill,
      highlightColor: HomeFeedTokens.skeletonHighlight,
    );
  }
}

/// Full-bleed placeholder for Reels' first paint, before the first video is
/// ready — shown in place of a bare spinner over black.
class ReelSkeleton extends StatelessWidget {
  const ReelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const fill = Color(0x14FFFFFF);
    const highlight = Color(0x33FFFFFF);
    return _shimmer(
      const DecoratedBox(decoration: BoxDecoration(color: fill)),
      baseColor: fill,
      highlightColor: highlight,
    );
  }
}

/// Placeholder rows for card-list screens (Notifications / Requests / Chats)
/// — a leading avatar circle plus two text-bar "lines", matching the
/// [GlassCard] row shape those lists render once loaded.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const fill = HomeFeedTokens.skeletonBase;
    final overlayFill = Colors.white.withValues(alpha: 0.75);

    Widget row() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(HomeFeedTokens.cardRadius),
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: overlayFill, shape: BoxShape.circle),
              child: const SizedBox(width: 40, height: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: overlayFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: overlayFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _shimmer(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              row(),
              if (i != itemCount - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      baseColor: fill,
      highlightColor: HomeFeedTokens.skeletonHighlight,
    );
  }
}

/// Placeholder rows for card-list screens (Notifications / Requests / Chats),
/// styled to match [SettingsListSkeleton]'s flat look — a leading avatar
/// circle plus two text-bar "lines" sitting directly on the page background,
/// with no solid card block behind each row (unlike [ListRowSkeleton], which
/// mimics the real [GlassCard] row's opaque background).
class FlatListRowSkeleton extends StatelessWidget {
  const FlatListRowSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const fill = HomeFeedTokens.skeletonBase;

    Widget row() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: fill, shape: BoxShape.circle),
              child: const SizedBox(width: 44, height: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _shimmer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [for (var i = 0; i < itemCount; i++) row()],
        ),
      ),
      baseColor: fill,
      highlightColor: HomeFeedTokens.skeletonHighlight,
    );
  }
}

/// Placeholder for Profile Settings' first load — section-header bars
/// followed by [SettingsTile]-shaped rows (icon circle + text bar +
/// trailing blob), so the page reads as "loading settings" instead of a
/// full-screen logo overlay.
class SettingsListSkeleton extends StatelessWidget {
  const SettingsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const fill = HomeFeedTokens.skeletonBase;

    Widget sectionHeader() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
        child: Container(
          width: 72,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    Widget tileRow({double labelWidth = 140}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: const SizedBox(width: 22, height: 22),
            ),
            const SizedBox(width: 14),
            Container(
              width: labelWidth,
              height: 14,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    Widget section(int rows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(),
          for (var i = 0; i < rows; i++)
            tileRow(labelWidth: 120 + (i * 37) % 80),
        ],
      );
    }

    return _shimmer(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section(3),
            section(4),
            section(3),
            section(2),
          ],
        ),
      ),
      baseColor: fill,
      highlightColor: HomeFeedTokens.skeletonHighlight,
    );
  }
}

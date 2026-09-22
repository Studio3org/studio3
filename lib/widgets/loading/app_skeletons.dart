/// Shared, page-shaped placeholders built from [SkeletonBox] & friends.
///
/// Every one of these stands in for a *single backend-dependent section*.
/// None of them include chrome (app bars, tabs, headings, actions) — that
/// is static and must already be on screen behind them.
library;

import 'package:flutter/material.dart';

import '../../theme/home_feed_tokens.dart';
import 'skeleton_primitives.dart';

/// Stacked "card" rows — the shape of the GlassCard lists used by Orders,
/// Sales, Addresses, Reports, Blocked accounts and Inquiries.
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({
    super.key,
    this.itemCount = 5,
    this.height = 92,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.gap = 12,
  });

  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (_, _) => SkeletonBox(
          height: height,
          radius: HomeFeedTokens.cardRadius,
        ),
      ),
    );
  }
}

/// Avatar + two text lines per row, sitting directly on the page
/// background — used by follower/following lists, people pickers and any
/// other "list of accounts" section.
class UserListSkeleton extends StatelessWidget {
  const UserListSkeleton({
    super.key,
    this.itemCount = 7,
    this.padding = const EdgeInsets.all(16),
    this.trailingAction = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  /// Adds a pill placeholder on the right, matching rows that carry a
  /// Follow / Unblock / Select control.
  final bool trailingAction;

  @override
  Widget build(BuildContext context) {
    Widget row(int i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SkeletonCircle(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonLine(width: 120 + (i * 29) % 70),
                  const SizedBox(height: 8),
                  SkeletonLine(width: 70 + (i * 17) % 50, height: 10),
                ],
              ),
            ),
            if (trailingAction) ...[
              const SizedBox(width: 12),
              const SkeletonBox(width: 84, height: 32, radius: 16),
            ],
          ],
        ),
      );
    }

    return SkeletonShimmer(
      child: Padding(
        padding: padding,
        child: Column(
          children: [for (var i = 0; i < itemCount; i++) row(i)],
        ),
      ),
    );
  }
}

/// Label + input-field pairs — the shape of a form whose current values are
/// still being fetched (Edit profile, Series editor, Payout setup).
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({
    super.key,
    this.fieldCount = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.leading,
  });

  final int fieldCount;
  final EdgeInsetsGeometry padding;

  /// Optional placeholder rendered above the fields (e.g. an avatar or a
  /// cover image block).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(height: 28)],
            for (var i = 0; i < fieldCount; i++) ...[
              SkeletonLine(width: 80 + (i * 23) % 60, height: 11),
              const SizedBox(height: 10),
              const SkeletonBox(height: 48, radius: 12),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header block plus stacked info cards — the shape of a single-record
/// detail screen (Order detail, Event detail) while the record loads.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.cardCount = 3,
    this.heroAspectRatio,
  });

  final EdgeInsetsGeometry padding;
  final int cardCount;

  /// When set, a full-width media block of this ratio leads the layout.
  final double? heroAspectRatio;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heroAspectRatio != null) ...[
              AspectRatio(
                aspectRatio: heroAspectRatio!,
                child: const SkeletonBox(radius: HomeFeedTokens.cardRadius),
              ),
              const SizedBox(height: 20),
            ],
            const SkeletonLine(width: 180, height: 18),
            const SizedBox(height: 10),
            const SkeletonLine(width: 110, height: 12),
            const SizedBox(height: 24),
            for (var i = 0; i < cardCount; i++) ...[
              SkeletonBox(
                height: 96 + (i * 21) % 48,
                radius: HomeFeedTokens.cardRadius,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alternating incoming/outgoing bubbles — stands in for a conversation
/// whose history is still loading.
class ChatThreadSkeleton extends StatelessWidget {
  const ChatThreadSkeleton({super.key, this.itemCount = 7});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const widths = [180.0, 120.0, 220.0, 96.0, 160.0, 200.0, 140.0];

    Widget bubble(int i) {
      final mine = i.isOdd;
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: SkeletonBox(
          width: widths[i % widths.length],
          height: 38 + (i % 3) * 14,
          radius: 18,
        ),
      );
    }

    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => bubble(i),
      ),
    );
  }
}

/// Fixed-aspect tiles in a grid — used by media/piece pickers and any
/// square-ish thumbnail section.
class TileGridSkeleton extends StatelessWidget {
  const TileGridSkeleton({
    super.key,
    this.crossAxisCount = 3,
    this.itemCount = 9,
    this.aspectRatio = 1,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 8,
    this.radius = 12,
  });

  final int crossAxisCount;
  final int itemCount;
  final double aspectRatio;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => SkeletonBox(radius: radius),
      ),
    );
  }
}

/// A single full-width hero/banner block — for a lead card that is still
/// being fetched while the rest of the page is already interactive.
class HeroBlockSkeleton extends StatelessWidget {
  const HeroBlockSkeleton({
    super.key,
    this.aspectRatio = 16 / 9,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final double aspectRatio;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: padding,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: const SkeletonBox(radius: HomeFeedTokens.cardRadius),
        ),
      ),
    );
  }
}

/// Stacked comment rows — avatar, author line, body lines.
class CommentListSkeleton extends StatelessWidget {
  const CommentListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    Widget row(int i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonCircle(size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonLine(width: 90 + (i * 19) % 50, height: 11),
                  const SizedBox(height: 8),
                  const SkeletonLine(height: 10),
                  if (i.isEven) ...[
                    const SizedBox(height: 6),
                    SkeletonLine(width: 160 + (i * 31) % 80, height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [for (var i = 0; i < itemCount; i++) row(i)],
        ),
      ),
    );
  }
}

/// Selectable option rows (payment cards, shipping methods, series) — a
/// leading radio dot, a label line and an optional trailing value.
class OptionListSkeleton extends StatelessWidget {
  const OptionListSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget row(int i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SkeletonCircle(size: 20),
            const SizedBox(width: 14),
            Expanded(child: SkeletonLine(width: 140 + (i * 27) % 70)),
            const SizedBox(width: 12),
            const SkeletonLine(width: 48, height: 12),
          ],
        ),
      );
    }

    return SkeletonShimmer(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < itemCount; i++) row(i)],
        ),
      ),
    );
  }
}

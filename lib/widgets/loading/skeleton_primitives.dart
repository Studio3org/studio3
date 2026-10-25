/// # Smart loading standard
///
/// One rule governs every loading state in the app:
///
/// > **A skeleton may only ever stand in for content that is genuinely
/// > waiting on a backend response, and only while there is nothing to
/// > show in its place.**
///
/// Concretely:
///
/// * **Static / local content paints immediately.** App bars, titles, tab
///   bars, filter chips, section headings, icons, buttons, and anything
///   already in local state or cache are built on the very first frame.
///   They are never wrapped in a skeleton and never sit behind a
///   full-screen loading gate.
/// * **Skeletons are section-scoped.** Each independently-fetched section
///   owns its own placeholder. One slow request never blanks the rest of
///   the screen — sections that already have data keep rendering it.
/// * **Cache wins over skeletons.** If a screen can seed itself from
///   `CacheService.peekCache` (or any in-memory store), it renders that
///   content on the first frame and refreshes silently in the background.
///   Revisiting a screen must never flash a skeleton over content the user
///   has already seen.
/// * **Refresh is silent.** Pull-to-refresh, background revalidation and
///   pagination use the platform refresh indicator or an inline footer
///   spinner — never a skeleton that replaces visible content.
/// * **Full-screen blocking overlays are for mutations only.** A
///   `StudioLoadingGate` is legitimate while a submit/publish/upload is in
///   flight (the user must not interact with the form), and illegitimate
///   as a wrapper around an initial GET.
///
/// [SectionLoader] encodes the read path of this rule; the primitives below
/// are the building blocks every skeleton in the app is composed from, so
/// placeholders share one shimmer timing, one base colour and one corner
/// radius language.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/home_feed_tokens.dart';

/// Shared shimmer sweep for every skeleton in the app.
///
/// [highlight] must read as visibly lighter than [base], otherwise the
/// sweep fades toward the page background and stops looking like motion.
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.base = HomeFeedTokens.skeletonBase,
    this.highlight = HomeFeedTokens.skeletonHighlight,
    this.period = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Color base;
  final Color highlight;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: period,
        direction: ShimmerDirection.ltr,
        child: child,
      ),
    );
  }
}

/// Rounded placeholder block — the atom every skeleton shape is built from.
///
/// Always render inside a [SkeletonShimmer]; on its own it is a static grey
/// box, which reads as broken content rather than as loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.color = HomeFeedTokens.skeletonBase,
  });

  final double? width;
  final double? height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Text-line placeholder — a [SkeletonBox] with type-like proportions.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.color = HomeFeedTokens.skeletonBase,
  });

  final double? width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      radius: 4,
      color: color,
    );
  }
}

/// Avatar / icon placeholder.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    required this.size,
    this.color = HomeFeedTokens.skeletonBase,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

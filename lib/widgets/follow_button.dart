import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Follow relationship from the viewer to a profile/artist — a private
/// account yields [pending] instead of jumping straight to [following].
enum FollowState { none, pending, following }

/// Shared Follow/Following/Requested pill button used on the artist profile
/// page and on piece/scene detail pages.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.state,
    this.onPressed,
    this.dense = false,
    this.busy = false,
    this.figmaDetail = false,
  });

  final FollowState state;
  final VoidCallback? onPressed;

  /// Compact sizing for tight horizontal rows (e.g. piece/scene artist rows),
  /// as opposed to the larger standalone pill on the profile header.
  final bool dense;

  /// Shows a spinner in place of the label and refuses taps — set while a
  /// follow/unfollow request is in flight (e.g. `DetailFollowState.followBusy`).
  final bool busy;

  /// Figma 2707:3564 — 96×28, 6px radius, outlined Follow, Geist 12.
  final bool figmaDetail;

  @override
  Widget build(BuildContext context) {
    final outlined = figmaDetail || state != FollowState.none;
    final label = switch (state) {
      FollowState.none => 'Follow',
      FollowState.pending => 'Requested',
      FollowState.following => 'Following',
    };
    final labelColor = figmaDetail
        ? HomeFeedTokens.neutral800.withValues(
            alpha: state == FollowState.pending ? 0.7 : 1,
          )
        : outlined
            ? HomeFeedTokens.textPrimary.withValues(
                alpha: state == FollowState.pending ? 0.7 : 1,
              )
            : HomeFeedTokens.textInverse;
    final spinnerSize = dense || figmaDetail ? 14.0 : 16.0;
    final radius = figmaDetail ? 6.0 : HomeFeedTokens.cardRadius;

    final child = Material(
      color: outlined ? Colors.transparent : HomeFeedTokens.textPrimary,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: outlined
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: figmaDetail
                        ? HomeFeedTokens.neutral800
                        : HomeFeedTokens.textPrimary.withValues(
                            alpha: state == FollowState.pending ? 0.2 : 0.35,
                          ),
                  ),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: figmaDetail
                ? EdgeInsets.zero
                : dense
                    ? const EdgeInsets.symmetric(vertical: 4, horizontal: 14)
                    : const EdgeInsets.symmetric(vertical: 6, horizontal: 28),
            child: Center(
              widthFactor: figmaDetail ? null : 1,
              child: busy
                  ? SizedBox(
                      width: spinnerSize,
                      height: spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: labelColor,
                      ),
                    )
                  : Text(
                      label,
                      style: figmaDetail
                          ? GoogleFonts.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: labelColor,
                            )
                          : GoogleFonts.inter(
                              fontSize: dense ? 12 : 15,
                              fontWeight:
                                  dense ? FontWeight.w500 : FontWeight.w600,
                              color: labelColor,
                            ),
                    ),
            ),
          ),
        ),
      ),
    );

    if (!figmaDetail) return child;
    return SizedBox(width: 96, height: 28, child: child);
  }
}

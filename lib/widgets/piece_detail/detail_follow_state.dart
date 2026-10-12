import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../services/social_service.dart';
import '../../utils/require_login.dart';
import '../follow_button.dart';

/// Shared follow-toggle wiring for piece/scene detail pages, mirroring
/// ProfilePage's `_toggleFollow` (busy-guard, optimistic update, error
/// SnackBar) against the same [SocialService] follow/unfollow endpoints.
mixin DetailFollowState<T extends StatefulWidget> on State<T> {
  FollowState followState = FollowState.none;
  bool followBusy = false;

  /// The artist's username (without a leading '@') to follow/unfollow.
  String get followUsername;

  void applyFollowState(FeedPreviewItem item) {
    if (!mounted) return;
    setState(() {
      followState =
          item.authorIsFollowing ? FollowState.following : FollowState.none;
    });
  }

  Future<void> toggleFollow() async {
    if (followBusy || followUsername.isEmpty) return;
    if (!await requireLogin(
      context,
      message: 'Log in or create a free account to follow artists.',
    )) {
      return;
    }
    if (!mounted) return;
    final wasFollowingOrPending = followState != FollowState.none;
    setState(() => followBusy = true);
    try {
      if (wasFollowingOrPending) {
        await SocialService.instance.unfollow(followUsername);
        if (!mounted) return;
        setState(() => followState = FollowState.none);
      } else {
        final result = await SocialService.instance.follow(followUsername);
        if (!mounted) return;
        setState(() {
          followState = result.following
              ? FollowState.following
              : (result.requested ? FollowState.pending : FollowState.none);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }
}

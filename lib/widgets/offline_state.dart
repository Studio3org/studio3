import 'package:flutter/material.dart';

import 'studio/studio_empty_state.dart';

/// Shown instead of an indefinite spinner when a screen has no cached
/// data and no network connection to fetch fresh data with. The shared empty state (grey
/// mark, title, line) with Try again.
class OfflineState extends StatelessWidget {
  const OfflineState({
    super.key,
    this.message = "You're offline",
    this.detail = 'Connect to the internet to load this content.',
    this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: StudioEmptyState(
          title: message,
          message: detail,
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}

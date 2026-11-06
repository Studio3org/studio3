import 'package:flutter/material.dart';

import '../models/follow_request.dart';
import '../widgets/inbox/follow_requests_body.dart';
import '../widgets/studio/studio.dart';

/// Follow requests (`SettingsFollowRequests`, Flow 12), opened from Privacy: newest first, each
/// with Approve (they follow you and are told) and Decline (quiet; they can ask again), and
/// "They aren't told if you decline." under the rows. The list is the inbox's Requests tab in
/// its Settings look ([FollowRequestsBody.settings]).
class FollowRequestsPage extends StatelessWidget {
  const FollowRequestsPage({super.key, this.debugRequests});

  /// For tests: the requests instead of loading them.
  @visibleForTesting
  final List<FollowRequest>? debugRequests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(context: context, title: 'Follow requests'),
      body: FollowRequestsBody(settings: true, debugRequests: debugRequests),
    );
  }
}

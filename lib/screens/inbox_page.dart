import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/social_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/create_flow/post_flow_widgets.dart' show PostIconButton;
import '../widgets/inbox/chats_body.dart';
import 'new_message_page.dart';
import '../widgets/inbox/follow_requests_body.dart';
import '../widgets/inbox/notifications_body.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_tab_bar.dart';

enum InboxTab { notifications, chats, requests }

/// Inbox (`NotifActivity`): opened from the home top bar's inbox icon (and from Profile
/// Settings' Notifications / Follow requests links).
///
/// Back and "Inbox" 16/500; Activity, Messages and Requests as the boards' tabs, Messages
/// and Requests with a Mono count when there is one. Requests is the app's follow requests
/// (kept; the board draws two tabs). No settings icon: notification settings live in
/// Profile settings.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key, this.initialTab = InboxTab.notifications});

  final InboxTab initialTab;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: InboxTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  int _chatsCount = 0;
  int _requestsCount = 0;
  final _chatsKey = GlobalKey<ChatsBodyState>();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
    _refreshCounts();
  }

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  /// The + on the Messages tab (`NotifMessages`): New message, with the people already in
  /// the inbox as Recent.
  Future<void> _newMessage() async {
    final recent = [
      for (final c in _chatsKey.currentState?.conversations ?? const [])
        if (c.otherPartyUsername != null && c.status != 'pending')
          MessageContact(
            username: c.otherPartyUsername!,
            name: c.otherPartyDisplayName,
            avatarUrl: c.otherPartyAvatarUrl,
          ),
    ];
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => NewMessagePage(recent: recent)),
    );
    _refreshCounts();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final results = await Future.wait<int>([
      SocialService.instance
          .listFollowRequests()
          .then((requests) => requests.length)
          .catchError((_) => _requestsCount),
      ChatService.instance.unreadCount().catchError((_) => _chatsCount),
    ]);
    if (!mounted) return;
    setState(() {
      _requestsCount = results[0];
      _chatsCount = results[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  PostIconButton(
                    icon: StudioIcons.backBold,
                    label: 'Back',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Inbox',
                      textAlign: TextAlign.center,
                      style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                    ),
                  ),
                  if (_tabs.index == InboxTab.chats.index)
                    PostIconButton(
                      icon: StudioIcons.newFolder,
                      label: 'New message',
                      onTap: _newMessage,
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            StudioTabBar(
              controller: _tabs,
              labels: const ['Activity', 'Messages', 'Requests'],
              counts: [null, _chatsCount, _requestsCount],
              ruleFullWidth: true,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  NotificationsBody(onLiveNotification: () {}),
                  ChatsBody(
                    key: _chatsKey,
                    onCountsChanged: _refreshCounts,
                    onNewMessage: _newMessage,
                  ),
                  const FollowRequestsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

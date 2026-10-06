import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/snappy_page_physics.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/inbox/chats_body.dart';
import '../widgets/inbox/follow_requests_body.dart';
import '../widgets/inbox/notifications_body.dart';

enum InboxTab { notifications, chats, requests }

/// Full-page Inbox — opened from the Home feed's inbox icon (and from
/// Profile Settings' Notifications / Follow requests links). Styled like
/// Home: a top bar with a centered switcher between the three sections,
/// instead of the popup menu this used to be.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key, this.initialTab = InboxTab.notifications});

  final InboxTab initialTab;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late InboxTab _activeTab = widget.initialTab;
  late final PageController _pageController = PageController(
    initialPage: widget.initialTab.index,
  );

  int _notificationsCount = 0;
  int _chatsCount = 0;
  int _requestsCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final results = await Future.wait<int>([
      NotificationService.instance
          .getUnreadCount()
          .catchError((_) => _notificationsCount),
      SocialService.instance
          .listFollowRequests()
          .then((requests) => requests.length)
          .catchError((_) => _requestsCount),
      ChatService.instance
          .unreadCount()
          .catchError((_) => _chatsCount),
    ]);
    if (!mounted) return;
    setState(() {
      _notificationsCount = results[0];
      _requestsCount = results[1];
      _chatsCount = results[2];
    });
  }

  void _onTabChanged(InboxTab tab) {
    if (_activeTab == tab) return;
    _pageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    final tab = InboxTab.values[index];
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
  }

  Widget _tab({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required int count,
  }) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FeedFilterTab(
                label: label,
                active: active,
                onTap: onTap,
                underline: false,
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                _CountBadge(count: count),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 1.5,
            color: active ? HomeFeedTokens.textPrimary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: HomeFeedTokens.textPrimary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tab(
                              label: 'Notifications',
                              active: _activeTab == InboxTab.notifications,
                              onTap: () =>
                                  _onTabChanged(InboxTab.notifications),
                              count: _notificationsCount,
                            ),
                            const SizedBox(width: 24),
                            _tab(
                              label: 'Chats',
                              active: _activeTab == InboxTab.chats,
                              onTap: () => _onTabChanged(InboxTab.chats),
                              count: _chatsCount,
                            ),
                            const SizedBox(width: 24),
                            _tab(
                              label: 'Requests',
                              active: _activeTab == InboxTab.requests,
                              onTap: () => _onTabChanged(InboxTab.requests),
                              count: _requestsCount,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const SnappyPageScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  NotificationsBody(onLiveNotification: _onLiveNotification),
                  ChatsBody(onCountsChanged: _refreshCounts),
                  const FollowRequestsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLiveNotification() {
    if (!mounted) return;
    setState(() => _notificationsCount += 1);
  }
}

/// Small red Android-style count bubble — matches the badge on the Home
/// feed's inbox icon (`home_feed_widgets.dart`), used here on each tab
/// instead of appending "(count)" to the label text.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFE05252),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

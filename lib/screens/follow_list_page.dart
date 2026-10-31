import 'package:flutter/material.dart';

import '../models/follow_user_summary.dart';
import '../services/api_exception.dart';
import '../services/social_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_avatar.dart';
import '../widgets/studio/studio_empty_state.dart';
import '../widgets/studio/studio_tab_bar.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../utils/profile_navigation.dart';
import '../widgets/offline_state.dart';
import 'profile/widgets/profile_locked_placeholder.dart';

enum FollowListTab { followers, following }

/// Followers/following list for a profile — opened to whichever stat was
/// tapped, with the other tab a swipe/tap away.
///
/// No board: the tabs are the profile boards' section tabs and each person is a
/// `NewMessage` row (44 avatar, name 15/500, handle 12).
class FollowListPage extends StatelessWidget {
  const FollowListPage({
    super.key,
    required this.username,
    this.initialTab = FollowListTab.followers,
  });

  final String username;
  final FollowListTab initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == FollowListTab.following ? 1 : 0,
      child: Scaffold(
        backgroundColor: context.studio.background,
        appBar: StudioTopBar(
          context: context,
          title: '@$username',
          bottom: const StudioTabBar(labels: ['Followers', 'Following']),
        ),
        body: TabBarView(
          children: [
            _FollowListTabView(
              username: username,
              fetchPage: ({cursor}) =>
                  SocialService.instance.listFollowers(username, cursor: cursor),
              emptyMessage: 'No followers yet',
            ),
            _FollowListTabView(
              username: username,
              fetchPage: ({cursor}) =>
                  SocialService.instance.listFollowing(username, cursor: cursor),
              emptyMessage: 'Not following anyone yet',
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowListTabView extends StatefulWidget {
  const _FollowListTabView({
    required this.username,
    required this.fetchPage,
    required this.emptyMessage,
  });

  final String username;
  final Future<FollowUserPage> Function({String? cursor}) fetchPage;
  final String emptyMessage;

  @override
  State<_FollowListTabView> createState() => _FollowListTabViewState();
}

class _FollowListTabViewState extends State<_FollowListTabView> {
  final _scrollController = ScrollController();
  final _items = <FollowUserSummary>[];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _locked = false;
  bool _showOfflineState = false;

  bool get _hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _locked = false;
      _showOfflineState = false;
    });
    try {
      final page = await widget.fetchPage();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _locked = e is ApiException && e.statusCode == 403;
        _showOfflineState = !_locked && _items.isEmpty;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await widget.fetchPage(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // Pagination failure just stops loading further pages.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) return const ProfileLockedPlaceholder();
    if (_showOfflineState) return OfflineState(onRetry: _load);
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return Center(child: StudioEmptyState(title: widget.emptyMessage));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final user = _items[index];
          return FollowUserRow(user: user, onTap: () => openUserProfile(context, user.username));
        },
      ),
    );
  }
}

/// One person in the list (`NewMessage` row): 44 avatar, 12 gap, name 15/500 over
/// handle 12 Graphite, 10 above and below.
class FollowUserRow extends StatelessWidget {
  const FollowUserRow({super.key, required this.user, required this.onTap});

  final FollowUserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            StudioAvatar(url: user.profilePhotoUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.caption12(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/follow_user_summary.dart';
import '../services/api_exception.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/profile_navigation.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/offline_state.dart';
import 'profile/widgets/profile_locked_placeholder.dart';

enum FollowListTab { followers, following }

/// Instagram-style followers/following list for a profile — opened to
/// whichever stat was tapped, with the other tab a swipe/tap away.
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
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            '@$username',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          bottom: TabBar(
            labelColor: HomeFeedTokens.textPrimary,
            unselectedLabelColor: HomeFeedTokens.textSecondary,
            indicatorColor: HomeFeedTokens.textPrimary,
            labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowListTabView(
              username: username,
              fetchPage: ({cursor}) => SocialService.instance
                  .listFollowers(username, cursor: cursor),
              emptyMessage: 'No followers yet',
            ),
            _FollowListTabView(
              username: username,
              fetchPage: ({cursor}) => SocialService.instance
                  .listFollowing(username, cursor: cursor),
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
      return Center(
        child: Text(
          widget.emptyMessage,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => openUserProfile(context, user.username),
              behavior: HitTestBehavior.opaque,
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    UserAvatar(url: user.profilePhotoUrl, name: user.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HomeFeedTokens.textPrimary,
                            ),
                          ),
                          Text(
                            '@${user.username}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

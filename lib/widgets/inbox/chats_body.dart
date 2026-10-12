import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/chat_message.dart';
import '../../models/follow_user_summary.dart';
import '../../screens/conversation_thread_page.dart';
import '../../services/auth_session.dart';
import '../../services/chat_service.dart';
import '../../services/social_service.dart';
import '../../theme/app_theme.dart';
import '../accept_decline_buttons.dart';
import '../feed_skeleton.dart';
import '../glass_card.dart';
import '../home_feed/home_feed_widgets.dart';

enum _ChatsTab { all, requests }

/// Chats list content for the Inbox page's "Chats" tab — extracted from the
/// former standalone DirectMessagesPage, minus its own back-button header.
/// Keeps its own internal All/Requests sub-switcher, plus a search bar that
/// looks up people from the user's own following/followers lists to start
/// or jump back into a conversation with them.
class ChatsBody extends StatefulWidget {
  const ChatsBody({super.key, this.onCountsChanged});

  /// Called after opening/returning from a thread so the parent can refresh badges.
  final VoidCallback? onCountsChanged;

  @override
  State<ChatsBody> createState() => _ChatsBodyState();
}

class _ChatsBodyState extends State<ChatsBody> {
  _ChatsTab _activeTab = _ChatsTab.all;

  final List<ConversationSummary> _conversations = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;

  final List<ConversationSummary> _requests = [];
  bool _requestsLoading = true;
  bool _requestsLoaded = false;
  bool _requestsLoadingMore = false;
  String? _requestsNextCursor;
  final Set<String> _requestBusy = {};

  final _scrollController = ScrollController();

  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<FollowUserSummary>? _connections;
  bool _connectionsLoading = false;

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });
    try {
      final page = await ChatService.instance.getInbox(
        cursor: append ? _nextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _conversations.addAll(page.items);
        } else {
          _conversations
            ..clear()
            ..addAll(page.items);
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) _conversations.clear();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadRequests({bool append = false}) async {
    if (append && (_requestsNextCursor == null || _requestsNextCursor!.isEmpty)) {
      return;
    }
    setState(() {
      if (append) {
        _requestsLoadingMore = true;
      } else {
        _requestsLoading = true;
      }
    });
    try {
      final page = await ChatService.instance.listRequests(
        cursor: append ? _requestsNextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _requests.addAll(page.items);
        } else {
          _requests
            ..clear()
            ..addAll(page.items);
        }
        _requestsNextCursor = page.nextCursor;
        _requestsLoading = false;
        _requestsLoadingMore = false;
        _requestsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) _requests.clear();
        _requestsLoading = false;
        _requestsLoadingMore = false;
        _requestsLoaded = true;
      });
    }
  }

  /// Fetches the caller's own following + followers once (lazily, on first
  /// search) and merges them by username — this is what the search bar
  /// filters, not every user on the app and not the conversation list.
  Future<void> _ensureConnectionsLoaded() async {
    if (_connections != null || _connectionsLoading) return;
    setState(() => _connectionsLoading = true);
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) {
      if (!mounted) return;
      setState(() {
        _connections = const [];
        _connectionsLoading = false;
      });
      return;
    }
    try {
      final pages = await Future.wait([
        SocialService.instance.listFollowing(username),
        SocialService.instance.listFollowers(username),
      ]);
      if (!mounted) return;
      final byUsername = <String, FollowUserSummary>{};
      for (final page in pages) {
        for (final user in page.items) {
          byUsername[user.username] = user;
        }
      }
      setState(() {
        _connections = byUsername.values.toList();
        _connectionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connections = const [];
        _connectionsLoading = false;
      });
    }
  }

  void _onSearchQueryChanged(String value) {
    final query = value.trim();
    setState(() => _searchQuery = query);
    if (query.isNotEmpty) _ensureConnectionsLoaded();
  }

  List<FollowUserSummary> get _filteredConnections {
    final connections = _connections;
    if (connections == null || _searchQuery.isEmpty) return const [];
    final q = _searchQuery.toLowerCase();
    return connections
        .where((user) =>
            user.name.toLowerCase().contains(q) ||
            user.username.toLowerCase().contains(q))
        .toList();
  }

  void _onTabChanged(_ChatsTab tab) {
    setState(() => _activeTab = tab);
    if (tab == _ChatsTab.requests && !_requestsLoaded) _loadRequests();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 200) return;
    if (_activeTab == _ChatsTab.all) {
      if (_loadingMore) return;
      if (_nextCursor == null || _nextCursor!.isEmpty) return;
      _load(append: true);
    } else {
      if (_requestsLoadingMore) return;
      if (_requestsNextCursor == null || _requestsNextCursor!.isEmpty) return;
      _loadRequests(append: true);
    }
  }

  Future<void> _openThreadWithUser(FollowUserSummary user) async {
    // Prefer an already-loaded inbox/request row so we open with history
    // immediately; ConversationThreadPage also resolves via API as a fallback.
    ConversationSummary? existing;
    for (final c in _conversations) {
      if (c.otherPartyUsername == user.username) {
        existing = c;
        break;
      }
    }
    if (existing == null) {
      for (final c in _requests) {
        if (c.otherPartyUsername == user.username) {
          existing = c;
          break;
        }
      }
    }

    if (existing != null) {
      await _openThread(existing, isRequest: existing.status == 'pending');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationThreadPage(
          otherPartyUsername: user.username,
          otherPartyName: user.name,
          otherPartyAvatarUrl: user.profilePhotoUrl,
        ),
      ),
    );
    _load();
    widget.onCountsChanged?.call();
  }

  Future<void> _openThread(ConversationSummary conversation, {required bool isRequest}) async {
    // Optimistic: clear unread dot immediately when opening.
    if (conversation.unread) {
      setState(() {
        final list = isRequest ? _requests : _conversations;
        final i = list.indexWhere((c) => c.id == conversation.id);
        if (i != -1) list[i] = list[i].copyWith(unread: false);
      });
      widget.onCountsChanged?.call();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationThreadPage(
          conversationId: conversation.id,
          otherPartyId: conversation.otherPartyId,
          otherPartyUsername: conversation.otherPartyUsername,
          otherPartyName: conversation.otherPartyDisplayName,
          otherPartyAvatarUrl: conversation.otherPartyAvatarUrl,
          initialStatus: conversation.status,
        ),
      ),
    );
    // Refresh both lists on return — accept/decline/read may have changed status.
    _load();
    if (_requestsLoaded) _loadRequests();
    widget.onCountsChanged?.call();
  }

  Future<void> _acceptRequest(ConversationSummary request) async {
    setState(() => _requestBusy.add(request.id));
    try {
      await ChatService.instance.acceptRequest(request.id);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
        _conversations.insert(0, request.copyWith(status: 'open'));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestBusy.remove(request.id));
    }
  }

  Future<void> _declineRequest(ConversationSummary request) async {
    setState(() => _requestBusy.add(request.id));
    try {
      await ChatService.instance.declineRequest(request.id);
    } catch (_) {
      // Treat as handled either way.
    } finally {
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
          _requestBusy.remove(request.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchQueryChanged,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
            decoration: InputDecoration(
              hintText: 'Search your connections',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              FeedFilterTab(
                label: 'All',
                active: _activeTab == _ChatsTab.all,
                onTap: () => _onTabChanged(_ChatsTab.all),
              ),
              const SizedBox(width: 24),
              FeedFilterTab(
                label: _requests.isEmpty
                    ? 'Requests'
                    : 'Requests (${_requests.length})',
                active: _activeTab == _ChatsTab.requests,
                onTap: () => _onTabChanged(_ChatsTab.requests),
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildConnectionsSearchBody()
              : (_activeTab == _ChatsTab.all
                  ? _buildAllBody()
                  : _buildRequestsBody()),
        ),
      ],
    );
  }

  Widget _buildConnectionsSearchBody() {
    if (_connectionsLoading && _connections == null) {
      return const FlatListRowSkeleton();
    }
    final results = _filteredConnections;
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No matches in your connections',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final user = results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openThreadWithUser(user),
              borderRadius: BorderRadius.circular(AppDims.radiusMd),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    UserAvatar(
                      url: user.profilePhotoUrl,
                      name: user.name,
                      size: 48,
                    ),
                    const SizedBox(width: AppDims.spaceSm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate900,
                            ),
                          ),
                          Text(
                            '@${user.username}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
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
          ),
        );
      },
    );
  }

  Widget _buildAllBody() {
    if (_loading) {
      return const FlatListRowSkeleton();
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.slate200),
            const SizedBox(height: AppDims.spaceMd),
            Text(
              'No messages yet',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _conversations.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _conversations.length) {
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
          final conversation = _conversations[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openThread(conversation, isRequest: false),
                borderRadius: BorderRadius.circular(AppDims.radiusMd),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        url: conversation.otherPartyAvatarUrl,
                        name: conversation.otherPartyDisplayName,
                        size: 48,
                      ),
                      const SizedBox(width: AppDims.spaceSm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conversation.otherPartyDisplayName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                            ),
                            Text(
                              conversation.preview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _timeAgo(conversation.updatedAt),
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
                          ),
                          if (conversation.unread) ...[
                            const SizedBox(height: 4),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.slate900)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsBody() {
    if (_requestsLoading) {
      return const FlatListRowSkeleton();
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 48, color: AppColors.slate200),
            const SizedBox(height: AppDims.spaceMd),
            Text(
              'No message requests',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _requests.length + (_requestsLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _requests.length) {
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
          final conversation = _requests[i];
          final busy = _requestBusy.contains(conversation.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openThread(conversation, isRequest: true),
                borderRadius: BorderRadius.circular(AppDims.radiusMd),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        url: conversation.otherPartyAvatarUrl,
                        name: conversation.otherPartyDisplayName,
                        size: 48,
                      ),
                      const SizedBox(width: AppDims.spaceSm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conversation.otherPartyDisplayName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                            ),
                            Text(
                              conversation.preview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AcceptDeclineButtons(
                        busy: busy,
                        onAccept: () => _acceptRequest(conversation),
                        onDecline: () => _declineRequest(conversation),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

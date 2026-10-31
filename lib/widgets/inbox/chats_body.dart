import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../screens/conversation_thread_page.dart';
import '../../screens/message_requests_page.dart';
import '../../services/chat_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../feed_skeleton.dart';
import '../post_picker_search_field.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_empty_state.dart';
import '../home_feed/home_feed_widgets.dart' show FeedPicsumImage;
import '../studio/studio_icon.dart';
import '../../utils/app_clock.dart';

/// The Inbox's Messages tab (`NotifMessages`).
///
/// "Search messages" (names, handles and message text, matches in 500 Ink: the loaded chats
/// at once, then the server's search of every message, BACKEND_CHANGES B10); conversations
/// newest first: 56 avatar, name 16/500 with the time 13 on the right, the last message 15
/// below — Ink with an 8 Ink dot when unread, Tertiary when read. Pending message requests
/// sit behind a "Message requests" row at the top (the board has no sub-tabs). Tapping opens
/// the chat. Muted chats show a crossed-out bell (B8); a chat about a piece, its thumbnail (B9).
class ChatsBody extends StatefulWidget {
  const ChatsBody({
    super.key,
    this.onCountsChanged,
    this.onNewMessage,
    this.debugConversations,
    this.debugRequests,
    this.debugSearch,
  });

  /// Called after opening/returning from a thread so the parent can refresh badges.
  final VoidCallback? onCountsChanged;

  /// "Start a message" on the empty state (`NotifEmptyMessages`): the same as the + above.
  final VoidCallback? onNewMessage;

  /// For tests: conversations and requests instead of loading them.
  @visibleForTesting
  final List<ConversationSummary>? debugConversations;
  @visibleForTesting
  final List<ConversationSummary>? debugRequests;

  /// For tests: the server's search. With [debugConversations] and no [debugSearch], search
  /// only filters the loaded chats.
  @visibleForTesting
  final Future<ConversationInboxPage> Function(String query, String? cursor)? debugSearch;

  @override
  State<ChatsBody> createState() => ChatsBodyState();
}

class ChatsBodyState extends State<ChatsBody> {
  final List<ConversationSummary> _conversations = [];
  final List<ConversationSummary> _requests = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _query = '';

  /// The server's results for [_resultsFor] (B10); until they come, the loaded chats filtered.
  List<ConversationSummary>? _results;
  String _resultsFor = '';
  String? _resultsCursor;
  bool _searching = false;
  int _searchRequest = 0;
  Timer? _searchDebounce;

  /// People from the inbox, newest first, for the New message screen's Recent list.
  List<ConversationSummary> get conversations => List.unmodifiable(_conversations);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final debug = widget.debugConversations;
    if (debug != null) {
      _conversations.addAll(debug);
      _requests.addAll(widget.debugRequests ?? const []);
      _loading = false;
      return;
    }
    _load();
    _loadRequests();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() => append ? _loadingMore = true : _loading = true);
    try {
      final page = await ChatService.instance.getInbox(cursor: append ? _nextCursor : null);
      if (!mounted) return;
      setState(() {
        if (!append) _conversations.clear();
        _conversations.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && !append) setState(_conversations.clear);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadRequests() async {
    try {
      final page = await ChatService.instance.listRequests();
      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(page.items);
      });
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 200) return;
    if (_query.isEmpty) {
      _load(append: true);
    } else if (_results != null && _resultsCursor != null) {
      _search(_query, append: true);
    }
  }

  Future<ConversationInboxPage> Function(String, String?)? get _searchServer {
    if (widget.debugSearch != null) return widget.debugSearch;
    if (widget.debugConversations != null) return null;
    return (query, cursor) => ChatService.instance.searchConversations(query, cursor: cursor);
  }

  void _onQuery(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    setState(() {
      _query = query;
      _searching = query.isNotEmpty && _searchServer != null;
    });
    if (!_searching) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  /// Every message on the server, not just the chats loaded so far.
  Future<void> _search(String query, {bool append = false}) async {
    final server = _searchServer;
    if (server == null) return;
    final request = ++_searchRequest;
    if (append) setState(() => _loadingMore = true);
    try {
      final page = await server(query, append ? _resultsCursor : null);
      if (!mounted || request != _searchRequest || query != _query) return;
      setState(() {
        _results = [if (append) ...?_results, ...page.items];
        _resultsFor = query;
        _resultsCursor = page.nextCursor;
      });
    } catch (_) {
      // Offline or failing: the loaded chats, filtered, stay up.
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<ConversationSummary> get _visible {
    if (_query.isEmpty) return _conversations;
    final results = _results;
    if (results != null && _resultsFor == _query) return results;
    final q = _query.toLowerCase();
    return _conversations
        .where(
          (c) =>
              c.otherPartyDisplayName.toLowerCase().contains(q) ||
              (c.otherPartyUsername ?? '').toLowerCase().contains(q) ||
              (c.preview ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openThread(ConversationSummary conversation) async {
    if (conversation.unread) {
      setState(() {
        for (final list in [_conversations, ?_results]) {
          final i = list.indexWhere((c) => c.id == conversation.id);
          if (i != -1) list[i] = list[i].copyWith(unread: false);
        }
      });
      widget.onCountsChanged?.call();
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
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
    if (widget.debugConversations != null) return;
    _load();
    _loadRequests();
    if (_query.isNotEmpty) _search(_query);
    widget.onCountsChanged?.call();
  }

  Future<void> _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => MessageRequestsPage(initial: _requests)),
    );
    if (widget.debugConversations != null) return;
    _load();
    _loadRequests();
    widget.onCountsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final visible = _visible;
    // `NotifEmptyMessages`: no search bar until there is a conversation.
    final empty = !_loading && _conversations.isEmpty && _requests.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!empty) Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: PostPickerSearchField(
            controller: _searchController,
            hintText: 'Search messages',
            height: 44,
            onChanged: _onQuery,
          ),
        ),
        Expanded(
          child: _loading && _conversations.isEmpty
              ? const FlatListRowSkeleton()
              : RefreshIndicator(
                  color: c.textPrimary,
                  onRefresh: () async {
                    await Future.wait([_load(), _loadRequests()]);
                  },
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      if (_requests.isNotEmpty && _query.isEmpty)
                        _RequestsRow(count: _requests.length, onTap: _openRequests),
                      if (visible.isEmpty && _searching)
                        Padding(
                          padding: const EdgeInsets.only(top: 64),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else if (visible.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: empty ? 200 : 64),
                          child: _query.isEmpty
                              ? StudioEmptyState(
                                  title: 'No messages yet',
                                  message:
                                      'Message an artist from their profile or from a piece you like.',
                                  actionLabel: widget.onNewMessage == null
                                      ? null
                                      : 'Start a message',
                                  onAction: widget.onNewMessage,
                                )
                              : Text(
                                  'No conversations match “$_query”',
                                  textAlign: TextAlign.center,
                                  style: StudioType.body14(color: c.textSecondary),
                                ),
                        ),
                      for (final conversation in visible)
                        ConversationRow(
                          conversation: conversation,
                          query: _query,
                          onTap: () => _openThread(conversation),
                        ),
                      if (_loadingMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// "6:30 PM" today, the weekday this week, "Oct 12" before.
String conversationTime(DateTime at, DateTime now) {
  final t = at.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  if (!t.isBefore(today)) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (now.difference(t) < const Duration(days: 7)) return days[t.weekday - 1];
  return '${months[t.month - 1]} ${t.day}';
}

/// [text] with every match of [query] in 500 Ink.
TextSpan highlightMatches(String text, String query, TextStyle match) {
  if (query.isEmpty) return TextSpan(text: text);
  final lower = text.toLowerCase();
  final q = query.toLowerCase();
  final spans = <TextSpan>[];
  var at = 0;
  while (true) {
    final i = lower.indexOf(q, at);
    if (i < 0) break;
    if (i > at) spans.add(TextSpan(text: text.substring(at, i)));
    spans.add(TextSpan(text: text.substring(i, i + q.length), style: match));
    at = i + q.length;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(children: spans);
}

/// One conversation: 56 avatar, 14 gap, 12 vertical padding, no rule.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.query = '',
    this.trailing,
  });

  final ConversationSummary conversation;
  final String query;
  final VoidCallback onTap;

  /// Replaces the unread dot (message requests put Accept / Decline here).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final unread = conversation.unread;
    final match = TextStyle(fontWeight: StudioType.medium, color: c.textPrimary);
    // A search result shows the message that matched (B10), else the last message.
    final preview = conversation.matchPreview ?? conversation.preview ?? 'No messages yet';
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              StudioAvatar(url: conversation.otherPartyAvatarUrl, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text.rich(
                            highlightMatches(conversation.otherPartyDisplayName, query, match),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(
                              16,
                              weight: StudioType.medium,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          conversationTime(conversation.updatedAt, appNow()),
                          style: StudioType.label13(color: c.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            highlightMatches(preview, query, match),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(
                              15,
                              color: unread ? c.textPrimary : c.textTertiary,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 10),
                          trailing!,
                        ] else if (conversation.muted) ...[
                          // Muted chats show a crossed-out bell instead of the dot.
                          const SizedBox(width: 10),
                          StudioIcon(
                            StudioIcons.bellOff,
                            size: 16,
                            color: c.textPlaceholder,
                            semanticLabel: 'Muted',
                          ),
                        ] else if (unread) ...[
                          const SizedBox(width: 10),
                          Semantics(
                            label: 'Unread',
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c.textPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Started about a piece (B9): its thumbnail on the right, as in Activity.
              if (conversation.piece != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 34,
                    height: 45,
                    child: FeedPicsumImage(url: conversation.piece!.imageUrl ?? ''),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Message requests" with a Mono count and a chevron, 1 px Line under.
class _RequestsRow extends StatelessWidget {
  const _RequestsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Message requests',
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
              Text('$count', style: StudioType.mono13(color: c.textSecondary)),
              const SizedBox(width: 8),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

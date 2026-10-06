/// Legacy inquiries inbox UI — deferred to v2.
///
/// `/chat` now redirects to [InboxPage] Conversations. This file is kept only
/// as reference for the future piece-scoped Ask UX; do not re-route to it.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/inquiry_summary.dart';
import '../services/auth_session.dart';
import '../services/inquiry_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/studio_loading.dart';

enum _InboxTab { all, requests }

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  _InboxTab _activeTab = _InboxTab.all;

  final List<InquirySummary> _inquiries = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;

  final List<InquirySummary> _requests = [];
  bool _requestsLoading = true;
  bool _requestsLoaded = false;
  bool _requestsLoadingMore = false;
  String? _requestsNextCursor;
  final Set<String> _requestBusy = {};

  String? _selectedId;
  bool _selectedIsRequest = false;
  InquiryThread? _thread;
  bool _threadLoading = false;
  bool _sending = false;
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

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
    _replyController.dispose();
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
      final page = await InquiryService.instance.getInbox(
        cursor: append ? _nextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _inquiries.addAll(page.items);
        } else {
          _inquiries
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
        if (!append) _inquiries.clear();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadRequests({bool append = false}) async {
    if (append &&
        (_requestsNextCursor == null || _requestsNextCursor!.isEmpty)) {
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
      final page = await InquiryService.instance.listRequests(
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

  void _onTabChanged(_InboxTab tab) {
    setState(() => _activeTab = tab);
    if (tab == _InboxTab.requests && !_requestsLoaded) _loadRequests();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 200) return;
    if (_activeTab == _InboxTab.all) {
      if (_loadingMore) return;
      if (_nextCursor == null || _nextCursor!.isEmpty) return;
      _load(append: true);
    } else {
      if (_requestsLoadingMore) return;
      if (_requestsNextCursor == null || _requestsNextCursor!.isEmpty) return;
      _loadRequests(append: true);
    }
  }

  Future<void> _openThread(
    InquirySummary inquiry, {
    required bool isRequest,
  }) async {
    setState(() {
      _selectedId = inquiry.id;
      _selectedIsRequest = isRequest;
      _thread = null;
      _threadLoading = true;
    });
    try {
      final thread = await InquiryService.instance.getThread(inquiry.id);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _threadLoading = false;
        if (!isRequest) {
          final index = _inquiries.indexWhere((i) => i.id == inquiry.id);
          if (index != -1 && _inquiries[index].unread) {
            _inquiries[index] = _inquiries[index].copyWith(unread: false);
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _threadLoading = false;
        _selectedId = null;
      });
    }
  }

  void _closeThread() {
    setState(() {
      _selectedId = null;
      _thread = null;
      _replyController.clear();
    });
  }

  /// Shows the reply immediately (optimistic) instead of waiting for the
  /// request to complete — see `ConversationThreadPage._sendText` for the
  /// same pattern and why.
  Future<void> _sendReply() async {
    final id = _selectedId;
    final text = _replyController.text.trim();
    if (id == null || text.isEmpty || _sending) return;

    _replyController.clear();
    final me = AuthSession.instance.user;
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = InquiryMessage(
      id: tempId,
      body: text,
      senderUsername: me?.username,
      senderName: me?.name,
      senderAvatarUrl: me?.profilePhotoUrl,
      createdAt: DateTime.now(),
      isPending: true,
    );
    setState(() {
      _sending = true;
      final thread = _thread;
      if (thread != null) {
        _thread = InquiryThread(
          id: thread.id,
          pieceId: thread.pieceId,
          pieceTitle: thread.pieceTitle,
          pieceThumbnailUrl: thread.pieceThumbnailUrl,
          otherPartyUsername: thread.otherPartyUsername,
          otherPartyName: thread.otherPartyName,
          otherPartyAvatarUrl: thread.otherPartyAvatarUrl,
          status: thread.status,
          messages: [...thread.messages, pending],
        );
      }
    });
    try {
      final message = await InquiryService.instance.reply(id, text);
      if (!mounted) return;
      setState(() {
        final thread = _thread;
        if (thread != null) {
          _thread = InquiryThread(
            id: thread.id,
            pieceId: thread.pieceId,
            pieceTitle: thread.pieceTitle,
            pieceThumbnailUrl: thread.pieceThumbnailUrl,
            otherPartyUsername: thread.otherPartyUsername,
            otherPartyName: thread.otherPartyName,
            otherPartyAvatarUrl: thread.otherPartyAvatarUrl,
            status: 'open',
            messages: [
              for (final m in thread.messages)
                if (m.id != tempId) m,
              message,
            ],
          );
        }
        _sending = false;
      });
      // Replying to a pending request implicitly accepts it — move it over.
      if (_selectedIsRequest) _moveRequestToAll(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final thread = _thread;
        if (thread != null) {
          _thread = InquiryThread(
            id: thread.id,
            pieceId: thread.pieceId,
            pieceTitle: thread.pieceTitle,
            pieceThumbnailUrl: thread.pieceThumbnailUrl,
            otherPartyUsername: thread.otherPartyUsername,
            otherPartyName: thread.otherPartyName,
            otherPartyAvatarUrl: thread.otherPartyAvatarUrl,
            status: thread.status,
            messages: [
              for (final m in thread.messages)
                if (m.id != tempId) m,
            ],
          );
        }
        _sending = false;
      });
      _replyController.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
    }
  }

  void _moveRequestToAll(String id) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final moved = _requests[index].copyWith(status: 'open');
    setState(() {
      _requests.removeAt(index);
      _inquiries.insert(0, moved);
      _selectedIsRequest = false;
    });
  }

  Future<void> _acceptRequest(InquirySummary request) async {
    setState(() => _requestBusy.add(request.id));
    try {
      await InquiryService.instance.acceptRequest(request.id);
      if (!mounted) return;
      _moveRequestToAll(request.id);
      if (_selectedId == request.id) _closeThread();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    } finally {
      if (mounted) setState(() => _requestBusy.remove(request.id));
    }
  }

  Future<void> _declineRequest(InquirySummary request) async {
    setState(() => _requestBusy.add(request.id));
    try {
      await InquiryService.instance.declineRequest(request.id);
    } catch (_) {
      // Treat as handled either way.
    } finally {
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
          _requestBusy.remove(request.id);
          if (_selectedId == request.id) {
            _selectedId = null;
            _thread = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: HomeFeedTokens.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Inquiries',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FeedFilterTab(
                    label: 'All',
                    active: _activeTab == _InboxTab.all,
                    onTap: () => _onTabChanged(_InboxTab.all),
                  ),
                  const SizedBox(width: 24),
                  FeedFilterTab(
                    label: _requests.isEmpty
                        ? 'Requests'
                        : 'Requests (${_requests.length})',
                    active: _activeTab == _InboxTab.requests,
                    onTap: () => _onTabChanged(_InboxTab.requests),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _activeTab == _InboxTab.all
                  ? _buildAllBody()
                  : _buildRequestsBody(),
            ),
          ],
        ),
      ),
      bottomSheet: _selectedId != null
          ? _InquiryBottomSheet(
              thread: _thread,
              loading: _threadLoading,
              sending: _sending,
              isRequest: _selectedIsRequest,
              busy: _selectedId != null && _requestBusy.contains(_selectedId),
              replyController: _replyController,
              onClose: _closeThread,
              onSend: _sendReply,
              onAccept: _selectedIsRequest && _thread != null
                  ? () => _acceptRequest(
                      _requests.firstWhere(
                        (r) => r.id == _selectedId,
                        orElse: () => _requests.first,
                      ),
                    )
                  : null,
              onDecline: _selectedIsRequest && _thread != null
                  ? () => _declineRequest(
                      _requests.firstWhere(
                        (r) => r.id == _selectedId,
                        orElse: () => _requests.first,
                      ),
                    )
                  : null,
            )
          : null,
    );
  }

  Widget _buildAllBody() {
    if (_loading) {
      return const StudioLoadingBody();
    }
    if (_inquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 48, color: AppColors.slate200),
            const SizedBox(height: AppDims.spaceMd),
            Text(
              'No inquiries yet',
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _inquiries.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _inquiries.length) {
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
          final inq = _inquiries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openThread(inq, isRequest: false),
                borderRadius: BorderRadius.circular(AppDims.radiusMd),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        url: inq.otherPartyAvatarUrl,
                        name: inq.otherPartyDisplayName,
                        size: 48,
                      ),
                      const SizedBox(width: AppDims.spaceSm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inq.displayTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              '${inq.otherPartyDisplayName} — ${inq.preview ?? 'No messages yet'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _timeAgo(inq.updatedAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.slate400,
                            ),
                          ),
                          if (inq.unread) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.slate900,
                              ),
                            ),
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
      return const StudioLoadingBody();
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 48,
              color: AppColors.slate200,
            ),
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
          final inq = _requests[i];
          final busy = _requestBusy.contains(inq.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDims.spaceSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openThread(inq, isRequest: true),
                borderRadius: BorderRadius.circular(AppDims.radiusMd),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        url: inq.otherPartyAvatarUrl,
                        name: inq.otherPartyDisplayName,
                        size: 48,
                      ),
                      const SizedBox(width: AppDims.spaceSm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inq.displayTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              '${inq.otherPartyDisplayName} — ${inq.preview ?? 'No messages yet'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AcceptDeclineButtons(
                        busy: busy,
                        onAccept: () => _acceptRequest(inq),
                        onDecline: () => _declineRequest(inq),
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

class _InquiryBottomSheet extends StatelessWidget {
  const _InquiryBottomSheet({
    required this.thread,
    required this.loading,
    required this.sending,
    required this.isRequest,
    required this.busy,
    required this.replyController,
    required this.onClose,
    required this.onSend,
    this.onAccept,
    this.onDecline,
  });

  final InquiryThread? thread;
  final bool loading;
  final bool sending;
  final bool isRequest;
  final bool busy;
  final TextEditingController replyController;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final myUsername = AuthSession.instance.user?.username;
    final showPendingActions = isRequest && thread?.status == 'pending';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      padding: const EdgeInsets.all(AppDims.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDims.radiusXl),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(
                url: thread?.otherPartyAvatarUrl,
                name: thread?.otherPartyName ?? 'Someone',
                size: 48,
              ),
              const SizedBox(width: AppDims.spaceSm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread?.displayTitle ?? 'Inquiry',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        thread?.otherPartyName ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: AppDims.spaceMd),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final message in thread?.messages ?? const [])
                      _MessageBubble(
                        message: message,
                        isMine:
                            myUsername != null &&
                            message.senderUsername == myUsername,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppDims.spaceMd),
          if (showPendingActions)
            Center(
              child: AcceptDeclineButtons(
                busy: busy,
                onAccept: onAccept ?? () {},
                onDecline: onDecline ?? () {},
              ),
            )
          else ...[
            TextField(
              controller: replyController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
              decoration: InputDecoration(
                hintText: 'Reply...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDims.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppDims.spaceSm + 4),
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate900,
                minimumSize: const Size.fromHeight(AppDims.primaryButtonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Reply'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final InquiryMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: message.isPending ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMine ? AppColors.slate900 : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppDims.radiusMd),
          ),
          child: Text(
            message.body,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isMine ? AppColors.white : AppColors.slate800,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../services/auth_session.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../theme/chat_tokens.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/studio_loading.dart';

/// A single 1:1 chat thread — real-time via [ChatSocketService], with REST
/// ([ChatService]) as the source of truth for history and pagination.
///
/// Supports two entry modes:
/// - Existing thread: pass [conversationId] (from the inbox).
/// - New/"compose" thread: pass [conversationId] as null plus
///   [otherPartyUsername] (e.g. from a profile's "Message" button) — no
///   conversation is created on the server until the first message is sent,
///   matching Instagram's actual "Message" button behavior.
class ConversationThreadPage extends StatefulWidget {
  const ConversationThreadPage({
    super.key,
    this.conversationId,
    this.otherPartyId,
    required this.otherPartyUsername,
    required this.otherPartyName,
    required this.otherPartyAvatarUrl,
    this.initialStatus = 'open',
  }) : assert(
         conversationId != null || otherPartyUsername != null,
         'Either conversationId or otherPartyUsername is required.',
       );

  final String? conversationId;
  final String? otherPartyId;
  final String? otherPartyUsername;
  final String otherPartyName;
  final String? otherPartyAvatarUrl;
  final String initialStatus;

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _busy = false;
  bool _otherTyping = false;
  bool _otherOnline = false;
  String _status = 'open';
  String? _conversationId;
  String? _otherPartyId;
  int? _followersCount;
  int? _piecesCount;
  DateTime? _otherPartyReadAt;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingStopTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _conversationId = widget.conversationId;
    _otherPartyId = widget.otherPartyId;
    _textController.addListener(_onTextChanged);
    if (_conversationId != null) {
      _load();
      _joinLiveUpdates();
    } else {
      // Compose entry (search / profile Message): reuse an existing thread if
      // one already exists so history loads instead of an empty new-chat state.
      _resolveExistingConversation();
    }
  }

  /// When opened without [conversationId], look up an open/pending thread with
  /// this user and switch into it (same as tapping the chat in the inbox).
  Future<void> _resolveExistingConversation() async {
    final username = widget.otherPartyUsername;
    if (username == null || username.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final existing = await ChatService.instance.findConversationWith(username);
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _conversationId = existing.id;
          _status = existing.status;
          _otherPartyId = existing.otherPartyId ?? _otherPartyId;
        });
        _joinLiveUpdates();
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _joinLiveUpdates() {
    final id = _conversationId;
    if (id == null) return;
    ChatSocketService.instance.joinConversation(id);
    ChatSocketService.instance.onNewMessage(_onSocketMessage);
    ChatSocketService.instance.onMessageError(_onSocketMessageError);
    ChatSocketService.instance.onTypingStart(_onTypingStart);
    ChatSocketService.instance.onTypingStop(_onTypingStop);
    ChatSocketService.instance.onPresenceUpdate(_onPresenceUpdate);
    ChatSocketService.instance.onConversationRead(_onConversationRead);
  }

  @override
  void dispose() {
    final id = _conversationId;
    if (id != null) {
      ChatSocketService.instance.leaveConversation(id);
      ChatSocketService.instance.offNewMessage();
      ChatSocketService.instance.offMessageError();
      ChatSocketService.instance.offTypingStart();
      ChatSocketService.instance.offTypingStop();
      ChatSocketService.instance.offPresenceUpdate();
      ChatSocketService.instance.offConversationRead();
    }
    _typingStopTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final id = _conversationId;
    if (id == null) return; // no live typing signal before the thread exists
    ChatSocketService.instance.startTyping(id);
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      ChatSocketService.instance.stopTyping(id);
    });
  }

  void _appendMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;
    _messages.add(message);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  /// API returns newest-first; UI needs oldest → newest (WhatsApp/IG style).
  void _replaceMessagesFromThread(ChatThread thread) {
    _messages
      ..clear()
      ..addAll(thread.messages.reversed);
    _status = thread.status;
    _otherPartyId = thread.otherPartyId ?? _otherPartyId;
    _followersCount = thread.otherPartyFollowersCount ?? _followersCount;
    _piecesCount = thread.otherPartyPiecesCount ?? _piecesCount;
    _otherPartyReadAt = thread.otherPartyReadAt ?? _otherPartyReadAt;
  }

  void _onConversationRead(
    String conversationId,
    String readerId,
    DateTime readAt,
  ) {
    if (conversationId != _conversationId || !mounted) return;
    // Only the other party's read advances blue ticks on my messages.
    if (_otherPartyId != null && readerId != _otherPartyId) return;
    setState(() => _otherPartyReadAt = readAt);
  }

  void _onSocketMessage(String conversationId, ChatMessage message) {
    if (conversationId != _conversationId || !mounted) return;
    setState(() {
      _appendMessage(message);
      _status = 'open';
    });
    _scrollToBottom();
  }

  void _onSocketMessageError(String message, {String? code}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onTypingStart(String conversationId, String userId) {
    // The server excludes the emitting client from its own broadcast
    // (include_self=False), so any typing event received for this room is
    // always the other participant in a 1:1 thread.
    if (conversationId != _conversationId || !mounted) return;
    setState(() => _otherTyping = true);
  }

  void _onTypingStop(String conversationId, String userId) {
    if (conversationId != _conversationId || !mounted) return;
    setState(() => _otherTyping = false);
  }

  void _onPresenceUpdate(String userId, bool online) {
    if (!mounted || _otherPartyId == null || userId != _otherPartyId) return;
    setState(() => _otherOnline = online);
  }

  Future<void> _load() async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final thread = await ChatService.instance.getThread(id);
      if (!mounted) return;
      setState(() {
        _replaceMessagesFromThread(thread);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Starts the conversation on the server with the first message, then
  /// switches this page from compose mode into a live thread.
  Future<ChatMessage?> _startWithFirstMessage({
    String? body,
    String? imageUrl,
  }) async {
    final username = widget.otherPartyUsername;
    if (username == null) return null;
    final result = await ChatService.instance.startConversation(
      username,
      body ?? '',
      imageUrl: imageUrl,
    );
    if (!mounted) return null;
    setState(() {
      _conversationId = result.id;
      _status = result.status;
    });
    _joinLiveUpdates();
    // startConversation doesn't return the created message payload — fetch
    // the thread once so the message list (with real id/timestamp) is correct.
    final thread = await ChatService.instance.getThread(result.id);
    if (!mounted) return null;
    setState(() {
      _replaceMessagesFromThread(thread);
    });
    _scrollToBottom();
    return _messages.isNotEmpty ? _messages.last : null;
  }

  /// Shows the message immediately (optimistic) instead of waiting for the
  /// send request to complete — the request can legitimately take a while
  /// (slow network, or the backend waking from an idle cold-start), and
  /// there's no reason the thread should sit empty/frozen for that whole
  /// time when we already know exactly what's being sent.
  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    final id = _conversationId;
    if (id != null) ChatSocketService.instance.stopTyping(id);

    _textController.clear();
    final me = AuthSession.instance.user;
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
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
      _messages.add(pending);
    });
    _scrollToBottom();
    try {
      if (id == null) {
        // `_startWithFirstMessage` re-syncs `_messages` wholesale from the
        // server thread once the conversation exists, which already
        // replaces this pending bubble with the real one.
        await _startWithFirstMessage(body: text);
        if (!mounted) return;
        setState(() => _sending = false);
      } else {
        final message = await ChatService.instance.sendMessage(id, body: text);
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _appendMessage(message);
          _status = 'open';
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        _sending = false;
      });
      _textController.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _pickAndSendPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final url = await MediaService.instance.uploadFile(
        purpose: MediaPurpose.chat,
        file: File(picked.path),
      );
      final id = _conversationId;
      if (id == null) {
        await _startWithFirstMessage(imageUrl: url);
        if (!mounted) return;
        setState(() => _sending = false);
      } else {
        final message = await ChatService.instance.sendMessage(
          id,
          imageUrl: url,
        );
        if (!mounted) return;
        setState(() {
          _appendMessage(message);
          _status = 'open';
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send photo: $e')));
    }
  }

  Future<void> _accept() async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ChatService.instance.acceptRequest(id);
      if (!mounted) return;
      setState(() {
        _status = 'open';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    }
  }

  Future<void> _decline() async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ChatService.instance.declineRequest(id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  String get _displayUsername {
    final u = widget.otherPartyUsername;
    if (u == null || u.isEmpty) return '';
    return u.startsWith('@') ? u : '@$u';
  }

  /// Flat list length including date headers between day changes.
  int get _threadItemCount {
    if (_messages.isEmpty) return 0;
    var count = _messages.length;
    for (var i = 1; i < _messages.length; i++) {
      if (!_sameCalendarDay(_messages[i - 1].createdAt, _messages[i].createdAt)) {
        count++;
      }
    }
    // Leading date header for the first message.
    count++;
    return count;
  }

  Object _threadItemAt(int index) {
    var cursor = 0;
    DateTime? prevDay;
    for (final message in _messages) {
      final day = DateTime(
        message.createdAt.toLocal().year,
        message.createdAt.toLocal().month,
        message.createdAt.toLocal().day,
      );
      if (prevDay == null || day != prevDay) {
        if (cursor == index) {
          return _DateHeaderData(_dateLabel(message.createdAt));
        }
        cursor++;
        prevDay = day;
      }
      if (cursor == index) return message;
      cursor++;
    }
    return _messages.last;
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  static String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (local.year == now.year) {
      return '${months[local.month - 1]} ${local.day}';
    }
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = AuthSession.instance.user?.username;
    final showPendingActions = _status == 'pending';
    final showEmptyState = !_loading && _messages.isEmpty;

    return Scaffold(
      backgroundColor: ChatTokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: ChatTokens.headerBackground,
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        url: widget.otherPartyAvatarUrl,
                        name: widget.otherPartyName,
                        size: 36,
                      ),
                      if (_otherOnline)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.shade500,
                              border: Border.all(
                                color: ChatTokens.headerBackground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherPartyName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: HomeFeedTokens.textPrimary,
                          ),
                        ),
                        if (_otherTyping)
                          Text(
                            'typing…',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          )
                        else if (_displayUsername.isNotEmpty)
                          Text(
                            _displayUsername,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: ChatTokens.username,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const StudioLoadingBody()
                  : showEmptyState
                  ? _NewChatEmptyState(
                      avatarUrl: widget.otherPartyAvatarUrl,
                      name: widget.otherPartyName,
                      username: _displayUsername,
                      followersCount: _followersCount,
                      piecesCount: _piecesCount,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _threadItemCount,
                      itemBuilder: (context, i) {
                        final item = _threadItemAt(i);
                        if (item is _DateHeaderData) {
                          return _DateSeparator(label: item.label);
                        }
                        final message = item as ChatMessage;
                        final isMine = myUsername != null &&
                            message.senderUsername == myUsername;
                        return _MessageBubble(
                          message: message,
                          isMine: isMine,
                          seen: isMine &&
                              _otherPartyReadAt != null &&
                              !message.createdAt
                                  .toUtc()
                                  .isAfter(_otherPartyReadAt!.toUtc()),
                        );
                      },
                    ),
            ),
            if (showPendingActions)
              Padding(
                padding: const EdgeInsets.all(AppDims.spaceLg),
                child: Center(
                  child: AcceptDeclineButtons(
                    busy: _busy,
                    onAccept: _accept,
                    onDecline: _decline,
                  ),
                ),
              )
            else
              Container(
                color: ChatTokens.headerBackground,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _sending ? null : _pickAndSendPhoto,
                      icon: Icon(
                        Icons.image_outlined,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.slate900,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9999),
                            borderSide: BorderSide(color: AppColors.slate200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _sendText,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded, color: AppColors.slate900),
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

class _DateHeaderData {
  const _DateHeaderData(this.label);
  final String label;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.slate200,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NewChatEmptyState extends StatelessWidget {
  const _NewChatEmptyState({
    required this.avatarUrl,
    required this.name,
    required this.username,
    this.followersCount,
    this.piecesCount,
  });

  final String? avatarUrl;
  final String name;
  final String username;
  final int? followersCount;
  final int? piecesCount;

  String get _statsLine {
    final parts = <String>[];
    if (followersCount != null) {
      parts.add('${_formatCount(followersCount!)} followers');
    }
    if (piecesCount != null) {
      parts.add('${_formatCount(piecesCount!)} pieces');
    }
    return parts.join(' • ');
  }

  static String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return v == v.roundToDouble()
          ? '${v.toInt()}M'
          : '${v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return v == v.roundToDouble()
          ? '${v.toInt()}K'
          : '${v.toStringAsFixed(1)}K';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statsLine;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(url: avatarUrl, name: name, size: 96),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            if (username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                username,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: ChatTokens.username,
                ),
              ),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                stats,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: ChatTokens.emptyStats,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Message $name',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: ChatTokens.emptyStats,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.seen = false,
  });

  final ChatMessage message;
  final bool isMine;
  final bool seen;

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: message.isPending ? 0.6 : 1.0,
              child: Container(
                padding: hasImage
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.7,
                ),
                decoration: BoxDecoration(
                  color: isMine ? AppColors.slate900 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(AppDims.radiusMd),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppDims.radiusMd - 4),
                        child: Image.network(message.imageUrl!, fit: BoxFit.cover),
                      )
                    : Text(
                        message.body ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isMine ? AppColors.white : AppColors.slate800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: ChatTokens.timestamp,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: seen ? const Color(0xFF53BDEB) : ChatTokens.timestamp,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/chat_message.dart';
import '../models/feed_preview_item.dart';
import '../services/auth_session.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/media_service.dart';
import '../services/piece_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../utils/explore_detail_route.dart' show openPieceDetailPreview;
import '../utils/money_format.dart';
import '../utils/profile_navigation.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/content_actions_sheet.dart';
import '../widgets/create_flow/post_flow_widgets.dart' show PostIconButton;
import '../widgets/home_feed/home_feed_widgets.dart' show FeedPicsumImage;
import '../widgets/studio/studio_avatar.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_toast.dart';
import '../widgets/studio_loading.dart';
import 'chat_video_page.dart';
import 'image_preview_page.dart';
import '../widgets/studio/studio_tap_area.dart';
import '../utils/app_clock.dart';

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
    this.aboutPiece,
    this.debugMessages,
    this.debugMyUsername,
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

  /// Opened from a piece page (B9): a new chat starts about this piece, and its card shows at
  /// the top. A chat already under way keeps the piece it began with (or none).
  final ChatPiece? aboutPiece;

  /// For tests: messages (oldest first) and the signed-in username, instead of loading.
  @visibleForTesting
  final List<ChatMessage>? debugMessages;
  @visibleForTesting
  final String? debugMyUsername;

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _busy = false;
  bool _otherTyping = false;
  String _status = 'open';
  String? _conversationId;
  String? _otherPartyId;
  int? _followersCount;
  int? _piecesCount;
  DateTime? _otherPartyReadAt;

  /// Muted by the viewer: no alerts for this chat (`ConvMenu`).
  bool _muted = false;

  /// The piece the chat is about ("About this piece"), once the thread says so.
  ChatPiece? _piece;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingStopTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _conversationId = widget.conversationId;
    _piece = widget.aboutPiece;
    _otherPartyId = widget.otherPartyId;
    _textController.addListener(_onTextChanged);
    final debug = widget.debugMessages;
    if (debug != null) {
      _messages.addAll(debug);
      _loading = false;
      return;
    }
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
      ChatSocketService.instance.offConversationRead();
    }
    _typingStopTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Send turns on with text.
    final id = _conversationId;
    if (widget.debugMessages != null) return;
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
    showStudioToast(context, message, icon: null);
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

  Future<void> _load() async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final thread = await ChatService.instance.getThread(id);
      if (!mounted) return;
      setState(() {
        _replaceMessagesFromThread(thread);
        _muted = thread.muted;
        // The thread's own piece wins: a chat already under way keeps what it began with.
        _piece = thread.piece;
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
    String? videoUrl,
    String? thumbnailUrl,
  }) async {
    final username = widget.otherPartyUsername;
    if (username == null) return null;
    final result = await ChatService.instance.startConversation(
      username,
      body ?? '',
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      pieceId: widget.aboutPiece?.id,
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
      _piece = thread.piece ?? _piece;
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
      showStudioToast(context, "Couldn't send. Try again.", icon: null);
    }
  }

  /// + (`Conversation`): a photo or a video from the camera roll, nothing else. Videos
  /// (BACKEND_CHANGES B11) go up to 100 MB and send with their first frame as the poster.
  Future<void> _pickAndSendMedia() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickMedia(imageQuality: 85);
    } catch (_) {
      return;
    }
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final isVideo = MediaService.isVideoContentType(MediaService.contentTypeForPath(picked.path));
    if (isVideo && await file.length() > MediaService.maxVideoBytes) {
      if (mounted) showStudioToast(context, 'Videos can be up to 100 MB', icon: null);
      return;
    }
    setState(() => _sending = true);
    try {
      final url = await MediaService.instance.uploadFile(purpose: MediaPurpose.chat, file: file);
      final poster = isVideo ? await _uploadPoster(picked.path) : null;
      final imageUrl = isVideo ? null : url;
      final videoUrl = isVideo ? url : null;
      final id = _conversationId;
      if (id == null) {
        await _startWithFirstMessage(
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          thumbnailUrl: poster,
        );
        if (!mounted) return;
        setState(() => _sending = false);
      } else {
        final message = await ChatService.instance.sendMessage(
          id,
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          thumbnailUrl: poster,
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
      showStudioToast(
        context,
        isVideo ? "Couldn't send the video" : "Couldn't send the photo",
        icon: null,
      );
    }
  }

  /// The video's first frame, uploaded as its poster. A video still sends without one.
  Future<String?> _uploadPoster(String path) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return await MediaService.instance.uploadBytes(
        purpose: MediaPurpose.chat,
        bytes: bytes,
        contentType: 'image/jpeg',
      );
    } catch (_) {
      return null;
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
      showStudioToast(context, "Couldn't accept the request", icon: null);
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
      showStudioToast(context, "Couldn't decline the request", icon: null);
    }
  }

  String get _displayUsername {
    final u = widget.otherPartyUsername;
    if (u == null || u.isEmpty) return '';
    return u.startsWith('@') ? u : '@$u';
  }

  String? get _username {
    final u = widget.otherPartyUsername;
    if (u == null || u.isEmpty) return null;
    return u.startsWith('@') ? u.substring(1) : u;
  }

  void _openMenu() {
    final username = _username;
    if (username == null) return;
    showConversationMenu(
      context,
      username: username,
      name: widget.otherPartyName,
      avatarUrl: widget.otherPartyAvatarUrl,
      onViewProfile: () => openUserProfile(context, username),
      onBlocked: () {
        if (mounted) Navigator.of(context).maybePop();
      },
      muted: _muted,
      onMuteChanged: _conversationId == null ? null : _setMuted,
    );
  }

  /// The card opens the piece (it may have gone: then nothing happens).
  Future<void> _openPiece(ChatPiece piece) async {
    try {
      final summary = await PieceService.instance.getByIdCached(piece.id);
      if (!mounted) return;
      await openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(summary));
    } catch (_) {}
  }

  /// Mute notifications: the switch moves at once; if the server refuses, it goes back.
  Future<bool> _setMuted(bool muted) async {
    final id = _conversationId;
    if (id == null) return _muted;
    final before = _muted;
    setState(() => _muted = muted);
    try {
      final kept = await ChatService.instance.setMuted(id, muted);
      if (mounted) setState(() => _muted = kept);
      return kept;
    } catch (_) {
      if (mounted) {
        setState(() => _muted = before);
        showStudioToast(context, 'Could not save. Try again.', icon: null);
      }
      return before;
    }
  }

  /// The thread as rows: a day line where the day changes, then bubbles. A bubble is the
  /// last of its run when the next message is from someone else or on another day.
  List<_Row> _rows(String? me) {
    final rows = <_Row>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i == 0 ? null : _messages[i - 1];
      final next = i + 1 < _messages.length ? _messages[i + 1] : null;
      final mine = me != null && m.senderUsername == me;
      final newDay = prev == null || !_sameCalendarDay(prev.createdAt, m.createdAt);
      if (newDay) rows.add(_Row.day(dayLine(m.createdAt, appNow())));
      // The piece the chat is about sits under the first day line (`Conversation`).
      if (i == 0 && _piece != null) rows.add(const _Row.piece());
      final prevMine = prev != null && me != null && prev.senderUsername == me;
      final nextMine = next != null && me != null && next.senderUsername == me;
      final startsRun = newDay || prevMine != mine;
      final endsRun = next == null ||
          nextMine != mine ||
          !_sameCalendarDay(m.createdAt, next.createdAt);
      rows.add(_Row.message(m, mine: mine, startsRun: startsRun, endsRun: endsRun));
    }
    return rows;
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  /// My newest message, once the other person has read it.
  String? _seenId(String? me) {
    final readAt = _otherPartyReadAt;
    if (me == null || readAt == null) return null;
    for (final m in _messages.reversed) {
      if (m.senderUsername != me) continue;
      return m.createdAt.toUtc().isAfter(readAt.toUtc()) ? null : m.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final me = widget.debugMyUsername ?? AuthSession.instance.user?.username;
    final pending = _status == 'pending';
    final empty = !_loading && _messages.isEmpty;
    final rows = _rows(me);
    final seenId = _seenId(me);
    final canSend = !_sending && _textController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: back; avatar, name and handle open the profile; more.
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Row(
                children: [
                  PostIconButton(
                    icon: StudioIcons.backBold,
                    label: 'Back',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: '${widget.otherPartyName}, open profile',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => openUserProfile(context, _username),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            StudioAvatar(url: widget.otherPartyAvatarUrl, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.otherPartyName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: StudioType.sans(
                                      15,
                                      weight: StudioType.medium,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  if (_displayUsername.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      _displayUsername,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: StudioType.caption12(color: c.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_username != null)
                    PostIconButton(
                      icon: StudioIcons.folderOptions,
                      label: 'Conversation options',
                      onTap: _openMenu,
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const StudioLoadingBody()
                  : empty
                  ? _NewChatEmptyState(
                      avatarUrl: widget.otherPartyAvatarUrl,
                      name: widget.otherPartyName,
                      username: _displayUsername,
                      followersCount: _followersCount,
                      piecesCount: _piecesCount,
                      piece: _piece == null
                          ? null
                          : ChatPieceCard(piece: _piece!, onTap: () => _openPiece(_piece!)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      itemCount: rows.length + (_otherTyping ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= rows.length) return const _TypingBubble();
                        final row = rows[i];
                        final day = row.day;
                        if (day != null) return _DayLine(label: day);
                        if (row.isPiece) {
                          final piece = _piece!;
                          // On the side of whoever asked: yours when it is someone else's piece.
                          final mine = piece.artistUsername == null || piece.artistUsername != me;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: ChatPieceCard(piece: piece, onTap: () => _openPiece(piece)),
                            ),
                          );
                        }
                        final m = row.message!;
                        return _MessageBubble(
                          message: m,
                          isMine: row.mine,
                          startsRun: row.startsRun,
                          endsRun: row.endsRun,
                          seen: m.id == seenId,
                        );
                      },
                    ),
            ),
            if (pending)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewPaddingOf(context).bottom + 16,
                ),
                child: Center(
                  child: AcceptDeclineButtons(busy: _busy, onAccept: _accept, onDecline: _decline),
                ),
              )
            else
              _Composer(
                controller: _textController,
                canSend: canSend,
                sending: _sending,
                onAttach: _sending ? null : _pickAndSendMedia,
                onSend: _sendText,
              ),
          ],
        ),
      ),
    );
  }
}

/// A thread row: a day line, the piece card, or a message.
class _Row {
  const _Row.day(String this.day)
    : message = null,
      mine = false,
      startsRun = false,
      endsRun = false,
      isPiece = false;
  const _Row.piece()
    : day = null,
      message = null,
      mine = false,
      startsRun = false,
      endsRun = false,
      isPiece = true;
  const _Row.message(
    ChatMessage this.message, {
    required this.mine,
    required this.startsRun,
    required this.endsRun,
  }) : day = null,
       isPiece = false;

  final String? day;
  final ChatMessage? message;
  final bool mine;
  final bool startsRun;
  final bool endsRun;
  final bool isPiece;
}

/// `Conversation` "About this piece": 236 wide, 8 padding, a 1 px Line, radius 16 on Card;
/// the 48 × 64 cover (radius 8), then "About this piece" (12 Graphite), the title (14/500) and
/// the price (13) while it is for sale. Opens the piece.
class ChatPieceCard extends StatelessWidget {
  const ChatPieceCard({super.key, required this.piece, required this.onTap});

  final ChatPiece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final price = piece.priceCents;
    return Semantics(
      button: true,
      label: ['About this piece', piece.title, if (price != null) formatMoney(price)].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 236,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: FeedPicsumImage(url: piece.imageUrl ?? ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('About this piece', style: StudioType.caption12(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      piece.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(14, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 2),
                      Text(formatMoney(price), style: StudioType.sans(13, color: c.textPrimary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today · 2:14 PM", "Yesterday · 9:02 AM", "Oct 12 · 4:35 PM" (the year when it is not
/// this one): the day and the time of its first message.
String dayLine(DateTime at, DateTime now) {
  final t = at.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time = '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final diff = today.difference(day).inDays;
  final date = switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    _ when t.year == now.year => '${months[t.month - 1]} ${t.day}',
    _ => '${months[t.month - 1]} ${t.day}, ${t.year}',
  };
  return '$date · $time';
}

/// Mono 11 Tertiary, centred, 6 above and below.
class _DayLine extends StatelessWidget {
  const _DayLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(label, style: StudioType.mono11(color: context.studio.textTertiary)),
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
    this.piece,
  });

  /// Opened from a piece page: its card, under "Message [name]".
  final Widget? piece;

  final String? avatarUrl;
  final String name;
  final String username;
  final int? followersCount;
  final int? piecesCount;

  static String _count(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return v == v.roundToDouble() ? '${v.toInt()}M' : '${v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return v == v.roundToDouble() ? '${v.toInt()}K' : '${v.toStringAsFixed(1)}K';
    }
    return '$n';
  }

  /// No board: the person (96 avatar, 20/500 name, handle, Mono counts) and "Message [name]".
  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final stats = [
      if (followersCount != null) '${_count(followersCount!)} followers',
      if (piecesCount != null) '${_count(piecesCount!)} pieces',
    ].join(' · ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioAvatar(url: avatarUrl, size: 96),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: StudioType.sans(20, weight: StudioType.medium, color: c.textPrimary),
            ),
            if (username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(username, style: StudioType.body14(color: c.textSecondary)),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(stats, style: StudioType.mono(12, color: c.textTertiary)),
            ],
            const SizedBox(height: 12),
            Text('Message $name', style: StudioType.label13(color: c.textTertiary)),
            if (piece != null) ...[const SizedBox(height: 24), piece!],
          ],
        ),
      ),
    );
  }
}

/// One bubble (`Conversation`): sent Ink with Gallery White text, received Surface; 10 14
/// padding, 15 / 1.4, radius 18, the last of a run with a 6 corner on its sender's side;
/// up to 76 % of the width. Photos are 180 wide, 3:4; videos the same, their poster with a
/// play button, opening full screen (B11). 6 between bubbles, 12 between runs.
/// "Seen" (11 Tertiary) under your newest message once it is read.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.startsRun,
    required this.endsRun,
    this.seen = false,
  });

  final ChatMessage message;
  final bool isMine;
  final bool startsRun;
  final bool endsRun;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final image = message.imageUrl;
    final hasImage = image != null && image.isNotEmpty;
    final video = message.videoUrl;
    final hasVideo = video != null && video.isNotEmpty;
    const r = Radius.circular(18);
    const tail = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !isMine && endsRun ? tail : r,
      bottomRight: isMine && endsRun ? tail : r,
    );
    final maxWidth = MediaQuery.sizeOf(context).width * 0.76;

    Widget bubble;
    if (hasVideo) {
      final poster = message.thumbnailUrl;
      bubble = Semantics(
        button: true,
        label: 'Video',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => ChatVideoPage(url: video)),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: 180,
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: c.surface,
                    child: poster == null || poster.isEmpty
                        ? null
                        : FeedPicsumImage(url: poster),
                  ),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.scrim, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const StudioIcon(
                        StudioIcons.play,
                        size: 18,
                        color: StudioColors.galleryWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (hasImage) {
      bubble = Semantics(
        button: true,
        label: 'Photo',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => ImagePreviewPage(imageUrls: [image])),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: 180,
              height: 240,
              child: ColoredBox(color: c.surface, child: FeedPicsumImage(url: image)),
            ),
          ),
        ),
      );
    } else {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? c.buttonFill : c.surface,
          borderRadius: radius,
        ),
        child: Text(
          message.body ?? '',
          style: StudioType.sans(
            15,
            height: 1.4,
            color: isMine ? c.buttonText : c.textPrimary,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: startsRun ? 12 : 6),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            duration: StudioMotion.quick,
            opacity: message.isPending ? 0.6 : 1.0,
            child: bubble,
          ),
          if (seen)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text('Seen', style: StudioType.sans(11, color: c.textTertiary)),
            ),
        ],
      ),
    );
  }
}

/// Three dots in a received bubble (Surface, the tail corner) while the other person types.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget dot(Color color) => Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'Typing',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [dot(c.textTertiary), dot(c.textPlaceholder), dot(c.lineStrong)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Composer (`Conversation`): 1 px Line above, 10 12 padding; + (40) attaches a photo or video; a
/// 42 Surface pill field ("Message", 15); a 40 round send, Line until there is text, then
/// Ink.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool sending;
  final VoidCallback? onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom > 0
        ? 10.0
        : (mq.viewPadding.bottom > 0 ? mq.viewPadding.bottom : StudioSize.noInsetBottomPadding);
    final style = StudioType.sans(15, color: c.textPrimary);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            button: true,
            enabled: onAttach != null,
            label: 'Attach a photo or video',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onAttach,
              behavior: HitTestBehavior.opaque,
              child: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: StudioIcon(StudioIcons.attach, size: 22, color: c.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(21)),
              child: StudioTapArea(child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: style,
                cursorColor: c.textPrimary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Message',
                  hintStyle: style.copyWith(color: c.textTertiary),
                ),
              )),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: 'Send',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? onSend : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend ? c.buttonFill : c.line,
                ),
                child: sending
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.buttonText),
                      )
                    : StudioIcon(
                        StudioIcons.send,
                        size: 18,
                        color: canSend ? c.buttonText : StudioColors.galleryWhite,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

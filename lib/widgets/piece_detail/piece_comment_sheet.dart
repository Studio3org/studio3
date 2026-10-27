import 'package:flutter/material.dart';

import '../../models/comment_page.dart';
import '../../models/feed_item.dart';
import '../../services/auth_session.dart';
import '../../services/blocked_authors_store.dart';
import '../../services/chat_socket_service.dart';
import '../../services/report_service.dart';
import '../../services/social_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../content_actions_sheet.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_sheet.dart';
import '../studio/studio_toast.dart';

/// Comment list + add-comment bottom sheet for a piece or Scene (`SceneComments`).
///
/// Grabber (10 above, 6 below), "Comments" 15/500 with the Mono 12 count, a Line, then
/// rows: 32 photo, 12 gap, name 13/500 (an "Artist" pill on the artist's own comments), Mono
/// 11 time, the text 14/1.45 and Reply 12 in Graphite, 10 above and below. Reply starts a new
/// comment with "@name" (no likes, no threads). Press and hold someone else's comment to
/// report it or block them. At the bottom: your photo and the 42 pill field, with the
/// `Conversation` send button (grey until there is text). Over a Scene ([overMedia]) the
/// sheet takes the lower 60 % and the Scene keeps playing behind a 35 % shade.
class PieceCommentSheet extends StatefulWidget {
  const PieceCommentSheet({
    super.key,
    required this.contentId,
    required this.isScene,
    required this.scrollController,
    this.commentCount,
    this.artistUsername,
    this.onCountChanged,
  });

  final String contentId;
  final bool isScene;
  final ScrollController scrollController;

  /// Shown after the title; null leaves it out.
  final int? commentCount;

  /// Their comments carry the Artist label.
  final String? artistUsername;

  /// Called with the new count after a comment is posted.
  final ValueChanged<int>? onCountChanged;

  static Future<void> show(
    BuildContext context, {
    required String contentId,
    required bool isScene,
    int? commentCount,
    String? artistUsername,
    bool overMedia = false,
    ValueChanged<int>? onCountChanged,
  }) {
    final c = context.studio;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      barrierColor: overMedia ? const Color(0x59000000) : c.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: overMedia ? 0.61 : 0.75,
        minChildSize: 0.5,
        maxChildSize: StudioSize.sheetMaxHeightFactor,
        expand: false,
        builder: (context, scrollController) => PieceCommentSheet(
          contentId: contentId,
          isScene: isScene,
          scrollController: scrollController,
          commentCount: commentCount,
          artistUsername: artistUsername,
          onCountChanged: onCountChanged,
        ),
      ),
    );
  }

  @override
  State<PieceCommentSheet> createState() => _PieceCommentSheetState();
}

class _PieceCommentSheetState extends State<PieceCommentSheet> {
  final _comments = <CommentSummary>[];
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  late int? _count = widget.commentCount;
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;

  String get _targetType => widget.isScene ? 'post' : 'piece';

  bool get _hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    ChatSocketService.instance.joinTarget(targetType: _targetType, targetId: widget.contentId);
    ChatSocketService.instance.onCommentNew(_onLiveComment);
    BlockedAuthorsStore.instance.addListener(_onAuthorBlocked);
    _loadInitial();
  }

  void _onAuthorBlocked() {
    if (mounted) setState(() {});
  }

  /// Comments from accounts blocked this session are hidden immediately;
  /// the backend leaves them out of later fetches.
  List<CommentSummary> get _visibleComments {
    final blocked = BlockedAuthorsStore.instance;
    return _comments.where((c) => !blocked.isBlocked(c.authorUsername)).toList();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    ChatSocketService.instance.leaveTarget(targetType: _targetType, targetId: widget.contentId);
    ChatSocketService.instance.offCommentNew();
    BlockedAuthorsStore.instance.removeListener(_onAuthorBlocked);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onLiveComment(Map<String, dynamic> json) {
    final targetType = json['targetType'] as String?;
    final targetId = json['targetId'] as String?;
    if (targetType != _targetType || targetId != widget.contentId) return;
    final comment = CommentSummary.fromJson(json);
    if (comment.id.isEmpty) return;
    if (!mounted) return;
    if (_comments.any((c) => c.id == comment.id)) return;
    // Skip if we already have an optimistic local copy that will be replaced.
    setState(() => _comments.insert(0, comment));
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || !widget.scrollController.hasClients) {
      return;
    }
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<CommentPage> _fetch({String? cursor}) {
    return widget.isScene
        ? SocialService.instance.getPostComments(widget.contentId, cursor: cursor)
        : SocialService.instance.getPieceComments(widget.contentId, cursor: cursor);
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch();
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load comments';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // Pagination failure just stops loading further pages.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _submit() async {
    final body = _textController.text.trim();
    if (body.isEmpty || _sending) return;
    if (!await requireLogin(context)) return;
    final user = AuthSession.instance.user;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = CommentSummary(
      id: tempId,
      body: body,
      authorUsername: user?.username,
      authorName: user?.name,
      authorAvatarUrl: user?.profilePhotoUrl,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _comments.insert(0, optimistic);
      _sending = true;
    });
    _textController.clear();
    try {
      final saved = widget.isScene
          ? await SocialService.instance.commentOnPost(widget.contentId, body)
          : await SocialService.instance.commentOnPiece(widget.contentId, body);
      if (!mounted) return;
      if (_count != null) {
        _count = _count! + 1;
        widget.onCountChanged?.call(_count!);
      }
      setState(() {
        final index = _comments.indexWhere((c) => c.id == tempId);
        if (index != -1) {
          _comments[index] = saved;
        } else if (!_comments.any((c) => c.id == saved.id)) {
          // Socket may have already inserted the real comment.
          _comments.insert(0, saved);
        }
        _comments.removeWhere((c) => c.id != saved.id && c.id == tempId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == tempId);
        _textController.text = body;
      });
      showStudioToast(context, 'Could not post comment', icon: null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Reply: a new comment that starts with "@name".
  void _reply(CommentSummary comment) {
    if (!AuthSession.instance.isLoggedIn) {
      requireLogin(
        context,
        title: 'Sign in to comment',
        message: 'Log in or create a free account to comment.',
      );
      return;
    }
    final name = (comment.authorName != null && comment.authorName!.isNotEmpty)
        ? comment.authorName!
        : (comment.authorUsername ?? '');
    if (name.isEmpty) return;
    final text = '@$name ';
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      children: [
        const SizedBox(height: 10),
        const StudioSheetGrabber(),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Comments',
              style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
            ),
            if (_count != null && _count! > 0) ...[
              const SizedBox(width: 4),
              Text('${_count!}', style: StudioType.mono(12, color: c.textSecondary)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: c.line),
        Expanded(child: _buildList(c)),
        _buildInputBar(c),
      ],
    );
  }

  Widget _buildList(StudioColors c) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: StudioType.body14(color: c.textSecondary)),
      );
    }
    if (_visibleComments.isEmpty) {
      return Center(
        child: Text('No comments yet', style: StudioType.body14(color: c.textSecondary)),
      );
    }
    final comments = _visibleComments;
    final artist = widget.artistUsername?.toLowerCase();
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      itemCount: comments.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= comments.length) {
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
        final comment = comments[index];
        return _CommentTile(
          comment: comment,
          isArtist: artist != null &&
              artist.isNotEmpty &&
              comment.authorUsername?.toLowerCase() == artist,
          onReply: () => _reply(comment),
        );
      },
    );
  }

  /// `SceneComments` composer: 1 px rule above, 10 16 padding, your 32 photo, 10 gap, the 42
  /// pill field on Surface (15, placeholder tertiary), 8 gap, the `Conversation` 40 round send
  /// (Line until there is text, then Ink).
  Widget _buildInputBar(StudioColors c) {
    final loggedIn = AuthSession.instance.isLoggedIn;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final canSend = loggedIn && !_sending && _textController.text.trim().isNotEmpty;
    final style = StudioType.sans(15, color: c.textPrimary);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        keyboard > 0 ? keyboard + 10 : (safe > 0 ? safe : StudioSize.noInsetBottomPadding),
      ),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (loggedIn) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: StudioAvatar(url: AuthSession.instance.user?.profilePhotoUrl, size: 32),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(21)),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                // Guests can read the thread; tapping to write asks them to
                // log in instead of opening the keyboard.
                readOnly: !loggedIn,
                onTap: loggedIn
                    ? null
                    : () => requireLogin(
                        context,
                        title: 'Sign in to comment',
                        message: 'Log in or create a free account to comment.',
                      ),
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: style,
                cursorColor: c.textPrimary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: loggedIn ? 'Add a comment' : 'Log in to comment',
                  hintStyle: style.copyWith(color: c.textTertiary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: 'Send',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? _submit : null,
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
                child: _sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.isArtist, required this.onReply});

  final CommentSummary comment;
  final bool isArtist;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final canNavigate = comment.authorUsername != null && comment.authorUsername!.trim().isNotEmpty;
    void onTapAuthor() => openUserProfile(context, comment.authorUsername);
    final me = AuthSession.instance.user?.username.toLowerCase();
    // Only real (server-saved) comments by someone else can be reported. Deleting your own
    // (or, for the artist, anyone's) needs the server (BACKEND_CHANGES B33).
    final canReport =
        comment.id.isNotEmpty &&
        !comment.id.startsWith('local-') &&
        (me == null || comment.authorUsername?.toLowerCase() != me);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: canReport
          ? () => showContentActionsSheet(
                context,
                target: ReportTarget.comment(comment.id),
                authorUsername: comment.authorUsername,
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: canNavigate ? onTapAuthor : null,
              behavior: canNavigate ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
              child: StudioAvatar(url: comment.authorAvatarUrl, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: canNavigate ? onTapAuthor : null,
                          behavior: canNavigate
                              ? HitTestBehavior.opaque
                              : HitTestBehavior.deferToChild,
                          child: Text(
                            (comment.authorName != null && comment.authorName!.isNotEmpty)
                                ? comment.authorName!
                                : (comment.authorUsername ?? 'User'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.label13(
                              weight: StudioType.medium,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (isArtist) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(StudioRadius.round),
                            border: Border.all(color: c.line),
                          ),
                          child: Text('Artist', style: StudioType.sans(11, color: c.textSecondary)),
                        ),
                      ],
                      const SizedBox(width: 6),
                      // Times are facts: Geist Mono.
                      Text(
                        _timeAgo(comment.createdAt),
                        style: StudioType.mono11(color: c.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(comment.body, style: StudioType.body14(height: 1.45, color: c.textPrimary)),
                  const SizedBox(height: 3),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: Text('Reply', style: StudioType.sans(12, color: c.textSecondary)),
                    ),
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

String _timeAgo(String? isoDate) {
  if (isoDate == null) return '';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

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

/// Comment list + add-comment bottom sheet for a piece or scene. List/create only — no
/// like/reply (backend has no API for those).
///
/// No board: a board sheet (scrim, 24 top corners, grabber, ≤ 90 %), comment rows with
/// a 32 avatar, name 13/500 and Mono time, and the `Conversation` composer (42 pill field
/// on Paper, 40 round send, grey until there is text).
class PieceCommentSheet extends StatefulWidget {
  const PieceCommentSheet({
    super.key,
    required this.contentId,
    required this.isScene,
    required this.scrollController,
  });

  final String contentId;
  final bool isScene;
  final ScrollController scrollController;

  static Future<void> show(
    BuildContext context, {
    required String contentId,
    required bool isScene,
  }) {
    final c = context.studio;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      barrierColor: c.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: StudioSize.sheetMaxHeightFactor,
        expand: false,
        builder: (context, scrollController) => PieceCommentSheet(
          contentId: contentId,
          isScene: isScene,
          scrollController: scrollController,
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

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      children: [
        const SizedBox(height: 10),
        const StudioSheetGrabber(),
        const SizedBox(height: 12),
        Text(
          'Comments',
          style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
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
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
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
        return _CommentTile(comment: comments[index]);
      },
    );
  }

  /// `Conversation` composer: 1 px rule above, 10 12 padding, 42 pill field on Paper
  /// (15, placeholder tertiary), 8 gap, 40 round send (Line until there is text, then Ink).
  Widget _buildInputBar(StudioColors c) {
    final loggedIn = AuthSession.instance.isLoggedIn;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final canSend = loggedIn && !_sending && _textController.text.trim().isNotEmpty;
    final style = StudioType.sans(15, color: c.textPrimary);
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        keyboard > 0 ? keyboard + 10 : (safe > 0 ? safe : StudioSize.noInsetBottomPadding),
      ),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(21)),
              child: TextField(
                controller: _textController,
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
                  hintText: loggedIn ? 'Add a comment…' : 'Log in to comment',
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
  const _CommentTile({required this.comment});

  final CommentSummary comment;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final canNavigate = comment.authorUsername != null && comment.authorUsername!.trim().isNotEmpty;
    void onTapAuthor() => openUserProfile(context, comment.authorUsername);
    final me = AuthSession.instance.user?.username.toLowerCase();
    // Only real (server-saved) comments by someone else can be reported.
    final canReport =
        comment.id.isNotEmpty &&
        !comment.id.startsWith('local-') &&
        (me == null || comment.authorUsername?.toLowerCase() != me);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: canNavigate ? onTapAuthor : null,
            behavior: canNavigate ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
            child: StudioAvatar(url: comment.authorAvatarUrl, size: 32),
          ),
          const SizedBox(width: 10),
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
                    const SizedBox(width: 8),
                    // Times are facts: Geist Mono.
                    Text(
                      _timeAgo(comment.createdAt),
                      style: StudioType.mono11(color: c.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: StudioType.body14(height: 1.45, color: c.textPrimary)),
              ],
            ),
          ),
          if (canReport)
            Semantics(
              button: true,
              label: 'More',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showContentActionsSheet(
                  context,
                  target: ReportTarget.comment(comment.id),
                  authorUsername: comment.authorUsername,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: StudioIcon(StudioIcons.more, size: 18, color: c.textTertiary),
                  ),
                ),
              ),
            ),
        ],
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

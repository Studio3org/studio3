import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/comment_page.dart';
import '../../models/feed_item.dart';
import '../../services/auth_session.dart';
import '../../services/chat_socket_service.dart';
import '../../services/social_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/profile_navigation.dart';
import '../profile_avatar.dart';

/// Instagram-style comment list + add-comment bottom sheet for a piece or
/// scene. List/create only — no like/reply (backend has no API for those).
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
    ChatSocketService.instance.joinTarget(
      targetType: _targetType,
      targetId: widget.contentId,
    );
    ChatSocketService.instance.onCommentNew(_onLiveComment);
    _loadInitial();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    ChatSocketService.instance.leaveTarget(
      targetType: _targetType,
      targetId: widget.contentId,
    );
    ChatSocketService.instance.offCommentNew();
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
        ? SocialService.instance
            .getPostComments(widget.contentId, cursor: cursor)
        : SocialService.instance
            .getPieceComments(widget.contentId, cursor: cursor);
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
          : await SocialService.instance
              .commentOnPiece(widget.contentId, body);
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((c) => c.id == tempId);
        if (index != -1) {
          _comments[index] = saved;
        } else if (!_comments.any((c) => c.id == saved.id)) {
          // Socket may have already inserted the real comment.
          _comments.insert(0, saved);
        }
        _comments.removeWhere(
          (c) => c.id != saved.id && c.id == tempId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == tempId);
        _textController.text = body;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Comments',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE8E5DF)),
          Expanded(child: _buildList()),
          const Divider(height: 1, color: Color(0xFFE8E5DF)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.inter(color: HomeFeedTokens.textSecondary),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet',
          style: GoogleFonts.inter(color: HomeFeedTokens.textSecondary),
        ),
      );
    }
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _comments.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
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
        return _CommentTile(comment: _comments[index]);
      },
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: HomeFeedTokens.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: HomeFeedTokens.textSecondary,
                ),
                filled: true,
                fillColor: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            color: HomeFeedTokens.textPrimary,
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
    final canNavigate = comment.authorUsername != null &&
        comment.authorUsername!.trim().isNotEmpty;
    void onTapAuthor() => openUserProfile(context, comment.authorUsername);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: canNavigate ? onTapAuthor : null,
            behavior: canNavigate
                ? HitTestBehavior.opaque
                : HitTestBehavior.deferToChild,
            child: ProfileAvatar(url: comment.authorAvatarUrl, size: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: canNavigate ? onTapAuthor : null,
                      behavior: canNavigate
                          ? HitTestBehavior.opaque
                          : HitTestBehavior.deferToChild,
                      child: Text(
                        (comment.authorName != null &&
                                comment.authorName!.isNotEmpty)
                            ? comment.authorName!
                            : (comment.authorUsername ?? 'User'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ],
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

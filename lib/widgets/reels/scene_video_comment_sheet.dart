import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/social_service.dart';
import '../../theme/home_feed_tokens.dart';

class SceneVideoCommentSheet extends StatefulWidget {
  const SceneVideoCommentSheet({
    super.key,
    required this.postId,
    required this.authorName,
  });

  final String postId;
  final String authorName;

  static Future<bool?> show(
    BuildContext context, {
    required String postId,
    required String authorName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SceneVideoCommentSheet(
          postId: postId,
          authorName: authorName,
        ),
      ),
    );
  }

  @override
  State<SceneVideoCommentSheet> createState() => _SceneVideoCommentSheetState();
}

class _SceneVideoCommentSheetState extends State<SceneVideoCommentSheet> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await SocialService.instance.commentOnPost(widget.postId, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comment on ${widget.authorName}\'s scene',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _posting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: HomeFeedTokens.textPrimary,
                foregroundColor: HomeFeedTokens.textInverse,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Post comment',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

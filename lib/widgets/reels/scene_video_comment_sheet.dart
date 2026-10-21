import 'package:flutter/material.dart';

import '../../services/social_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';

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
      backgroundColor: context.studio.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
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
    final c = context.studio;
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
                  color: c.lineStrong,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comment on ${widget.authorName}\'s scene',
              style: StudioType.body15(color: c.textPrimary).copyWith(
                fontWeight: StudioType.medium,
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
              style: StudioType.body14(color: c.textPrimary),
              cursorColor: c.textPrimary,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: StudioType.body14(color: c.textSecondary),
                filled: true,
                fillColor: c.surface,
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
                backgroundColor: c.buttonFill,
                foregroundColor: c.buttonText,
                disabledBackgroundColor: c.buttonDisabledFill,
                disabledForegroundColor: c.buttonDisabledText,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(StudioRadius.button),
                ),
              ),
              child: _posting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.buttonText,
                      ),
                    )
                  : Text(
                      'Post comment',
                      style: StudioType.body14(weight: StudioType.medium),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

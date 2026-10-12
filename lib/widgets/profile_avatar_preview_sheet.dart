import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';
import '../utils/profile_photo_upload.dart';
import 'profile_avatar.dart';

/// Shows an enlarged profile avatar. When [allowChange] is true, a Change button
/// lets the user pick and upload a new profile photo.
Future<void> showProfileAvatarPreview(
  BuildContext context, {
  required String? avatarUrl,
  required bool allowChange,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ProfileAvatarPreviewSheet(
        avatarUrl: avatarUrl,
        allowChange: allowChange,
        onChanged: onChanged,
      );
    },
  );
}

class _ProfileAvatarPreviewSheet extends StatefulWidget {
  const _ProfileAvatarPreviewSheet({
    required this.avatarUrl,
    required this.allowChange,
    this.onChanged,
  });

  final String? avatarUrl;
  final bool allowChange;
  final VoidCallback? onChanged;

  @override
  State<_ProfileAvatarPreviewSheet> createState() =>
      _ProfileAvatarPreviewSheetState();
}

class _ProfileAvatarPreviewSheetState extends State<_ProfileAvatarPreviewSheet> {
  static const _previewSize = 140.0;

  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;
  }

  Future<void> _changePhoto() async {
    final url = await pickAndUploadProfilePhoto(context);
    if (!mounted || url == null) return;
    setState(() => _avatarUrl = url);
    widget.onChanged?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                url: _avatarUrl,
                size: _previewSize,
              ),
              if (widget.allowChange) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _changePhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeFeedTokens.textPrimary,
                    foregroundColor: HomeFeedTokens.textInverse,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        HomeFeedTokens.cardRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

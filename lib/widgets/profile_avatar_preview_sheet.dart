import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import '../utils/profile_photo_upload.dart';
import 'studio/studio_avatar.dart';
import 'studio/studio_button.dart';

/// Shows an enlarged profile avatar. When [allowChange] is true, a Change button
/// lets the user pick and upload a new profile photo.
///
/// No board: the sheet scrim behind a round avatar and an inline (44) Ink button.
Future<void> showProfileAvatarPreview(
  BuildContext context, {
  required String? avatarUrl,
  required bool allowChange,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // The page below dims once, with the sheet scrim drawn by the sheet itself.
    barrierColor: Colors.transparent,
    elevation: 0,
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
  State<_ProfileAvatarPreviewSheet> createState() => _ProfileAvatarPreviewSheetState();
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
        color: context.studio.scrim,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioAvatar(url: _avatarUrl, size: _previewSize, semanticLabel: 'Profile photo'),
              if (widget.allowChange) ...[
                const SizedBox(height: 20),
                StudioButton(
                  label: 'Change',
                  variant: StudioButtonVariant.inline,
                  expand: false,
                  onPressed: _changePhoto,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import 'profile_cover_image.dart';
import 'studio/studio_avatar.dart';
import 'studio/studio_icon.dart';
import 'studio/studio_on_image.dart';

/// Edit-profile header: the cover photo full width with the avatar overlapping its bottom
/// edge. The cover's camera is a white icon over the image (no circle, `HandoffRules` "Top of
/// images"); the avatar's is a small Ink badge ringed in the page colour. Purely
/// presentational — callers own the upload flow via [onChangeCover]/[onChangeAvatar].
class ProfileEditHeader extends StatelessWidget {
  const ProfileEditHeader({
    super.key,
    required this.coverUrl,
    required this.avatarUrl,
    required this.onChangeCover,
    required this.onChangeAvatar,
  });

  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onChangeCover;
  final VoidCallback onChangeAvatar;

  static const _coverHeight = 180.0;
  static const _avatarSize = 88.0;
  static const _avatarRing = 4.0;
  static const _avatarOuter = _avatarSize + _avatarRing * 2;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: _coverHeight + _avatarOuter / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onChangeCover,
              child: ProfileCoverImage(url: coverUrl, width: width, height: _coverHeight),
            ),
          ),
          Positioned(
            right: 6,
            top: _coverHeight - 50,
            child: StudioTopIcon(
              icon: StudioIcons.camera,
              size: 22,
              onTap: onChangeCover,
              semanticLabel: 'Change cover photo',
            ),
          ),
          Positioned(
            left: 20,
            bottom: 0,
            child: Semantics(
              button: true,
              label: 'Change profile photo',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onChangeAvatar,
                child: Container(
                  padding: const EdgeInsets.all(_avatarRing),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.background),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      StudioAvatar(url: avatarUrl, size: _avatarSize, semanticLabel: 'Profile photo'),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c.textPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 2),
                          ),
                          child: Center(child: StudioIcon(StudioIcons.camera, size: 15, color: c.background)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_button.dart';
import '../studio/studio_field.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_on_image.dart';
import '../studio/studio_tooltip.dart';
import 'post_flow_widgets.dart';

/// A piece linked to the Scene being posted.
class SceneLinkedPiece {
  const SceneLinkedPiece({required this.id, required this.title, this.imageUrl});

  final String id;
  final String title;
  final String? imageUrl;
}

/// Scene details (`ScenePhotoDetails`, `SceneDetails`): the one details screen of Flow 5,
/// then Post — no review. Only the media is required, so Post is on from the start.
///
/// 96 × 170 preview (the video length on it for a video), "Caption · optional" over a
/// centred 16/1.45 field, Linked pieces as 84 × 112 tiles with × to unlink and a dashed
/// Link a piece tile, the location row ("Optional. Only a city is ever shown."), Post.
class SceneDetailsStep extends StatelessWidget {
  const SceneDetailsStep({
    super.key,
    required this.preview,
    required this.captionController,
    required this.linkedPieces,
    required this.location,
    required this.onBack,
    required this.onLinkPiece,
    required this.onUnlink,
    required this.onLocation,
    required this.onPost,
    this.videoLength,
    this.posting = false,
    this.previewAspect = 9 / 16,
  });

  final Widget preview;
  final double previewAspect;

  /// "0:42" on a video's preview.
  final String? videoLength;
  final TextEditingController captionController;
  final List<SceneLinkedPiece> linkedPieces;
  final String? location;
  final VoidCallback onBack;
  final VoidCallback onLinkPiece;
  final ValueChanged<SceneLinkedPiece> onUnlink;
  final VoidCallback onLocation;
  final VoidCallback onPost;
  final bool posting;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final hasLocation = location != null && location!.isNotEmpty;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostStepHeader(onBack: onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 96,
                        height: 170,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PostCoverFit(aspect: previewAspect, child: preview),
                              if (videoLength != null)
                                Positioned(
                                  left: -2,
                                  bottom: -2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: StudioImageLabel(videoLength!, size: 10),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Caption '),
                          TextSpan(
                            text: '· optional',
                            style: TextStyle(color: c.textPlaceholder),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.lineStrong)),
                      ),
                      child: TextField(
                        controller: captionController,
                        textAlign: TextAlign.center,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: StudioType.sans(16, height: 1.45, color: c.textPrimary),
                        cursorColor: c.textPrimary,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Every piece has a behind-the-scenes. This is yours…',
                          hintMaxLines: 3,
                          hintStyle: StudioType.sans(
                            16,
                            height: 1.45,
                            color: c.textPlaceholder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    StudioTooltip(
                      message:
                          'Link the pieces this Scene is about. It shows on each one, under '
                          'The story behind this piece.',
                      builder: (context, toggle) => Row(
                        children: [
                          Text(
                            'Linked pieces',
                            style: StudioType.sans(
                              17,
                              weight: StudioType.medium,
                              color: c.textPrimary,
                            ),
                          ),
                          StudioInfoButton(
                            onTap: toggle,
                            semanticLabel: 'What is linked pieces?',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final piece in linkedPieces) ...[
                            _LinkedTile(piece: piece, onUnlink: () => onUnlink(piece)),
                            const SizedBox(width: 10),
                          ],
                          _LinkTile(onTap: onLinkPiece),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This Scene will show on each linked piece, under The story behind this '
                      'piece.',
                      style: StudioType.caption12(height: 1.45, color: c.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: onLocation,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: c.line),
                              bottom: BorderSide(color: c.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location',
                                      style: StudioType.sans(16, color: c.textPrimary),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Optional. Only a city is ever shown.',
                                      style: StudioType.caption12(color: c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hasLocation ? location! : 'Add a city',
                                style: StudioType.body14(
                                  color: hasLocation ? c.textPrimary : c.textPlaceholder,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StudioIcon(
                                StudioIcons.chevronRight,
                                size: 16,
                                color: c.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PostBottomAction(
              button: StudioButton(
                label: 'Post',
                height: 54,
                loading: posting,
                onPressed: posting ? null : onPost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 84 × 112 cover (radius 8) with a 22 × to unlink, the title 12/1.3 under it.
class _LinkedTile extends StatelessWidget {
  const _LinkedTile({required this.piece, required this.onUnlink});

  final SceneLinkedPiece piece;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = piece.imageUrl;
    return SizedBox(
      width: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            height: 112,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url == null || url.isEmpty)
                    ColoredBox(color: c.surface)
                  else
                    FeedPicsumImage(url: url),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                      button: true,
                      label: 'Unlink ${piece.title}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: onUnlink,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x8C111111),
                          ),
                          child: const StudioIcon(
                            StudioIcons.unlink,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            piece.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: StudioType.sans(12, height: 1.3, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 84 × 112 dashed tile (1 px Line Strong, radius 8): a plus and "Link a piece" 12.
class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: 'Link a piece',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: PostDashedBorder(
          color: c.lineStrong,
          child: SizedBox(
            width: 84,
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StudioIcon(StudioIcons.newFolder, size: 20, color: c.textSecondary),
                const SizedBox(height: 6),
                Text('Link a piece', style: StudioType.caption12(color: c.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

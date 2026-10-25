import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_button.dart';
import '../studio/studio_chip.dart';
import '../studio/studio_icon.dart';
import 'post_flow_widgets.dart';

/// Close 22 at the top right (12 8 padding).
class _CloseBar extends StatelessWidget {
  const _CloseBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: PostIconButton(icon: StudioIcons.close, label: 'Close', onTap: onClose),
      ),
    );
  }
}

/// 1 px Line card, radius 14, 12 14 padding: [leading], then a 15/500 title over a 13
/// Graphite line, and an optional chevron (`PostSuccess` "Add a Scene from the studio",
/// `ScenePhotoPosted` "Now showing on N pieces").
class PostActionCard extends StatelessWidget {
  const PostActionCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.chevron = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(StudioRadius.panel),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (chevron) ...[
                const SizedBox(width: 8),
                StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "[Title] is live" (`PostSuccess`, `PostNFSDone`): the feed card as collectors see it
/// (photo 300 tall with the photo dots, avatar 32, name 14/500, title 13, and Available +
/// price or Not for sale), then Add a Scene, Share your piece and View piece.
class PostPublishedView extends StatelessWidget {
  const PostPublishedView({
    super.key,
    required this.title,
    required this.cover,
    required this.photoCount,
    required this.authorName,
    required this.avatarUrl,
    required this.priceLabel,
    required this.onClose,
    required this.onAddScene,
    required this.onShare,
    required this.onView,
    this.coverAspect = 3 / 4,
    this.heading,
    this.subheading = "Here's how collectors see it in the feed.",
  });

  final String title;
  final Widget cover;
  final double coverAspect;

  /// "[title] is live" by default; "[title] is listed" after listing later (`ListDone`).
  final String? heading;
  final String subheading;
  final int photoCount;
  final String authorName;
  final String? avatarUrl;

  /// "$3,600" for a sale; null shows Not for sale.
  final String? priceLabel;
  final VoidCallback onClose;
  final VoidCallback onAddScene;
  final VoidCallback onShare;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CloseBar(onClose: onClose),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      heading ?? '$title is live',
                      style: StudioType.title30(color: c.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subheading,
                      style: StudioType.sans(15, color: c.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    _FeedPreview(
                      cover: cover,
                      coverAspect: coverAspect,
                      photoCount: photoCount,
                      authorName: authorName,
                      avatarUrl: avatarUrl,
                      title: title,
                      priceLabel: priceLabel,
                    ),
                  ],
                ),
              ),
            ),
            PostBottomAction(
              bottom: 32,
              gap: 0,
              button: StudioButton(
                label: 'Share your piece',
                icon: StudioIcons.shareBold,
                height: 54,
                onPressed: onShare,
              ),
              caption: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 36,
                    child: PostTextLink(label: 'View piece', onTap: onView, height: 36),
                  ),
                ],
              ),
            ).withLeading(
              PostActionCard(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(StudioRadius.card),
                  ),
                  child: Center(
                    child: StudioIcon(StudioIcons.newFolder, size: 20, color: c.textPrimary),
                  ),
                ),
                title: 'Add a Scene from the studio',
                subtitle: 'Process posts help people find this piece.',
                onTap: onAddScene,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on PostBottomAction {
  /// The bottom block with a card 12 above the button.
  Widget withLeading(Widget card) => Builder(
    builder: (context) {
      final inset = MediaQuery.viewPaddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, inset > bottom ? inset : bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            const SizedBox(height: 12),
            button,
            if (caption != null) ...[const SizedBox(height: 12), caption!],
          ],
        ),
      );
    },
  );
}

class _FeedPreview extends StatelessWidget {
  const _FeedPreview({
    required this.cover,
    required this.coverAspect,
    required this.photoCount,
    required this.authorName,
    required this.avatarUrl,
    required this.title,
    required this.priceLabel,
  });

  final Widget cover;
  final double coverAspect;
  final int photoCount;
  final String authorName;
  final String? avatarUrl;
  final String title;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      label: 'Feed preview',
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: c.line, offset: const Offset(0, 1)),
            const BoxShadow(color: Color(0x14111111), offset: Offset(0, 18), blurRadius: 40),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PostCoverFit(aspect: coverAspect, child: cover),
                  if (photoCount > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(child: FeedDotIndicators(count: photoCount, page: 0)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  StudioAvatar(url: avatarUrl, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.body14(
                            weight: StudioType.medium,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.label13(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (priceLabel != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const StudioStatusChip(StudioStatus.available),
                        const SizedBox(height: 4),
                        Text(
                          priceLabel!,
                          style: StudioType.label13(
                            weight: StudioType.medium,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    )
                  else
                    const StudioStatusChip(StudioStatus.notForSale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A piece a Scene shows on, for the posted screen.
class LinkedPieceThumb {
  const LinkedPieceThumb({required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;
}

/// "Your Scene is live" (`ScenePhotoPosted`, `ScenePosted`): the 240 × 427 Scene card
/// (the first linked piece inset, the author bar, a play mark on video), "Now showing on N
/// pieces" only when linked, Share your Scene and View Scene.
class SceneLiveView extends StatelessWidget {
  const SceneLiveView({
    super.key,
    required this.preview,
    required this.isVideo,
    required this.authorName,
    required this.avatarUrl,
    required this.linkedPieces,
    required this.onClose,
    required this.onShare,
    required this.onView,
    this.onLinked,
    this.previewAspect = 9 / 16,
  });

  final Widget preview;
  final double previewAspect;
  final bool isVideo;
  final String authorName;
  final String? avatarUrl;
  final List<LinkedPieceThumb> linkedPieces;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onView;
  final VoidCallback? onLinked;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final first = linkedPieces.isEmpty ? null : linkedPieces.first;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CloseBar(onClose: onClose),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your Scene is live', style: StudioType.title30(color: c.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      "Here's how people see it in Behind the work.",
                      style: StudioType.sans(15, color: c.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 240,
                        height: 427,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24111111),
                              offset: Offset(0, 18),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PostCoverFit(aspect: previewAspect, child: preview),
                              if (isVideo)
                                const Positioned(
                                  top: 10,
                                  left: 10,
                                  child: StudioIcon(
                                    StudioIcons.video,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              if (first != null)
                                Positioned(
                                  right: 12,
                                  bottom: 50,
                                  child: Container(
                                    width: 40,
                                    height: 53,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: _Thumb(url: first.imageUrl),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  color: StudioColors.imageCaptionBar,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: [
                                      StudioAvatar(
                                        url: avatarUrl,
                                        size: 24,
                                        ringWidth: 1.5,
                                        ringColor: Colors.white,
                                        ringInside: true,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: StudioType.label13(
                                            weight: StudioType.medium,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
            Builder(
              builder: (context) {
                final inset = MediaQuery.viewPaddingOf(context).bottom;
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, inset > 32 ? inset : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (linkedPieces.isNotEmpty) ...[
                        PostActionCard(
                          leading: _Stack(pieces: linkedPieces),
                          title:
                              'Now showing on ${linkedPieces.length} '
                              '${linkedPieces.length == 1 ? 'piece' : 'pieces'}',
                          subtitle: linkedPieces.map((p) => p.title).join(', '),
                          chevron: onLinked != null,
                          onTap: onLinked ?? () {},
                        ),
                        const SizedBox(height: 12),
                      ],
                      StudioButton(
                        label: 'Share your Scene',
                        icon: StudioIcons.shareBold,
                        height: 54,
                        onPressed: onShare,
                      ),
                      const SizedBox(height: 12),
                      PostTextLink(label: 'View Scene', onTap: onView, height: 36),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return ColoredBox(color: context.studio.surface);
    return FeedPicsumImage(url: u, fit: BoxFit.cover);
  }
}

/// Up to two 30 × 40 piece thumbs (radius 5, 2 px Paper border), the second 10 over.
class _Stack extends StatelessWidget {
  const _Stack({required this.pieces});

  final List<LinkedPieceThumb> pieces;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final shown = pieces.take(2).toList();
    return SizedBox(
      width: 30 + (shown.length - 1) * 20,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20,
              child: Container(
                width: 30,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: c.background, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _Thumb(url: shown[i].imageUrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Couldn't publish" (`PostError`): an Ink-ringed "!" (no red), the reason, and when the
/// piece was saved first, "Saved as draft · [time]" in Mono with Go to drafts. Try again
/// retries.
class PostErrorView extends StatelessWidget {
  const PostErrorView({
    super.key,
    required this.isScene,
    required this.savedAt,
    required this.onClose,
    required this.onRetry,
    required this.onDrafts,
    this.retrying = false,
  });

  final bool isScene;

  /// When the draft was saved; null when nothing was.
  final DateTime? savedAt;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback onDrafts;
  final bool retrying;

  static String formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final saved = savedAt;
    final message = saved != null
        ? 'The connection dropped before it went live. Your piece is saved as a draft, '
              'so nothing is lost.'
        : isScene
        ? "The connection dropped before your Scene went up. Check your connection and "
              'try again.'
        : "The connection dropped before your piece was saved. Check your connection and "
              'try again.';
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CloseBar(onClose: onClose),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 200, 32, 24),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.textPrimary, width: 1.5),
                      ),
                      child: Text(
                        '!',
                        style: StudioType.sans(22, weight: StudioType.medium, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isScene ? "Couldn't post" : "Couldn't publish",
                      textAlign: TextAlign.center,
                      style: StudioType.sans(
                        28,
                        weight: StudioType.medium,
                        height: 1.1,
                        letterSpacing: -0.5,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
                    ),
                    if (saved != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Saved as draft · ${formatTime(saved)}',
                        style: StudioType.mono11(color: c.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final inset = MediaQuery.viewPaddingOf(context).bottom;
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, inset > 32 ? inset : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StudioButton(
                        label: 'Try again',
                        height: 54,
                        loading: retrying,
                        onPressed: retrying ? null : onRetry,
                      ),
                      if (saved != null) ...[
                        const SizedBox(height: 4),
                        PostTextLink(label: 'Go to drafts', onTap: onDrafts),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

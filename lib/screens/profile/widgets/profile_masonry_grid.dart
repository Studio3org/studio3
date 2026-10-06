import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../models/feed_item.dart';
import '../../../models/feed_preview_item.dart';
import '../../../models/piece_summary.dart';
import '../../../models/post_summary.dart';
import '../../../utils/explore_detail_route.dart';
import '../../../utils/slide_up_page_route.dart';
import '../../available_piece_detail_page.dart';
import '../../piece_detail_page.dart';
import '../profile_constants.dart';

class ProfileContentGrid extends StatelessWidget {
  const ProfileContentGrid._({
    required this.items,
    this.onPostTap,
    this.onPieceTap,
    this.onDeletePost,
    this.onDeletePiece,
    this.onPublishPost,
    this.onPublishPiece,
    this.showOwnerActions = false,
  });

  final List<
    ({
      String? url,
      double ratio,
      bool forSale,
      String? price,
      bool isVideo,
      bool isDraft,
      PostSummary? post,
      PieceSummary? piece,
    })
  >
  items;
  final void Function(PostSummary post)? onPostTap;
  final void Function(PieceSummary piece)? onPieceTap;
  final void Function(PostSummary post)? onDeletePost;
  final void Function(PieceSummary piece)? onDeletePiece;
  final void Function(PostSummary post)? onPublishPost;
  final void Function(PieceSummary piece)? onPublishPiece;
  final bool showOwnerActions;

  factory ProfileContentGrid.fromPieces(
    List<PieceSummary> pieces, {
    void Function(PieceSummary piece)? onPieceTap,
    void Function(PieceSummary piece)? onDeletePiece,
    void Function(PieceSummary piece)? onPublishPiece,
    bool showOwnerActions = false,
    bool forSaleListing = false,
  }) {
    final mapped =
        <
          ({
            String? url,
            double ratio,
            bool forSale,
            String? price,
            bool isVideo,
            bool isDraft,
            PostSummary? post,
            PieceSummary? piece,
          })
        >[];
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      mapped.add((
        url: p.mediaUrl,
        ratio:
            kProfileMasonryHeightRatios[i % kProfileMasonryHeightRatios.length],
        forSale: forSaleListing || p.isForSale,
        price: p.priceDisplay,
        isVideo: false,
        isDraft: p.status == 'draft',
        post: null,
        piece: p,
      ));
    }
    return ProfileContentGrid._(
      items: mapped,
      onPieceTap: onPieceTap,
      onDeletePiece: onDeletePiece,
      onPublishPiece: onPublishPiece,
      showOwnerActions: showOwnerActions,
    );
  }

  factory ProfileContentGrid.fromPosts(
    List<PostSummary> posts, {
    void Function(PostSummary post)? onPostTap,
    void Function(PostSummary post)? onDeletePost,
    void Function(PostSummary post)? onPublishPost,
    bool showOwnerActions = false,
  }) {
    final mapped =
        <
          ({
            String? url,
            double ratio,
            bool forSale,
            String? price,
            bool isVideo,
            bool isDraft,
            PostSummary? post,
            PieceSummary? piece,
          })
        >[];
    for (var i = 0; i < posts.length; i++) {
      final p = posts[i];
      final mediaType = p.mediaType?.toLowerCase();
      final isVideo =
          mediaType == 'video' || mediaType == 'reel' || mediaType == 'reels';
      mapped.add((
        url: p.mediaUrl,
        ratio:
            kProfileMasonryHeightRatios[i % kProfileMasonryHeightRatios.length],
        forSale: false,
        price: null,
        isVideo: isVideo,
        isDraft: p.status == 'draft',
        post: p,
        piece: null,
      ));
    }
    return ProfileContentGrid._(
      items: mapped,
      onPostTap: onPostTap,
      onDeletePost: onDeletePost,
      onPublishPost: onPublishPost,
      showOwnerActions: showOwnerActions,
    );
  }

  /// A sliver — must be placed directly in a `CustomScrollView.slivers` list
  /// (or a `SliverPadding`'s `sliver:`), not wrapped in `SliverToBoxAdapter`.
  /// Uses `SliverMasonryGrid.count`'s builder delegate so off-screen tiles
  /// are never built/laid out/painted — unlike the previous plain-`Column`
  /// implementation, which built every tile eagerly regardless of scroll
  /// position, this scales to large collections without the up-front cost.
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: kProfileGutter,
      crossAxisSpacing: kProfileGutter,
      childCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final colW =
            (MediaQuery.sizeOf(context).width -
                kProfileHorizontalPad * 2 -
                kProfileGutter) /
            2;
        return _MasonryTile(
          url: item.url,
          height: colW * item.ratio,
          forSale: item.forSale,
          price: item.price,
          isVideo: item.isVideo,
          isDraft: item.isDraft,
          onTap: item.post != null
              ? () => onPostTap?.call(item.post!)
              : item.piece != null
              ? () => onPieceTap?.call(item.piece!)
              : null,
          onDelete: !showOwnerActions
              ? null
              : item.post != null
              ? () => onDeletePost?.call(item.post!)
              : item.piece != null
              ? () => onDeletePiece?.call(item.piece!)
              : null,
          onPublish: !showOwnerActions || !item.isDraft
              ? null
              : item.post != null
              ? () => onPublishPost?.call(item.post!)
              : item.piece != null
              ? () => onPublishPiece?.call(item.piece!)
              : null,
        );
      },
    );
  }
}

class _MasonryTile extends StatelessWidget {
  const _MasonryTile({
    required this.url,
    required this.height,
    this.forSale = false,
    this.price,
    this.isVideo = false,
    this.isDraft = false,
    this.onTap,
    this.onDelete,
    this.onPublish,
  });

  final String? url;
  final double height;
  final bool forSale;
  final String? price;
  final bool isVideo;
  final bool isDraft;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPublish;

  bool get _hasActions => onDelete != null || onPublish != null;

  void _showActions(BuildContext context) {
    if (!_hasActions) return;
    final publish = onPublish;
    final delete = onDelete;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (publish != null)
              ListTile(
                leading: const Icon(
                  Icons.publish_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Publish',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  publish();
                },
              ),
            if (delete != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE05252),
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Color(0xFFE05252),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  delete();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: _hasActions ? () => _showActions(context) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kProfileCardRadius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null && url!.isNotEmpty && !isVideo)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      ((MediaQuery.sizeOf(context).width / 2) *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorWidget: (context, error, stackTrace) => ColoredBox(
                    color: Colors.grey.shade300,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: isVideo ? Colors.black : Colors.grey.shade300,
                ),
              if (isVideo)
                Container(
                  color: Colors.black.withValues(alpha: 0.22),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              if (forSale && price != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      price!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (isDraft)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Draft',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_hasActions)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _showActions(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void openProfileScene(
  BuildContext context,
  List<PostSummary> scenes,
  PostSummary post,
) {
  final item = FeedItem.post(post);
  openExploreDetail(context, item);
}

void openProfilePiece(BuildContext context, PieceSummary piece) {
  final preview = FeedPreviewItem.fromPieceSummary(piece);
  final page = preview.isAvailable
      ? AvailablePieceDetailPage(item: preview)
      : PieceDetailPage(item: preview);
  Navigator.of(context).push<void>(SlideUpPageRoute<void>(page: page));
}

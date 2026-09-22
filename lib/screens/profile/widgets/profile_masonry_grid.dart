import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../data/nav_assets.dart';
import '../../../theme/home_feed_tokens.dart';

import '../../../models/feed_item.dart';
import '../../../models/feed_preview_item.dart';
import '../../../models/piece_summary.dart';
import '../../../models/post_summary.dart';
import '../../../utils/explore_detail_route.dart';
import '../../../utils/slide_up_page_route.dart';
import '../../available_piece_detail_page.dart';
import '../../piece_detail_page.dart';
import '../profile_constants.dart';

/// What a tile says about a piece's place in the marketplace, shown as a
/// dot + label under the image. Scenes and unlisted pieces carry none.
enum ProfileTileListing {
  none,
  available,
  biddingOpen,
  sold;

  static ProfileTileListing forPiece(PieceSummary piece) {
    if (piece.isAvailableListing) return ProfileTileListing.available;
    if (piece.isAuctionLive) return ProfileTileListing.biddingOpen;
    if (piece.isCollectedListing || piece.isAuctionEnded) {
      return ProfileTileListing.sold;
    }
    return ProfileTileListing.none;
  }

  String get label => switch (this) {
        ProfileTileListing.available => 'Available',
        ProfileTileListing.biddingOpen => 'Bidding open',
        ProfileTileListing.sold => 'Sold',
        ProfileTileListing.none => '',
      };

  String get iconAsset => this == ProfileTileListing.sold
      ? NavAssets.collectedMark
      : NavAssets.availableDot;
}

/// One cell of the profile grid.
class _ProfileTileData {
  const _ProfileTileData({
    required this.url,
    required this.ratio,
    required this.isVideo,
    required this.isDraft,
    this.listing = ProfileTileListing.none,
    this.post,
    this.piece,
  });

  /// Image to draw. For a video this is the poster frame, not the video.
  final String? url;

  /// Tile height as a multiple of column width.
  final double ratio;
  final bool isVideo;
  final bool isDraft;
  final ProfileTileListing listing;
  final PostSummary? post;
  final PieceSummary? piece;
}

class ProfileContentGrid extends StatelessWidget {
  const ProfileContentGrid._({
    required List<_ProfileTileData> items,
    this.onPostTap,
    this.onPieceTap,
    this.onDeletePost,
    this.onDeletePiece,
    this.onPublishPost,
    this.onPublishPiece,
    this.showOwnerActions = false,
  }) : _items = items;

  final List<_ProfileTileData> _items;
  final void Function(PostSummary post)? onPostTap;
  final void Function(PieceSummary piece)? onPieceTap;
  final void Function(PostSummary post)? onDeletePost;
  final void Function(PieceSummary piece)? onDeletePiece;
  final void Function(PostSummary post)? onPublishPost;
  final void Function(PieceSummary piece)? onPublishPiece;
  final bool showOwnerActions;

  /// Pieces are captured and cropped at 3:4, so every tile is drawn at that
  /// ratio — the grid shows the work at the shape it was actually posted in
  /// rather than cropping it into the old rotating masonry rhythm, which
  /// squared some pieces off and letterboxed others.
  static const _pieceRatio = 4 / 3;

  factory ProfileContentGrid.fromPieces(
    List<PieceSummary> pieces, {
    void Function(PieceSummary piece)? onPieceTap,
    void Function(PieceSummary piece)? onDeletePiece,
    void Function(PieceSummary piece)? onPublishPiece,
    bool showOwnerActions = false,
  }) {
    return ProfileContentGrid._(
      items: [
        for (final p in pieces)
          _ProfileTileData(
            url: p.mediaUrl,
            ratio: _pieceRatio,
            isVideo: false,
            isDraft: p.status == 'draft',
            listing: ProfileTileListing.forPiece(p),
            piece: p,
          ),
      ],
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
    return ProfileContentGrid._(
      items: [
        for (var i = 0; i < posts.length; i++)
          _ProfileTileData(
            // A video's own URL is an .mp4 and can't be drawn as an image —
            // passing it here painted every video tile black. The server
            // sends a poster frame for exactly this, which is what Explore
            // has always used.
            url: posts[i].isVideo
                ? (posts[i].thumbnailUrl ?? posts[i].mediaUrl)
                : posts[i].mediaUrl,
            ratio: kProfileMasonryHeightRatios[
                i % kProfileMasonryHeightRatios.length],
            isVideo: posts[i].isVideo,
            isDraft: posts[i].status == 'draft',
            post: posts[i],
          ),
      ],
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
    if (_items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: kProfileGutter,
      crossAxisSpacing: kProfileGutter,
      childCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _MasonryTile(
          url: item.url,
          ratio: item.ratio,
          listing: item.listing,
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
    required this.ratio,
    this.listing = ProfileTileListing.none,
    this.isVideo = false,
    this.isDraft = false,
    this.onTap,
    this.onDelete,
    this.onPublish,
  });

  final String? url;

  /// Tile height as a multiple of its own column width. Applied with
  /// [AspectRatio] so the tile sizes off the constraint it is actually
  /// given — it used to derive a pixel height from
  /// `MediaQuery.sizeOf(context).width` minus the padding the profile
  /// screen happens to apply, which silently produced the wrong shape
  /// anywhere that padding differed.
  final double ratio;
  final ProfileTileListing listing;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
        borderRadius: BorderRadius.circular(kProfileCardRadius),
        child: AspectRatio(
          aspectRatio: 1 / ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // `!isVideo` used to be part of this condition, so a video
              // tile skipped the image entirely and fell through to the
              // black box below — every scene video rendered as a black
              // rectangle with a play button. [url] is the poster frame for
              // a video, so it draws like any other tile; the black box is
              // now only the genuine no-image fallback.
              if (url != null && url!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      ((MediaQuery.sizeOf(context).width / 2) *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorWidget: (context, error, stackTrace) => ColoredBox(
                    color: isVideo ? Colors.black : Colors.grey.shade300,
                    child: isVideo
                        ? null
                        : Icon(
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
          if (listing != ProfileTileListing.none) _ListingLabel(listing: listing),
        ],
      ),
    );
  }
}

/// Dot + word under a piece's tile — "Available", "Bidding open", "Sold".
///
/// Replaces the price chip that used to sit inside the image. A grid of
/// prices reads as a shop listing; what matters at a glance on a profile is
/// simply whether the work can still be had.
class _ListingLabel extends StatelessWidget {
  const _ListingLabel({required this.listing});

  final ProfileTileListing listing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(listing.iconAsset, width: 8, height: 8),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              listing.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kProfileGeist(
                fontSize: 13,
                color: listing == ProfileTileListing.sold
                    ? kProfileTextMuted
                    : HomeFeedTokens.textPrimary,
              ),
            ),
          ),
        ],
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

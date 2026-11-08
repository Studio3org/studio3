import 'package:flutter/material.dart';

import '../../../models/piece_summary.dart';
import '../../../models/post_summary.dart';
import '../../../widgets/feed_skeleton.dart';
import '../../../widgets/pill_chip.dart';
import 'profile_collection_grid.dart';
import 'profile_masonry_grid.dart';
import 'profile_seller_pieces.dart';
import '../models/profile_series_data.dart';

bool _isVideoPost(PostSummary p) {
  final m = p.mediaType?.toLowerCase();
  return m == 'video' || m == 'reel' || m == 'reels';
}

/// What sits under the profile's tabs (`HandoffProfiles`): Pieces (the Series shelf, All with
/// a count, the Available filter when something is for sale, the 3:4 grid), Scenes, or
/// Collection (what they've bought). The same for everyone; an empty tab shows nothing.
class ProfileTabContent extends StatelessWidget {
  const ProfileTabContent({
    super.key,
    required this.currentTab,
    required this.seriesItems,
    this.pieces = const [],
    this.scenes = const [],
    this.collection = const [],
    this.loading = false,
    this.isOwnProfile = false,
    this.onDeletePiece,
    this.onDeleteScene,
    this.onPublishPiece,
    this.onPublishScene,
    this.sceneFilter = 'all',
    this.onSceneFilterChanged,
    this.onSeeAllSeries,
    this.onSeriesTap,
  });

  /// `pieces`, `scenes` or `collection`.
  final String currentTab;
  final List<ProfileSeriesData> seriesItems;
  final List<PieceSummary> pieces;
  final List<PostSummary> scenes;

  /// The pieces they've bought (BACKEND_CHANGES B37).
  final List<PieceSummary> collection;
  final bool loading;
  final bool isOwnProfile;
  final void Function(PieceSummary piece)? onDeletePiece;
  final void Function(PostSummary post)? onDeleteScene;
  final void Function(PieceSummary piece)? onPublishPiece;
  final void Function(PostSummary post)? onPublishScene;
  final String sceneFilter;
  final ValueChanged<String>? onSceneFilterChanged;
  final VoidCallback? onSeeAllSeries;
  final void Function(ProfileSeriesData series)? onSeriesTap;

  /// A sliver — must be placed directly in a `CustomScrollView.slivers` list
  /// (or a `SliverPadding`'s `sliver:`), not wrapped in `SliverToBoxAdapter`.
  @override
  Widget build(BuildContext context) {
    final empty = switch (currentTab) {
      'pieces' => pieces.isEmpty,
      'scenes' => scenes.isEmpty,
      _ => collection.isEmpty,
    };
    if (loading && empty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ProfileGridSkeleton(),
        ),
      );
    }

    if (currentTab == 'pieces') {
      return ProfileSellerPieces(
        pieces: pieces,
        series: seriesItems,
        showOwnerActions: isOwnProfile,
        onPieceTap: (piece) => openProfilePiece(context, piece),
        onDeletePiece: onDeletePiece,
        onPublishPiece: onPublishPiece,
        onSeeAllSeries: onSeeAllSeries,
        onSeriesTap: onSeriesTap,
      );
    }

    if (currentTab == 'scenes') {
      if (scenes.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
      final visibleScenes = sceneFilter == 'videos'
          ? scenes.where(_isVideoPost).toList()
          : scenes;
      final Widget gridSliver = visibleScenes.isNotEmpty
          ? ProfileContentGrid.fromPosts(
              visibleScenes,
              onPostTap: (post) =>
                  openProfileScene(context, visibleScenes, post),
              onDeletePost: onDeleteScene,
              onPublishPost: onPublishScene,
              showOwnerActions: isOwnProfile,
            )
          : const SliverToBoxAdapter(child: SizedBox.shrink());
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  PillChip(
                    label: 'All',
                    selected: sceneFilter != 'videos',
                    onTap: () => onSceneFilterChanged?.call('all'),
                  ),
                  const SizedBox(width: 8),
                  PillChip(
                    label: 'Videos',
                    selected: sceneFilter == 'videos',
                    onTap: () => onSceneFilterChanged?.call('videos'),
                  ),
                ],
              ),
            ),
          ),
          gridSliver,
        ],
      );
    }

    return ProfileCollectionGrid(
      pieces: collection,
      onPieceTap: (piece) => openProfilePiece(context, piece),
    );
  }
}

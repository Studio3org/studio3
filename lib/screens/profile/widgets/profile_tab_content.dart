import 'package:flutter/material.dart';

import '../../../models/piece_summary.dart';
import '../../../models/post_summary.dart';
import '../../../widgets/feed_skeleton.dart';
import '../../../widgets/pill_chip.dart';
import '../profile_constants.dart';
import 'profile_masonry_grid.dart';
import 'profile_series_grid.dart';
import '../models/profile_series_data.dart';

bool _isVideoPost(PostSummary p) {
  final m = p.mediaType?.toLowerCase();
  return m == 'video' || m == 'reel' || m == 'reels';
}

class ProfileTabContent extends StatelessWidget {
  const ProfileTabContent({
    super.key,
    required this.currentTab,
    required this.seriesItems,
    this.pieces = const [],
    this.scenes = const [],
    this.listedPieces = const [],
    this.collectSegment = 'all',
    this.sellerMode = false,
    this.loading = false,
    this.isOwnProfile = false,
    this.onDeletePiece,
    this.onDeleteScene,
    this.onPublishPiece,
    this.onPublishScene,
    this.sceneFilter = 'all',
    this.onSceneFilterChanged,
  });

  final String currentTab;
  final List<ProfileSeriesData> seriesItems;
  final List<PieceSummary> pieces;
  final List<PostSummary> scenes;
  final List<PieceSummary> listedPieces;
  final String collectSegment;
  final bool sellerMode;
  final bool loading;
  final bool isOwnProfile;
  final void Function(PieceSummary piece)? onDeletePiece;
  final void Function(PostSummary post)? onDeleteScene;
  final void Function(PieceSummary piece)? onPublishPiece;
  final void Function(PostSummary post)? onPublishScene;
  final String sceneFilter;
  final ValueChanged<String>? onSceneFilterChanged;

  /// A sliver — must be placed directly in a `CustomScrollView.slivers` list
  /// (or a `SliverPadding`'s `sliver:`), not wrapped in `SliverToBoxAdapter`,
  /// since [ProfileContentGrid]'s masonry grid is itself a lazily-built
  /// sliver now (see `profile_masonry_grid.dart`). Every branch below wraps
  /// its box content (skeleton/empty-state/series grid) in
  /// `SliverToBoxAdapter` so the whole widget always returns a valid sliver.
  @override
  Widget build(BuildContext context) {
    if (loading &&
        (currentTab == 'pieces'
            ? pieces.isEmpty
            : currentTab == 'scenes'
            ? scenes.isEmpty
            : currentTab == 'collect'
            ? listedPieces.isEmpty
            : currentTab == 'series'
            ? seriesItems.isEmpty
            : true)) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ProfileGridSkeleton(),
        ),
      );
    }

    if (currentTab == 'series') {
      return SliverToBoxAdapter(
        child: ProfileSeriesGrid(items: seriesItems, loading: loading),
      );
    }

    if (currentTab == 'pieces') {
      if (pieces.isNotEmpty) {
        return ProfileContentGrid.fromPieces(
          pieces,
          onPieceTap: (piece) => openProfilePiece(context, piece),
          onDeletePiece: onDeletePiece,
          onPublishPiece: onPublishPiece,
          showOwnerActions: isOwnProfile,
        );
      }
      return const SliverToBoxAdapter(
        child: _EmptyState(label: 'No pieces yet'),
      );
    }

    if (currentTab == 'scenes') {
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
          : SliverToBoxAdapter(
              child: _EmptyState(
                label: sceneFilter == 'videos'
                    ? 'No videos yet'
                    : 'No scenes yet',
              ),
            );
      if (scenes.isEmpty) return gridSliver;
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

    if (currentTab == 'collect') {
      if (!sellerMode) {
        return const SliverToBoxAdapter(
          child: _EmptyState(label: 'Switch to Seller to list pieces for sale'),
        );
      }

      final visible = switch (collectSegment) {
        'sold' => listedPieces.where((p) => p.status == 'sold').toList(),
        'available' =>
          listedPieces.where((p) => p.isForSale && p.status != 'sold').toList(),
        _ => listedPieces,
      };

      if (visible.isEmpty) {
        final label = switch (collectSegment) {
          'sold' => 'No sold pieces yet',
          'available' => 'No pieces listed for sale yet',
          _ => 'No collect pieces yet',
        };
        return SliverToBoxAdapter(child: _EmptyState(label: label));
      }

      return ProfileContentGrid.fromPieces(
        visible,
        forSaleListing: collectSegment != 'sold',
        onPieceTap: (piece) => openProfilePiece(context, piece),
      );
    }

    return const SliverToBoxAdapter(child: _EmptyState(label: 'Coming soon'));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: kProfileGeist(fontSize: 13, color: kProfileTextMuted),
        ),
      ),
    );
  }
}

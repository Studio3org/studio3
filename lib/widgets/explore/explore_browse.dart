import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../models/series_summary.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../follow_button.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_icon.dart';
import 'explore_feed_image.dart';

/// A shelf is hidden until it has about this many items (`NoteExplore`).
const exploreShelfMinCount = 6;

/// Medium names already on loaded pieces, most common first.
List<String> exploreMediumNames(List<FeedItem> items) {
  final counts = <String, int>{};
  for (final item in items) {
    final medium = item.piece?.medium?.trim();
    if (medium == null || medium.isEmpty) continue;
    counts[medium] = (counts[medium] ?? 0) + 1;
  }
  final names = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return names;
}

List<FeedItem> filterExploreByMedium(List<FeedItem> items, String? medium) {
  if (medium == null || medium.isEmpty) return items;
  return items.where((item) => item.piece?.medium?.trim() == medium).toList();
}

/// Title, artist, username, or series name on items already loaded.
bool exploreItemMatchesQuery(FeedItem item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  bool has(String? value) => value != null && value.toLowerCase().contains(q);
  return has(item.title) ||
      has(item.authorName) ||
      has(item.authorUsername) ||
      has(item.piece?.series?.name);
}

const explorePieceShelfWidth = 160.0;

/// `HandoffSizes`: fixed width 160, 3:4. The board draws 200; the size rule wins.
const explorePieceShelfImageHeight = explorePieceShelfWidth * 4 / 3;

const exploreSceneShelfWidth = 140.0;

/// `HandoffSizes`: 140 × 249, 9:16.
const exploreSceneShelfHeight = 249.0;

const exploreSeriesShelfWidth = 270.0;
const exploreSeriesShelfImageHeight = 180.0;

const exploreArtistTileWidth = 96.0;
const exploreArtistAvatar = 76.0;

/// Gap inside a shelf, between its title and the scroller (the board's section gap).
const exploreShelfInnerGap = 14.0;

/// Gap between shelves (the board's main column).
const exploreSectionGap = 44.0;

double _line(double size) => size * StudioType.normalLineHeight(size);

double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(13) / 13;

/// Pieces stay 3:4. Scenes snap to 3:4, 1:1, or the landscape shelf ratio.
double exploreBrowseAspect(FeedItem item) {
  if (item.type == FeedItemType.piece && !item.isVideo) return 3 / 4;
  switch (item.mediaAspectRatio) {
    case '16:9':
      return 173 / 130;
    case '1:1':
      return 1;
    default:
      return 3 / 4;
  }
}

/// Walks [items] in feed order and drops each into the shorter column.
List<List<FeedItem>> exploreMasonryColumns(List<FeedItem> items) {
  final left = <FeedItem>[];
  final right = <FeedItem>[];
  var leftHeight = 0.0;
  var rightHeight = 0.0;
  for (final item in items) {
    final height = 1 / exploreBrowseAspect(item);
    if (leftHeight <= rightHeight) {
      left.add(item);
      leftHeight += height;
    } else {
      right.add(item);
      rightHeight += height;
    }
  }
  return [left, right];
}

class ExploreSeriesEntry {
  const ExploreSeriesEntry({
    required this.id,
    required this.name,
    required this.pieceCount,
    required this.coverUrl,
    required this.authorName,
    required this.authorUsername,
  });

  final String id;
  final String name;
  final int pieceCount;
  final String? coverUrl;
  final String? authorName;
  final String? authorUsername;
}

/// Series already attached to explore pieces. Nothing is fetched.
List<ExploreSeriesEntry> exploreSeriesEntries(List<FeedItem> items) {
  final seen = <String>{};
  final entries = <ExploreSeriesEntry>[];
  for (final item in items) {
    final series = item.piece?.series;
    if (series == null || series.id.isEmpty) continue;
    if (series.previewPieces.isEmpty && series.pieceIds.isEmpty) continue;
    if (!seen.add(series.id)) continue;
    entries.add(
      ExploreSeriesEntry(
        id: series.id,
        name: series.name,
        pieceCount: _seriesCount(series),
        coverUrl: _seriesCover(series),
        authorName: item.authorName,
        authorUsername: item.authorUsername,
      ),
    );
  }
  return entries;
}

int _seriesCount(PieceSeriesInfo series) {
  if (series.pieceIds.isNotEmpty) return series.pieceIds.length;
  return series.previewPieces.length;
}

String? _seriesCover(PieceSeriesInfo series) {
  for (final piece in series.previewPieces) {
    final url = piece.mediaUrl;
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

class ExploreShelfHeader extends StatelessWidget {
  const ExploreShelfHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: StudioType.sans(
                20,
                weight: StudioType.medium,
                height: 1.2,
                color: c.textPrimary,
              ),
            ),
          ),
          if (onSeeAll != null)
            Semantics(
              button: true,
              label: 'See all',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: StudioSize.tapTarget,
                    minHeight: StudioSize.tapTarget,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'See all',
                      style: StudioType.body14(
                        weight: StudioType.medium,
                        color: c.textSecondary,
                      ),
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

class ExplorePieceShelf extends StatelessWidget {
  const ExplorePieceShelf({
    super.key,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<FeedItem> items;
  final ValueChanged<FeedItem> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.length < exploreShelfMinCount) return const SizedBox.shrink();
    final scale = _textScale(context);
    final height = explorePieceShelfImageHeight +
        StudioSpace.s8 +
        (_line(14) + 2 + _line(13) + 2 + _line(13)) * scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExploreShelfHeader(title: 'Available now', onSeeAll: onSeeAll),
        const SizedBox(height: exploreShelfInnerGap),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: StudioSpace.s12),
            itemBuilder: (context, index) {
              return _PieceShelfCard(item: items[index], onOpen: onOpen);
            },
          ),
        ),
      ],
    );
  }
}

class _PieceShelfCard extends StatelessWidget {
  const _PieceShelfCard({required this.item, required this.onOpen});

  final FeedItem item;
  final ValueChanged<FeedItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final artist = item.authorName ?? item.authorUsername;
    final price = item.priceDisplay;
    return GestureDetector(
      onTap: () => onOpen(item),
      child: SizedBox(
        width: explorePieceShelfWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(StudioRadius.card),
              child: SizedBox(
                width: explorePieceShelfWidth,
                height: explorePieceShelfImageHeight,
                child: ExploreFeedImage(url: item.mediaUrl),
              ),
            ),
            const SizedBox(height: StudioSpace.s8),
            Text(
              item.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
            ),
            if (artist != null && artist.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.label13(color: c.textSecondary),
              ),
            ],
            if (price != null) ...[
              const SizedBox(height: 2),
              Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExploreSceneShelf extends StatelessWidget {
  const ExploreSceneShelf({
    super.key,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<FeedItem> items;
  final ValueChanged<FeedItem> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.length < exploreShelfMinCount) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExploreShelfHeader(title: 'Behind the work', onSeeAll: onSeeAll),
        const SizedBox(height: exploreShelfInnerGap),
        SizedBox(
          height: exploreSceneShelfHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: StudioSpace.s12),
            itemBuilder: (context, index) {
              return _SceneShelfCard(item: items[index], onOpen: onOpen);
            },
          ),
        ),
      ],
    );
  }
}

class _SceneShelfCard extends StatelessWidget {
  const _SceneShelfCard({required this.item, required this.onOpen});

  final FeedItem item;
  final ValueChanged<FeedItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final name = item.authorName ?? item.authorUsername ?? '';
    return GestureDetector(
      onTap: () => onOpen(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StudioRadius.card),
        child: SizedBox(
          width: exploreSceneShelfWidth,
          height: exploreSceneShelfHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExploreFeedImage(url: item.thumbnailUrl ?? item.mediaUrl),
              if (item.isVideo)
                const Positioned(
                  top: 10,
                  left: 10,
                  child: _VideoMark(),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: StudioColors.imageCaptionBar,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        StudioAvatar(
                          url: item.authorAvatarUrl,
                          size: 22,
                          ringWidth: 1.5,
                          ringColor: StudioColors.galleryWhite,
                          ringInside: true,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.caption12(
                              color: StudioColors.galleryWhite,
                            ).copyWith(fontWeight: StudioType.medium),
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
    );
  }
}

class ExploreSeriesShelf extends StatelessWidget {
  const ExploreSeriesShelf({
    super.key,
    required this.entries,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<ExploreSeriesEntry> entries;
  final ValueChanged<ExploreSeriesEntry> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (entries.length < exploreShelfMinCount) return const SizedBox.shrink();
    final scale = _textScale(context);
    final height = exploreSeriesShelfImageHeight +
        StudioSpace.s8 +
        (_line(14) + 2 + _line(13)) * scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExploreShelfHeader(title: 'New series', onSeeAll: onSeeAll),
        const SizedBox(height: exploreShelfInnerGap),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: StudioSpace.s12),
            itemBuilder: (context, index) {
              return _SeriesShelfCard(entry: entries[index], onOpen: onOpen);
            },
          ),
        ),
      ],
    );
  }
}

class _SeriesShelfCard extends StatelessWidget {
  const _SeriesShelfCard({required this.entry, required this.onOpen});

  final ExploreSeriesEntry entry;
  final ValueChanged<ExploreSeriesEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final artist = entry.authorName ?? entry.authorUsername ?? '';
    return GestureDetector(
      onTap: () => onOpen(entry),
      child: SizedBox(
        width: exploreSeriesShelfWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(StudioRadius.card),
              child: SizedBox(
                width: exploreSeriesShelfWidth,
                height: exploreSeriesShelfImageHeight,
                child: ExploreFeedImage(url: entry.coverUrl),
              ),
            ),
            const SizedBox(height: StudioSpace.s8),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                style: StudioType.label13(color: c.textSecondary),
                children: [
                  if (artist.isNotEmpty) TextSpan(text: '$artist · '),
                  TextSpan(
                    text: '${entry.pieceCount} pieces',
                    style: StudioType.mono(
                      12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreArtistTile extends StatelessWidget {
  const ExploreArtistTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.subtitle,
    this.onTap,
    this.followLabel,
    this.onFollow,
    this.followBusy = false,
  });

  final String name;
  final String? photoUrl;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Null hides the button (no follow action for this tile).
  final String? followLabel;
  final VoidCallback? onFollow;
  final bool followBusy;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SizedBox(
      width: exploreArtistTileWidth,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                StudioAvatar(url: photoUrl, size: exploreArtistAvatar),
                const SizedBox(height: StudioSpace.s8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: StudioType.label13(weight: StudioType.medium, color: c.textPrimary),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: StudioType.caption12(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (onFollow != null && followLabel != null) ...[
            const SizedBox(height: StudioSpace.s8),
            _ArtistFollowButton(
              label: followLabel!,
              busy: followBusy,
              filled: followLabel == FollowState.none.actionLabel,
              onTap: onFollow,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small Follow (`HandoffSizes` 34, radius 8) inside a 44 hit target.
class _ArtistFollowButton extends StatelessWidget {
  const _ArtistFollowButton({
    required this.label,
    required this.filled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final fg = filled ? c.buttonText : c.textPrimary;
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Center(
          child: Container(
            height: StudioSize.buttonSmall,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? c.buttonFill : c.card,
              borderRadius: BorderRadius.circular(StudioRadius.small),
              border: Border.all(color: filled ? c.buttonFill : c.lineStrong),
            ),
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    style: StudioType.label13(weight: StudioType.medium, color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}

class ExploreBrowseGrid extends StatelessWidget {
  const ExploreBrowseGrid({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<FeedItem> items;
  final ValueChanged<FeedItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final columns = exploreMasonryColumns(items);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _BrowseColumn(items: columns[0], onOpen: onOpen)),
          const SizedBox(key: Key('explore-gutter'), width: StudioSpace.s12),
          Expanded(child: _BrowseColumn(items: columns[1], onOpen: onOpen)),
        ],
      ),
    );
  }
}

class _BrowseColumn extends StatelessWidget {
  const _BrowseColumn({required this.items, required this.onOpen});

  final List<FeedItem> items;
  final ValueChanged<FeedItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: StudioSpace.feedGap),
          _BrowseCard(item: items[i], onOpen: onOpen),
        ],
      ],
    );
  }
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({required this.item, required this.onOpen});

  final FeedItem item;
  final ValueChanged<FeedItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final scene = item.type == FeedItemType.post || item.isVideo;
    final artist = item.authorName ?? item.authorUsername ?? '';
    return GestureDetector(
      onTap: () => onOpen(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StudioRadius.card),
            child: AspectRatio(
              aspectRatio: exploreBrowseAspect(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExploreFeedImage(
                    url: item.isVideo ? (item.thumbnailUrl ?? item.mediaUrl) : item.mediaUrl,
                  ),
                  if (item.isVideo)
                    const Positioned(top: 10, left: 10, child: _VideoMark()),
                ],
              ),
            ),
          ),
          const SizedBox(height: StudioSpace.s8),
          if (scene)
            Row(
              children: [
                StudioAvatar(url: item.authorAvatarUrl, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.label13(color: c.textSecondary),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              item.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
            ),
            if (artist.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.label13(color: c.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _VideoMark extends StatelessWidget {
  const _VideoMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: StudioIcon(
          StudioIcons.video,
          size: 12,
          color: StudioColors.galleryWhite,
          semanticLabel: 'Video',
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../theme/home_feed_tokens.dart';
import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../models/profile_series_data.dart';
import '../profile_constants.dart';

class ProfileSeriesGrid extends StatelessWidget {
  const ProfileSeriesGrid({
    super.key,
    required this.items,
    this.loading = false,
    this.onSeriesTap,
  });

  final List<ProfileSeriesData> items;
  final bool loading;

  /// Opens the series (restored from before commit 76f4ef9).
  final void Function(ProfileSeriesData series)? onSeriesTap;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
        child: Center(
          child: Text(
            'Series with more than one piece will appear here.',
            textAlign: TextAlign.center,
            style: kProfileGeist(
              fontSize: 13,
              color: kProfileTextMuted,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    final left = <ProfileSeriesData>[];
    final right = <ProfileSeriesData>[];
    for (var i = 0; i < items.length; i++) {
      if (i.isEven) {
        left.add(items[i]);
      } else {
        right.add(items[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _SeriesColumn(series: left, onSeriesTap: onSeriesTap)),
        const SizedBox(width: kProfileGutter),
        Expanded(child: _SeriesColumn(series: right, onSeriesTap: onSeriesTap)),
      ],
    );
  }
}

class _SeriesColumn extends StatelessWidget {
  const _SeriesColumn({required this.series, this.onSeriesTap});

  final List<ProfileSeriesData> series;
  final void Function(ProfileSeriesData series)? onSeriesTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < series.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _SeriesGridCard(data: series[i], onTap: onSeriesTap),
        ],
      ],
    );
  }
}

class _SeriesGridCard extends StatelessWidget {
  const _SeriesGridCard({required this.data, this.onTap});

  final ProfileSeriesData data;
  final void Function(ProfileSeriesData series)? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StackedSeriesCovers(data: data, maxWidth: constraints.maxWidth),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${data.name} · ${data.pieceCount}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: kProfileGeist(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
        if (onTap == null || data.id == null) return card;
        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap!(data),
            child: card,
          ),
        );
      },
    );
  }
}

class _StackedSeriesCovers extends StatelessWidget {
  const _StackedSeriesCovers({required this.data, required this.maxWidth});

  final ProfileSeriesData data;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final urls = data.stackUrls;
    final seeds = data.stackSeeds;
    final n = urls.isNotEmpty ? urls.length : seeds.length;
    final w = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 180.0;
    final side = w * kSeriesCardSideFraction;
    final stackHeight = side + (n >= 2 ? 8.0 : 4.0);

    if (n == 0) {
      return SizedBox(
        width: w,
        height: side,
        child: const ColoredBox(color: Color(0xFFE8E6E1)),
      );
    }

    final radius = BorderRadius.circular(HomeFeedTokens.cardRadius);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final imgPx = (side * dpr).round().clamp(120, 900);

    final cards = <Widget>[];
    if (n == 1) {
      cards.add(
        Positioned(
          left: 0,
          top: 0,
          width: side,
          height: side,
          child: _SeriesPaletteCard(
            imageUrl: urls.isNotEmpty ? urls[0] : null,
            borderRadius: radius,
            imagePx: imgPx,
            dropShadow: false,
          ),
        ),
      );
    } else {
      final step = (w - side) / (n - 1);
      for (var i = n - 1; i >= 0; i--) {
        cards.add(
          Positioned(
            left: i * step,
            top: 0,
            width: side,
            height: side,
            child: _SeriesPaletteCard(
              imageUrl: i < urls.length ? urls[i] : null,
              borderRadius: radius,
              imagePx: imgPx,
              dropShadow: i != 0,
            ),
          ),
        );
      }
    }

    return SizedBox(
      width: w,
      height: stackHeight,
      child: Stack(clipBehavior: Clip.hardEdge, children: cards),
    );
  }
}

class _SeriesPaletteCard extends StatelessWidget {
  const _SeriesPaletteCard({
    this.imageUrl,
    required this.borderRadius,
    required this.imagePx,
    this.dropShadow = false,
  });

  final String? imageUrl;
  final BorderRadius borderRadius;
  final int imagePx;
  final bool dropShadow;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: borderRadius,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: imagePx,
              errorWidget: (context, url, error) =>
                  const _SeriesCoverPlaceholder(),
            )
          : const _SeriesCoverPlaceholder(),
    );

    if (!dropShadow) return image;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(5, 2),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: image,
    );
  }
}

/// Horizontal series row on a seller's Pieces tab. Hidden by the caller when
/// this profile has no series loaded yet.
class ProfileSeriesShelf extends StatelessWidget {
  const ProfileSeriesShelf({
    super.key,
    required this.items,
    this.onSeeAll,
  });

  final List<ProfileSeriesData> items;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final textHeight = MediaQuery.textScalerOf(context).scale(14) * StudioType.normalLineHeight(14);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Series',
                  style: StudioType.header17(color: c.textPrimary),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  key: const Key('profile-series-see-all'),
                  onTap: onSeeAll,
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'See all',
                        style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160 + 8 + textHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _ShelfCard(data: items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.data});

  final ProfileSeriesData data;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = data.previewUrls.isEmpty ? null : data.previewUrls.first;
    final count = data.pieceCount == 1 ? '1 piece' : '${data.pieceCount} pieces';
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StudioRadius.card),
            child: SizedBox(
              width: 160,
              height: 160,
              child: url == null
                  ? ColoredBox(color: c.surface)
                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => ColoredBox(color: c.surface)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Text(count, style: StudioType.mono(12, color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeriesCoverPlaceholder extends StatelessWidget {
  const _SeriesCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade500,
      ),
    );
  }
}

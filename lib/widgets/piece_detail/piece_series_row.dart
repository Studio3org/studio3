import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';

/// Series card on the piece page (`BuyPieceFull`, `NoteBuyPieceFull`): 1 px Line border,
/// radius 14, 12 14 14 padding; "Part of a series" 13 Graphite, then stacked covers
/// (148 × 112: a 112 square in front, two narrower covers behind it to the right), the
/// series name 16/500 on one line and "[N] pieces" with the count in Mono.
///
/// The board's card opens the series page, which is not designed yet and does not exist in
/// the app, so the card has no action and no chevron (section 0.3). Hidden without a
/// series or covers.
class PieceSeriesRow extends StatelessWidget {
  const PieceSeriesRow({
    super.key,
    required this.seriesName,
    this.thumbSeeds = const [],
    this.thumbUrls = const [],
    this.pieceCount,
  });

  final String seriesName;
  final List<int> thumbSeeds;
  final List<String> thumbUrls;

  /// Pieces in the series; falls back to the number of covers.
  final int? pieceCount;

  @override
  Widget build(BuildContext context) {
    final urls = thumbUrls.where((url) => url.isNotEmpty).toList();
    final covers = urls.isNotEmpty ? urls.length : thumbSeeds.length;
    if (seriesName.isEmpty || covers == 0) return const SizedBox.shrink();
    final c = context.studio;
    final count = pieceCount ?? covers;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Part of a series', style: StudioType.label13(color: c.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _CoverStack(urls: urls, covers: covers),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seriesName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$count', style: StudioType.mono(13)),
                          TextSpan(text: count == 1 ? ' piece' : ' pieces'),
                        ],
                      ),
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Up to three covers: 112 × 112 in front (left 0), 48 wide at 78 and 40 wide at 108
/// behind it, all 112 tall, radius 10, each casting a soft shadow to the right. Only as
/// many layers as the series has covers; the box stays 148 wide so the text lines up.
class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.urls, required this.covers});

  final List<String> urls;
  final int covers;

  @override
  Widget build(BuildContext context) {
    const layers = [
      (left: 108.0, width: 40.0, shadow: 0.0),
      (left: 78.0, width: 48.0, shadow: 0.14),
      (left: 0.0, width: 112.0, shadow: 0.18),
    ];
    final shown = covers.clamp(1, layers.length);
    return SizedBox(
      width: 148,
      height: 112,
      child: Stack(
        children: [
          for (var i = layers.length - shown; i < layers.length; i++)
            Positioned(
              left: layers[i].left,
              top: 0,
              width: layers[i].width,
              height: 112,
              child: _Cover(
                // Front cover is the first image, then the second and third behind it.
                url: urls.length > layers.length - 1 - i ? urls[layers.length - 1 - i] : null,
                shadowOpacity: layers[i].shadow,
              ),
            ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.shadowOpacity});

  final String? url;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.studio.surface);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: shadowOpacity == 0
            ? null
            : [
                BoxShadow(
                  color: StudioColors.ink.withValues(alpha: shadowOpacity),
                  offset: const Offset(4, 0),
                  blurRadius: 10,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

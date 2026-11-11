import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/piece_summary.dart';
import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../../../widgets/studio/studio_chip.dart';

/// The Collection tab (`ProfileCollector`): the pieces this person bought on Studio 3
/// (BACKEND_CHANGES B37). Two columns 16 apart, 20 between rows, 20 under the tabs; each a
/// plain 3:4 picture (radius 8), then 8 under it the title (14/500) and the artist (13 grey),
/// 2 apart. No prices, no chips, no iridescence. Tapping a piece opens it. Nothing at all
/// when they haven't bought anything (empty tabs show nothing).
///
/// On their own Collection a piece they hid (B32) is dimmed with an Unhide chip on its picture
/// ([onUnhide]); everyone else never gets hidden pieces.
class ProfileCollectionGrid extends StatelessWidget {
  const ProfileCollectionGrid({super.key, required this.pieces, required this.onPieceTap, this.onUnhide});

  final List<PieceSummary> pieces;
  final void Function(PieceSummary piece) onPieceTap;
  final void Function(PieceSummary piece)? onUnhide;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.crossAxisExtent - StudioSpace.s16) / 2;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: StudioSpace.s16,
              mainAxisSpacing: 20,
              mainAxisExtent: _tileExtent(context, tileWidth),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CollectionTile(
                piece: pieces[index],
                onTap: () => onPieceTap(pieces[index]),
                onUnhide: pieces[index].hidden && onUnhide != null ? () => onUnhide!(pieces[index]) : null,
              ),
              childCount: pieces.length,
            ),
          );
        },
      ),
    );
  }
}

double _tileExtent(BuildContext context, double width) {
  double line(double size) =>
      MediaQuery.textScalerOf(context).scale(size) * StudioType.normalLineHeight(size);
  return width * 223 / 167 + 8 + line(14) + 2 + line(13) + 2;
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.piece, required this.onTap, this.onUnhide});

  final PieceSummary piece;
  final VoidCallback onTap;

  /// A piece they hid: dimmed, with Unhide.
  final VoidCallback? onUnhide;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = piece.mediaUrl;
    final artist = (piece.authorName ?? '').trim().isNotEmpty
        ? piece.authorName!.trim()
        : (piece.authorUsername ?? '').trim();
    final unhide = onUnhide;
    final label = artist.isEmpty ? piece.title : '${piece.title}, by $artist';
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (url == null || url.isEmpty)
          ? ColoredBox(color: c.surface)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: c.surface),
              errorWidget: (_, _, _) => ColoredBox(color: c.surface),
            ),
    );
    final tile = Semantics(
      button: true,
      label: unhide == null ? label : '$label, hidden',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 167 / 223,
              child: unhide == null ? picture : Opacity(opacity: 0.4, child: picture),
            ),
            const SizedBox(height: 8),
            Text(
              piece.title,
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
        ),
      ),
    );
    if (unhide == null) return tile;
    // Unhide sits on the dimmed picture, 8 in from its left and bottom edges.
    return LayoutBuilder(
      builder: (context, constraints) {
        final pictureHeight = constraints.maxWidth * 223 / 167;
        return Stack(
          children: [
            tile,
            Positioned(
              left: 8,
              top: pictureHeight - 8 - 32,
              child: StudioChip(label: 'Unhide', selected: true, dense: true, onTap: unhide),
            ),
          ],
        );
      },
    );
  }
}

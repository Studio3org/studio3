import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/piece_summary.dart';
import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../../../widgets/studio/studio_chip.dart';
import '../models/profile_series_data.dart';
import '../profile_constants.dart';
import 'profile_series_grid.dart';

bool profilePieceIsCollected(PieceSummary piece) {
  final status = piece.status?.toLowerCase();
  final listing = piece.listingState?.toLowerCase();
  return status == 'sold' || status == 'collected' || listing == 'collected';
}

bool profilePieceIsForSale(PieceSummary piece) =>
    piece.isForSale && !profilePieceIsCollected(piece);

/// Pieces tab for a seller: series already loaded, an All count, the Available
/// chip when something is for sale, and a 3:4 grid.
class ProfileSellerPieces extends StatefulWidget {
  const ProfileSellerPieces({
    super.key,
    required this.pieces,
    this.series = const [],
    this.showOwnerActions = false,
    this.onPieceTap,
    this.onDeletePiece,
    this.onPublishPiece,
    this.onSeeAllSeries,
  });

  final List<PieceSummary> pieces;
  final List<ProfileSeriesData> series;
  final bool showOwnerActions;
  final void Function(PieceSummary piece)? onPieceTap;
  final void Function(PieceSummary piece)? onDeletePiece;
  final void Function(PieceSummary piece)? onPublishPiece;
  final VoidCallback? onSeeAllSeries;

  @override
  State<ProfileSellerPieces> createState() => _ProfileSellerPiecesState();
}

class _ProfileSellerPiecesState extends State<ProfileSellerPieces> {
  bool _availableOnly = false;

  @override
  Widget build(BuildContext context) {
    final hasForSale = widget.pieces.any(profilePieceIsForSale);
    final availableOnly = _availableOnly && hasForSale;
    final visible = availableOnly
        ? widget.pieces.where(profilePieceIsForSale).toList(growable: false)
        : widget.pieces;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.series.isNotEmpty)
          SliverToBoxAdapter(
            child: ProfileSeriesShelf(
              items: widget.series,
              onSeeAll: widget.onSeeAllSeries,
            ),
          ),
        SliverToBoxAdapter(
          child: _AllHeader(
            count: visible.length,
            showAvailable: hasForSale,
            availableOnly: availableOnly,
            top: widget.series.isNotEmpty ? 30 : 22,
            onToggle: () => setState(() => _availableOnly = !_availableOnly),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  availableOnly ? 'No pieces listed for sale yet' : 'No pieces yet',
                  textAlign: TextAlign.center,
                  style: StudioType.label13(color: context.studio.textSecondary),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.crossAxisExtent - StudioSpace.s16) / 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: StudioSpace.s16,
                    mainAxisSpacing: 22,
                    mainAxisExtent: _tileExtent(context, tileWidth),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SellerPieceTile(
                      piece: visible[index],
                      showOwnerActions: widget.showOwnerActions,
                      onTap: () => widget.onPieceTap?.call(visible[index]),
                      onDelete: widget.onDeletePiece == null
                          ? null
                          : () => widget.onDeletePiece!(visible[index]),
                      onPublish: widget.onPublishPiece == null
                          ? null
                          : () => widget.onPublishPiece!(visible[index]),
                    ),
                    childCount: visible.length,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

double _tileExtent(BuildContext context, double width) {
  double line(double size) =>
      MediaQuery.textScalerOf(context).scale(size) * StudioType.normalLineHeight(size);
  final chip = 2 + 10 + line(11);
  return width * 223 / 167 + 8 + line(14) + 8 + chip + 6;
}

class _AllHeader extends StatelessWidget {
  const _AllHeader({
    required this.count,
    required this.showAvailable,
    required this.availableOnly,
    required this.top,
    required this.onToggle,
  });

  final int count;
  final bool showAvailable;
  final bool availableOnly;
  final double top;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'All ', style: StudioType.header17(color: c.textPrimary)),
                TextSpan(
                  text: '$count',
                  style: StudioType.mono(13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (showAvailable)
            StudioChip(
              key: const Key('profile-available-filter'),
              label: 'Available',
              selected: availableOnly,
              onTap: onToggle,
              leading: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellerPieceTile extends StatelessWidget {
  const _SellerPieceTile({
    required this.piece,
    required this.showOwnerActions,
    this.onTap,
    this.onDelete,
    this.onPublish,
  });

  final PieceSummary piece;
  final bool showOwnerActions;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final collected = profilePieceIsCollected(piece);
    final forSale = profilePieceIsForSale(piece);
    final draft = piece.status == 'draft';
    return GestureDetector(
      onTap: onTap,
      onLongPress: showOwnerActions && (onDelete != null || (draft && onPublish != null))
          ? () => _showActions(context)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 167 / 223,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kProfileCardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (piece.mediaUrl != null && piece.mediaUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: piece.mediaUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                    )
                  else
                    ColoredBox(color: c.surface),
                  if (draft)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(StudioRadius.round),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('Draft', style: StudioType.caption12(color: c.textPrimary)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            piece.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
          ),
          if (collected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StudioStatusChip(StudioStatus.collected),
            )
          else if (forSale)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StudioStatusChip(StudioStatus.available),
            ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    final publish = draftAction;
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
                title: const Text('Publish', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  publish();
                },
              ),
            if (delete != null)
              ListTile(
                title: const Text('Delete', style: TextStyle(color: Color(0xFFE05252))),
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

  VoidCallback? get draftAction => piece.status == 'draft' ? onPublish : null;
}

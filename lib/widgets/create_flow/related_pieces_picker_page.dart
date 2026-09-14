import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../models/piece_summary.dart';
import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
import 'create_flow_widgets.dart';

/// Full-screen linked-pieces picker for scene Details (Figma 2761:11632).
class RelatedPiecesPickerPage extends StatefulWidget {
  const RelatedPiecesPickerPage({
    super.key,
    required this.pieces,
    required this.selectedIds,
  });

  final List<PieceSummary> pieces;
  final Set<String> selectedIds;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<PieceSummary> pieces,
    required Set<String> selectedIds,
  }) {
    return Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => RelatedPiecesPickerPage(
          pieces: pieces,
          selectedIds: selectedIds,
        ),
      ),
    );
  }

  @override
  State<RelatedPiecesPickerPage> createState() =>
      _RelatedPiecesPickerPageState();
}

class _RelatedPiecesPickerPageState extends State<RelatedPiecesPickerPage> {
  late final Set<String> _selected = Set<String>.from(widget.selectedIds);

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final count = _selected.length;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          ColoredBox(
            color: HomeFeedTokens.background,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: 53,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: SvgPicture.asset(
                            PostMediaAssets.createBannerBack,
                            width: 7,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              HomeFeedTokens.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Related Pieces',
                        style: kProfileGeist(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (count > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$count selected',
                            style: GoogleFonts.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: HomeFeedTokens.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.pieces.isEmpty
                ? Center(
                    child: Text(
                      'You don\'t have any pieces yet.',
                      textAlign: TextAlign.center,
                      style: kProfileGeist(
                        fontSize: 14,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: widget.pieces.length,
                    itemBuilder: (context, index) {
                      final piece = widget.pieces[index];
                      return _PieceTile(
                        imageUrl: _coverUrl(piece),
                        selected: _selected.contains(piece.id),
                        onTap: () => _toggle(piece.id),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 16),
            child: CreateFlowBottomButton(
              label: 'Save',
              height: 40,
              backgroundColor: HomeFeedTokens.neutral800,
              textColor: HomeFeedTokens.textInverse,
              onTap: () => Navigator.pop(context, _selected),
              child: Text(
                'Save',
                style: GoogleFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textInverse,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _coverUrl(PieceSummary piece) {
    if (piece.images.isNotEmpty && piece.images.first.mediaUrl.isNotEmpty) {
      return piece.images.first.mediaUrl;
    }
    final url = piece.mediaUrl;
    if (url != null && url.isNotEmpty) return url;
    return null;
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: Color(0xFFE2DED6)),
              )
            else
              const ColoredBox(color: Color(0xFFE2DED6)),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? HomeFeedTokens.textPrimary
                      : Colors.white.withValues(alpha: 0.35),
                  border: Border.all(
                    color: selected ? HomeFeedTokens.textPrimary : Colors.white,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 10,
                        color: HomeFeedTokens.textInverse,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

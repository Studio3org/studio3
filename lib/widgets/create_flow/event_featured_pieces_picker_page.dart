import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../models/piece_summary.dart';
import '../../services/auth_session.dart';
import '../../services/piece_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../profile_avatar.dart';
import 'create_flow_widgets.dart';
import 'event_lineup_models.dart';
import '../loading/app_skeletons.dart';

class EventPieceGroup {
  const EventPieceGroup({required this.person, required this.pieces});

  final EventLineupPerson person;
  final List<PieceSummary> pieces;
}

/// Figma Featured Pieces — grouped by co-hosts and featured artists.
class EventFeaturedPiecesPickerPage extends StatefulWidget {
  const EventFeaturedPiecesPickerPage({
    super.key,
    required this.people,
    required this.selectedIds,
    this.knownPieces = const [],
  });

  final List<EventLineupPerson> people;
  final Set<String> selectedIds;
  final List<PieceSummary> knownPieces;

  static Future<List<PieceSummary>?> open(
    BuildContext context, {
    required List<EventLineupPerson> people,
    required Set<String> selectedIds,
    List<PieceSummary> knownPieces = const [],
  }) {
    return Navigator.of(context).push<List<PieceSummary>>(
      MaterialPageRoute(
        builder: (_) => EventFeaturedPiecesPickerPage(
          people: people,
          selectedIds: selectedIds,
          knownPieces: knownPieces,
        ),
      ),
    );
  }

  @override
  State<EventFeaturedPiecesPickerPage> createState() =>
      _EventFeaturedPiecesPickerPageState();
}

class _EventFeaturedPiecesPickerPageState
    extends State<EventFeaturedPiecesPickerPage> {
  late final Set<String> _selected = Set<String>.from(widget.selectedIds);
  final _byId = <String, PieceSummary>{};
  List<EventPieceGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final piece in widget.knownPieces) {
      _byId[piece.id] = piece;
    }
    _load();
  }

  Future<void> _load() async {
    final people = [...widget.people];
    final me = AuthSession.instance.user;
    if (me != null &&
        me.username.isNotEmpty &&
        people.every((person) => person.username != me.username)) {
      people.insert(
        0,
        EventLineupPerson(
          username: me.username,
          name: me.name,
          avatarUrl: me.profilePhotoUrl,
        ),
      );
    }

    final groups = <EventPieceGroup>[];
    for (final person in people) {
      try {
        final pieces =
            await PieceService.instance.getUserPieces(person.username);
        if (pieces.isNotEmpty) {
          for (final piece in pieces) {
            _byId[piece.id] = piece;
          }
          groups.add(EventPieceGroup(person: person, pieces: pieces));
        }
      } catch (_) {
        // Skip artists whose pieces can't be loaded.
      }
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

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
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          // 44x44 minimum touch target around the (much
                          // smaller) icon — the tap area used to be exactly
                          // the icon's own 7x14 size, which was easy to
                          // miss and read as the back button not working.
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
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
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Featured Pieces',
                              style: GoogleFonts.geist(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                color: HomeFeedTokens.textPrimary,
                              ),
                            ),
                            Text(
                              'From your featured artists and co-hosts',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.geist(
                                fontSize: 11,
                                height: 1.2,
                                color: HomeFeedTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$count selected',
                            style: GoogleFonts.geist(
                              fontSize: 12,
                              color: HomeFeedTokens.textSecondary,
                            ),
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
            child: _loading && _groups.isEmpty
                ? const TileGridSkeleton(crossAxisCount: 3, itemCount: 9)
                : _groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Add co-hosts or featured artists to tag their pieces.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.geist(
                              fontSize: 13,
                              color: HomeFeedTokens.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: _groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          return _ArtistGroup(
                            group: group,
                            selectedIds: _selected,
                            onToggle: _toggle,
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
              onTap: () => Navigator.pop(
                context,
                _selected
                    .map((id) => _byId[id])
                    .whereType<PieceSummary>()
                    .toList(),
              ),
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
}

class _ArtistGroup extends StatelessWidget {
  const _ArtistGroup({
    required this.group,
    required this.selectedIds,
    required this.onToggle,
  });

  final EventPieceGroup group;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProfileAvatar(url: group.person.avatarUrl, size: 40),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.person.displayName,
                  style: GoogleFonts.geist(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.person.handle,
                  style: GoogleFonts.geist(
                    fontSize: 10,
                    height: 1.15,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            const columns = 3;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final height = width * 4 / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final piece in group.pieces)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _PieceThumb(
                      imageUrl: eventPieceCoverUrl(piece),
                      selected: selectedIds.contains(piece.id),
                      onTap: () => onToggle(piece.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PieceThumb extends StatelessWidget {
  const _PieceThumb({
    required this.selected,
    required this.onTap,
    required this.imageUrl,
  });

  final String imageUrl;
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
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: HomeFeedTokens.skeletonBase),
              )
            else
              const ColoredBox(color: HomeFeedTokens.skeletonBase),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/piece_summary.dart';
import '../../services/auth_session.dart';
import '../../services/piece_service.dart';
import '../../widgets/create_flow/event_lineup_models.dart';
import '../../widgets/post_picker_search_field.dart';
import '../../widgets/studio/studio.dart';

/// Tag pieces (`HostTagPieces`): Back, "Tag pieces" and Done; a search field (pieces or
/// artists); the Mono count selected; then the pieces grouped by artist — featured artists
/// first, then the host's own — three across at 3:4, radius 8. Tapping one selects it (a 2 px
/// Ink outline 2 outside it); "For sale" or "Collected" sits on the image. Done returns the
/// selection.
class HostTagPiecesPage extends StatefulWidget {
  const HostTagPiecesPage({
    super.key,
    required this.artists,
    required this.selectedIds,
    this.knownPieces = const [],
    this.debugGroups,
  });

  final List<EventLineupPerson> artists;
  final Set<String> selectedIds;
  final List<PieceSummary> knownPieces;

  /// For tests: the groups, instead of loading each person's pieces.
  @visibleForTesting
  final List<({EventLineupPerson person, bool host, List<PieceSummary> pieces})>? debugGroups;

  static Future<List<PieceSummary>?> open(
    BuildContext context, {
    required List<EventLineupPerson> artists,
    required Set<String> selectedIds,
    List<PieceSummary> knownPieces = const [],
  }) {
    return Navigator.of(context).push<List<PieceSummary>>(
      MaterialPageRoute(
        builder: (_) => HostTagPiecesPage(artists: artists, selectedIds: selectedIds, knownPieces: knownPieces),
      ),
    );
  }

  @override
  State<HostTagPiecesPage> createState() => _HostTagPiecesPageState();
}

typedef _Group = ({EventLineupPerson person, bool host, List<PieceSummary> pieces});

class _HostTagPiecesPageState extends State<HostTagPiecesPage> {
  late final Set<String> _selected = {...widget.selectedIds};
  final _byId = <String, PieceSummary>{};
  final _search = TextEditingController();
  List<_Group> _groups = const [];
  bool _loading = true;

  /// Nobody's pieces could be loaded.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    for (final p in widget.knownPieces) {
      _byId[p.id] = p;
    }
    final given = widget.debugGroups;
    if (given != null) {
      _setGroups(given);
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setGroups(List<_Group> groups) {
    for (final g in groups) {
      for (final p in g.pieces) {
        _byId[p.id] = p;
      }
    }
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  /// A piece from someone's own list doesn't always say whose it is; the event needs to know,
  /// because only the artist can sell it there.
  static PieceSummary _byPerson(PieceSummary p, EventLineupPerson person) =>
      (p.authorUsername ?? '').isNotEmpty
      ? p
      : PieceSummary.fromJson({...p.toJson(), 'authorUsername': person.username, 'authorName': person.name});

  Future<void> _load() async {
    if (_failed) {
      // Try again.
      setState(() {
        _failed = false;
        _loading = true;
      });
    }
    final me = AuthSession.instance.user;
    final people = <(EventLineupPerson, bool)>[
      for (final a in widget.artists)
        if (a.username != me?.username) (a, false),
      if (me != null && me.username.isNotEmpty)
        (EventLineupPerson(username: me.username, name: me.name, avatarUrl: me.profilePhotoUrl), true),
    ];
    final groups = <_Group>[];
    var failures = 0;
    for (final (person, host) in people) {
      try {
        final pieces = await PieceService.instance.getUserPieces(person.username);
        groups.add((person: person, host: host, pieces: [for (final p in pieces) _byPerson(p, person)]));
      } catch (_) {
        // Skip someone whose pieces can't be loaded; say so if that was everyone.
        failures++;
      }
    }
    if (!mounted) return;
    _setGroups(groups);
    if (people.isNotEmpty && failures == people.length) setState(() => _failed = true);
  }

  void _done() {
    Navigator.of(context).pop([for (final id in _selected) ?_byId[id]]);
  }

  bool _matches(_Group g, PieceSummary p, String q) =>
      q.isEmpty ||
      p.title.toLowerCase().contains(q) ||
      g.person.displayName.toLowerCase().contains(q) ||
      g.person.username.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final g in _groups)
        if (g.pieces.any((p) => _matches(g, p, q))) (group: g, pieces: g.pieces.where((p) => _matches(g, p, q)).toList()),
    ];
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Tag pieces',
        actions: [
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: _done,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text('Done', style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(StudioSpace.marginPage, 4, StudioSpace.marginPage, 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          PostPickerSearchField(
            controller: _search,
            hintText: 'Search pieces or artists',
            height: 44,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text('${_selected.length} selected', style: StudioType.mono(12, color: c.textSecondary)),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                ),
              ),
            )
          else if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: StudioEmptyState(
                title: "Couldn't load pieces",
                message: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          else if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                q.isEmpty ? 'No pieces to tag yet.' : 'No pieces match.',
                style: StudioType.body14(color: c.textSecondary),
              ),
            )
          else
            for (final s in shown) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 10),
                child: Row(
                  children: [
                    StudioAvatar(url: s.group.person.avatarUrl, size: 30, semanticLabel: s.group.person.displayName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.group.host ? 'Your pieces' : s.group.person.displayName,
                            style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                          ),
                          Text(
                            s.group.host ? s.group.person.handle : '${s.group.person.handle} · featured',
                            style: StudioType.caption12(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                // The selected outline sits 2 outside the tile.
                clipBehavior: Clip.none,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3 / 4,
                children: [
                  for (final p in s.pieces)
                    _Tile(
                      piece: p,
                      selected: _selected.contains(p.id),
                      onTap: () => setState(() => _selected.contains(p.id) ? _selected.remove(p.id) : _selected.add(p.id)),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// A piece in the grid: 3:4 at radius 8; selected has a 2 px Ink outline 2 outside it; "For
/// sale" / "Collected" 10 white bottom left.
class _Tile extends StatelessWidget {
  const _Tile({required this.piece, required this.selected, required this.onTap});

  final PieceSummary piece;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = eventPieceCoverUrl(piece);
    final label = piece.isCollectedListing
        ? 'Collected'
        : (piece.isAvailableListing || piece.isAuctionLive)
        ? (piece.isAuctionLive ? 'In auction' : 'For sale')
        : null;
    return Semantics(
      button: true,
      selected: selected,
      label: piece.title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(StudioRadius.small),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                        ),
                  if (label != null)
                    Positioned(left: 6, bottom: 5, child: StudioImageLabel(label, mono: false, size: 10)),
                ],
              ),
            ),
            if (selected)
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.textPrimary, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

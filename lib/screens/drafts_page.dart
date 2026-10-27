import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/drafts_service.dart';
import '../widgets/studio/studio.dart';
import 'edit_piece_page.dart';

enum _Filter { all, pieces, scenes }

/// Drafts (`Drafts`): opened from + → Drafts and from Could not publish → Go to drafts.
///
/// All / Pieces / Scenes; each row is the picture (3:4), the title (or Untitled piece), what is
/// left in plain words, and Mono "PIECE · Today, 2:14 PM". A piece that failed to go live
/// shows the red ! circle and "Didn't publish. Tap to try again.", and tapping it tries again;
/// any other draft opens its edit page (the posting flow can't reopen a piece whose photos are
/// already uploaded). Swipe left or press and hold to delete, after asking. Empty: the grey
/// mark and No drafts. Scenes aren't kept as drafts until the server does (B33).
class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  _Filter _filter = _Filter.all;
  List<PieceSummary>? _pieces;
  Set<String> _failed = const {};
  bool _loadFailed = false;
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([DraftsService.instance.pieces(), DraftsService.instance.failedIds()]);
      if (!mounted) return;
      setState(() {
        _pieces = results[0] as List<PieceSummary>;
        _failed = results[1] as Set<String>;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _open(PieceSummary piece) async {
    if (_failed.contains(piece.id)) return _retry(piece);
    final changed = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => EditPiecePage(piece: piece)),
    );
    if (changed != null && mounted) _load();
  }

  Future<void> _retry(PieceSummary piece) async {
    if (_retrying.contains(piece.id)) return;
    setState(() => _retrying.add(piece.id));
    try {
      await DraftsService.instance.publish(piece.id);
      if (!mounted) return;
      setState(() {
        _pieces = [...?_pieces]..removeWhere((p) => p.id == piece.id);
        _failed = {..._failed}..remove(piece.id);
      });
      showStudioToast(context, 'Posted', icon: null);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, "Couldn't publish. Try again.", icon: null);
    } finally {
      if (mounted) setState(() => _retrying.remove(piece.id));
    }
  }

  Future<bool> _confirmDelete() => showStudioConfirm(
    context,
    title: 'Delete this draft?',
    message: 'It will be gone for good.',
    confirmLabel: 'Delete',
  );

  Future<void> _delete(PieceSummary piece) async {
    try {
      await DraftsService.instance.delete(piece.id);
      if (!mounted) return;
      setState(() => _pieces = [...?_pieces]..removeWhere((p) => p.id == piece.id));
    } catch (_) {
      if (mounted) {
        showStudioToast(context, "Couldn't delete the draft.", icon: null);
        _load();
      }
    }
  }

  Future<void> _holdToDelete(PieceSummary piece) async {
    if (await _confirmDelete()) await _delete(piece);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Drafts'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                for (final f in _Filter.values) ...[
                  StudioChip(
                    label: switch (f) {
                      _Filter.all => 'All',
                      _Filter.pieces => 'Pieces',
                      _Filter.scenes => 'Scenes',
                    },
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: _body(c)),
        ],
      ),
    );
  }

  Widget _body(StudioColors c) {
    if (_loadFailed) {
      return Center(
        child: StudioEmptyState(
          title: "Couldn't load drafts",
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _loadFailed = false);
            _load();
          },
        ),
      );
    }
    final pieces = _pieces;
    if (pieces == null) {
      return Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary)));
    }
    final shown = _filter == _Filter.scenes ? const <PieceSummary>[] : pieces;
    if (shown.isEmpty) return const Center(child: StudioEmptyState(title: 'No drafts'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final piece = shown[i];
          return Dismissible(
            key: ValueKey(piece.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(),
            onDismissed: (_) => _delete(piece),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: c.alert,
              child: Text('Delete', style: StudioType.label13(weight: StudioType.medium, color: Colors.white)),
            ),
            child: DraftRow(
              piece: piece,
              failed: _failed.contains(piece.id),
              busy: _retrying.contains(piece.id),
              onTap: () => _open(piece),
              onLongPress: () => _holdToDelete(piece),
            ),
          );
        },
      ),
    );
  }
}

/// One `Drafts` row: picture 54 × 72 (radius 6), title 15/500, the state line 13, and Mono 11
/// "PIECE · Today, 2:14 PM" in Tertiary, gap 3; a Line under it; chevron 18.
class DraftRow extends StatelessWidget {
  const DraftRow({
    super.key,
    required this.piece,
    required this.failed,
    required this.onTap,
    this.onLongPress,
    this.busy = false,
    this.now,
  });

  final PieceSummary piece;
  final bool failed;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// For tests: "today" for the time line.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final title = piece.title.trim().isEmpty || piece.title.trim() == 'Untitled' ? 'Untitled piece' : piece.title;
    final image = piece.imageUrls.isNotEmpty ? piece.imageUrls.first : piece.mediaUrl;
    final when = draftTimeLabel(piece.createdAt, now: now);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: busy ? null : onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 54,
                  height: 72,
                  child: image == null || image.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                          placeholder: (_, _) => ColoredBox(color: c.surface),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    if (failed)
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: c.alert, width: 1.5),
                            ),
                            child: Text(
                              '!',
                              style: StudioType.sans(10, weight: FontWeight.w600, height: 1, color: c.alert),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Didn't publish. Tap to try again.",
                              style: StudioType.sans(13, color: c.alert),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(draftLeftLine(piece), style: StudioType.sans(13, color: c.textSecondary)),
                    const SizedBox(height: 3),
                    Text(
                      when == null ? 'PIECE' : 'PIECE · $when',
                      style: StudioType.mono(11, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                )
              else
                StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is left before a draft piece can post, in plain words (`Drafts`): "Ready to post",
/// "Price left", "Price and shipping details left", "3 details left before you can post".
String draftLeftLine(PieceSummary piece) {
  final left = <String>[
    if (piece.title.trim().isEmpty || piece.title.trim() == 'Untitled') 'title',
    if ((piece.medium ?? '').trim().isEmpty) 'medium',
    if ((piece.dimensions ?? '').trim().isEmpty) 'size',
    if (piece.isForSale && piece.priceCents == null && piece.startingBidCents == null) 'price',
    if (piece.isForSale && piece.weightKg == null) 'shipping details',
  ];
  if (left.isEmpty) return 'Ready to post';
  if (left.length == 1) return '${_capital(left.first)} left';
  if (left.length == 2) return '${_capital(left.first)} and ${left.last} left';
  return '${left.length} details left before you can post';
}

String _capital(String s) => s[0].toUpperCase() + s.substring(1);

/// "Today, 2:14 PM", "Yesterday", "Oct 21" (and the year when it isn't this year).
String? draftTimeLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return null;
  final today = now ?? DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final days = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (days == 0) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return 'Today, $hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
  }
  if (days == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final label = '${months[at.month - 1]} ${at.day}';
  return at.year == today.year ? label : '$label, ${at.year}';
}

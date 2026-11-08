import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/drafts_service.dart';
import '../widgets/studio/studio.dart';
import 'edit_piece_page.dart';
import '../utils/app_clock.dart';

enum _Filter { all, pieces, scenes }

/// Drafts (`Drafts`): opened from + → Drafts and from Could not publish → Go to drafts.
///
/// All / Pieces / Scenes, newest edit first; each row is the picture (3:4 for a piece, 9:16 for
/// a Scene), the title (Untitled piece; a Scene's caption, or Untitled Scene), what is left in
/// plain words, and Mono "PIECE · Today, 2:14 PM" (the last edit, BACKEND_CHANGES B33). A
/// draft that failed to go live shows the red ! circle and "Didn't publish. Tap to try again.",
/// and tapping it tries again. Any other piece opens its edit page and a Scene asks to post
/// (the posting flow can't reopen work whose photos are already uploaded). Swipe left or press
/// and hold to delete, after asking. Empty: the grey mark and No drafts. A server without
/// the drafts list gives piece drafts only.
class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  _Filter _filter = _Filter.all;
  List<DraftEntry>? _drafts;
  bool _loadFailed = false;
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drafts = await DraftsService.instance.all();
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _open(DraftEntry draft) async {
    if (draft.failed) return _post(draft);
    final scene = draft.scene;
    if (scene != null) {
      final post = await showStudioConfirm(
        context,
        title: 'Post this Scene?',
        message: 'It goes on your profile and to your followers.',
        confirmLabel: 'Post',
      );
      if (post) await _post(draft);
      return;
    }
    final changed = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => EditPiecePage(piece: draft.piece!)),
    );
    if (changed != null && mounted) _load();
  }

  /// Takes the draft live: "Tap to try again", or posting a Scene.
  Future<void> _post(DraftEntry draft) async {
    if (_retrying.contains(draft.id)) return;
    setState(() => _retrying.add(draft.id));
    try {
      if (draft.isScene) {
        await DraftsService.instance.publishScene(draft.id);
      } else {
        await DraftsService.instance.publish(draft.id);
      }
      if (!mounted) return;
      setState(() => _drafts = [...?_drafts]..removeWhere((d) => d.id == draft.id));
      showStudioToast(context, 'Posted', icon: null);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, "Couldn't publish. Try again.", icon: null);
    } finally {
      if (mounted) setState(() => _retrying.remove(draft.id));
    }
  }

  Future<bool> _confirmDelete() => showStudioConfirm(
    context,
    title: 'Delete this draft?',
    message: 'It will be gone for good.',
    confirmLabel: 'Delete',
  );

  Future<void> _delete(DraftEntry draft) async {
    try {
      await DraftsService.instance.delete(draft);
      if (!mounted) return;
      setState(() => _drafts = [...?_drafts]..removeWhere((d) => d.id == draft.id));
    } catch (_) {
      if (mounted) {
        showStudioToast(context, "Couldn't delete the draft.", icon: null);
        _load();
      }
    }
  }

  Future<void> _holdToDelete(DraftEntry draft) async {
    if (await _confirmDelete()) await _delete(draft);
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
    final drafts = _drafts;
    if (drafts == null) {
      return Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary)));
    }
    final shown = switch (_filter) {
      _Filter.all => drafts,
      _Filter.pieces => [for (final d in drafts) if (!d.isScene) d],
      _Filter.scenes => [for (final d in drafts) if (d.isScene) d],
    };
    if (shown.isEmpty) return const Center(child: StudioEmptyState(title: 'No drafts'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final draft = shown[i];
          return Dismissible(
            key: ValueKey(draft.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(),
            onDismissed: (_) => _delete(draft),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: c.alert,
              child: Text('Delete', style: StudioType.label13(weight: StudioType.medium, color: Colors.white)),
            ),
            child: DraftRow(
              draft: draft,
              busy: _retrying.contains(draft.id),
              onTap: () => _open(draft),
              onLongPress: () => _holdToDelete(draft),
            ),
          );
        },
      ),
    );
  }
}

/// One `Drafts` row: the picture (a piece 54 × 72, a Scene 40 × 71; radius 6), title 15/500,
/// the state line 13, and Mono 11 "PIECE · Today, 2:14 PM" in Tertiary, gap 3; a Line under
/// it; chevron 18.
class DraftRow extends StatelessWidget {
  const DraftRow({
    super.key,
    required this.draft,
    required this.onTap,
    this.onLongPress,
    this.busy = false,
    this.now,
  });

  final DraftEntry draft;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// For tests: "today" for the time line.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final piece = draft.piece;
    final scene = draft.scene;
    final String title;
    final String? image;
    if (piece != null) {
      title = piece.title.trim().isEmpty || piece.title.trim() == 'Untitled' ? 'Untitled piece' : piece.title;
      image = piece.imageUrls.isNotEmpty ? piece.imageUrls.first : piece.mediaUrl;
    } else {
      final caption = scene!.caption?.trim() ?? '';
      title = caption.isEmpty ? 'Untitled Scene' : caption;
      image = scene.isVideo ? scene.thumbnailUrl : (scene.mediaUrls.isNotEmpty ? scene.mediaUrls.first : scene.mediaUrl);
    }
    final kind = draft.isScene ? 'SCENE' : 'PIECE';
    final when = draftTimeLabel(draft.editedAt, now: now);
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
                  width: draft.isScene ? 40 : 54,
                  height: draft.isScene ? 71 : 72,
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
                    if (draft.failed)
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
                      Text(
                        // A Scene draft is saved at Post, so it is always ready.
                        piece != null ? draftLeftLine(piece) : 'Ready to post',
                        style: StudioType.sans(13, color: c.textSecondary),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      when == null ? kind : '$kind · $when',
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
  final today = now ?? appNow();
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

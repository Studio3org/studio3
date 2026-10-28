import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/post_summary.dart';
import '../services/auth_session.dart';
import '../services/post_service.dart';
import '../widgets/studio/studio.dart';

/// Related Scenes (`PostRelatedScenes`): full screen from the Related Scenes row when posting
/// a piece. Back, "Related Scenes" and Done; a 14 Graphite line; the Mono count; the artist's
/// own Scenes newest first in a 3-up 9:16 grid (radius 10, a play mark on videos). Tapping
/// links or unlinks; a linked tile gets a 2 px Ink outline 2 out and a plain white "Linked".
/// Done returns the Scenes in the order linked; Back drops the changes.
class RelatedScenesPage extends StatefulWidget {
  const RelatedScenesPage({super.key, required this.selected, this.debugScenes});

  final List<PostSummary> selected;

  /// For tests: the artist's Scenes instead of loading them.
  @visibleForTesting
  final List<PostSummary>? debugScenes;

  static Future<List<PostSummary>?> open(
    BuildContext context, {
    required List<PostSummary> selected,
  }) {
    return Navigator.of(context).push<List<PostSummary>>(
      MaterialPageRoute(builder: (_) => RelatedScenesPage(selected: selected)),
    );
  }

  @override
  State<RelatedScenesPage> createState() => _RelatedScenesPageState();
}

class _RelatedScenesPageState extends State<RelatedScenesPage> {
  late final List<PostSummary> _linked = List.of(widget.selected);
  List<PostSummary> _scenes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final given = widget.debugScenes;
    if (given != null) {
      _scenes = given;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final me = AuthSession.instance.user?.username;
    try {
      final scenes = me == null ? <PostSummary>[] : await PostService.instance.getUserPosts(me);
      if (!mounted) return;
      setState(() {
        _scenes = scenes.where((s) => s.status == null || s.status == 'live').toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showStudioToast(context, 'Could not load your Scenes', icon: null);
    }
  }

  void _toggle(PostSummary scene) => setState(() {
    final i = _linked.indexWhere((s) => s.id == scene.id);
    i >= 0 ? _linked.removeAt(i) : _linked.add(scene);
  });

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Related Scenes',
                      style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox.square(
                            dimension: StudioSize.tapTarget,
                            child: Center(
                              child: StudioIcon(StudioIcons.backBold, size: 22, color: c.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: StudioTapArea(child: Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, _linked),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text(
                              'Done',
                              style: StudioType.sans(
                                15,
                                weight: StudioType.medium,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    'Pick Scenes that show how this piece came together. They appear on the '
                    'piece under The story behind this piece.',
                    style: StudioType.body14(height: 1.45, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${_linked.length} linked',
                    style: StudioType.mono(11, color: c.textSecondary),
                  ),
                  const SizedBox(height: 14),
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
                  else if (_scenes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        "You haven't posted any Scenes yet. After you publish, Add a Scene "
                        'from the studio links a new one to this piece.',
                        style: StudioType.body14(height: 1.45, color: c.textSecondary),
                      ),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 9 / 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final scene in _scenes)
                          _SceneTile(
                            scene: scene,
                            linked: _linked.any((s) => s.id == scene.id),
                            onTap: () => _toggle(scene),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({required this.scene, required this.linked, required this.onTap});

  final PostSummary scene;
  final bool linked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final video = scene.mediaType == 'video';
    final url = video ? (scene.thumbnailUrl ?? '') : (scene.mediaUrl ?? '');
    return Semantics(
      button: true,
      checked: linked,
      label: 'Scene',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudioRadius.card + 4),
            border: Border.all(color: linked ? c.textPrimary : Colors.transparent, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(StudioRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isNotEmpty)
                  CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                else
                  ColoredBox(color: c.surface),
                if (video)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: CustomPaint(size: Size(12, 12), painter: _PlayMark()),
                  ),
                if (linked)
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: Text(
                      'Linked',
                      style: StudioType.sans(
                        11,
                        weight: StudioType.medium,
                        color: Colors.white,
                      ).copyWith(shadows: const [Shadow(color: Color(0x73000000), blurRadius: 2)]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The white play triangle on a video tile, with the board's soft shadow.
class _PlayMark extends CustomPainter {
  const _PlayMark();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 7 / 24, size.height * 4 / 24)
      ..lineTo(size.width * 7 / 24, size.height * 20 / 24)
      ..lineTo(size.width * 20 / 24, size.height / 2)
      ..close();
    canvas.drawShadow(path, Colors.black, 1.5, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PlayMark oldDelegate) => false;
}

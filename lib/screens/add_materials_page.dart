import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/post_material_options.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/studio/studio_icon.dart';
import 'pick_materials_page.dart';

/// Materials and tools picked on this device most recently, for the Recent chips.
class RecentMaterialsStore {
  RecentMaterialsStore._();
  static final instance = RecentMaterialsStore._();

  static const _key = 'recent_materials';
  static const _max = 6;

  Future<List<PostMaterialOption>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return [
        for (final id in prefs.getStringList(_key) ?? const <String>[])
          ?PostMaterialOptions.byId(id),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> remember(Iterable<PostMaterialOption> used) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = [
        ...used.map((m) => m.id),
        ...?prefs.getStringList(_key),
      ];
      await prefs.setStringList(_key, ids.toSet().take(_max).toList());
    } catch (_) {}
  }
}

/// "Materials and tools" (`PostMaterials`): heading and subline, a search field that opens
/// the search (`PostMaterialsSearch`), Recent chips that add in one tap, and what was
/// picked grouped as Materials and Tools (Mono count) with × to remove. Done returns them.
class AddMaterialsPage extends StatefulWidget {
  const AddMaterialsPage({super.key, required this.initialMaterials, this.recent});

  final List<PostMaterialOption> initialMaterials;

  /// Recent picks; read from the device when null. Tests pass their own.
  final List<PostMaterialOption>? recent;

  @override
  State<AddMaterialsPage> createState() => _AddMaterialsPageState();
}

class _AddMaterialsPageState extends State<AddMaterialsPage> {
  late final List<PostMaterialOption> _selected = List.of(widget.initialMaterials);
  List<PostMaterialOption> _recent = const [];

  @override
  void initState() {
    super.initState();
    final given = widget.recent;
    if (given != null) {
      _recent = given;
    } else {
      RecentMaterialsStore.instance.load().then((r) {
        if (mounted) setState(() => _recent = r);
      });
    }
  }

  void _add(PostMaterialOption m) {
    if (_selected.contains(m)) return;
    setState(() => _selected.add(m));
  }

  Future<void> _openSearch() async {
    final picked = await Navigator.push<PostMaterialOption>(
      context,
      MaterialPageRoute<PostMaterialOption>(
        builder: (_) => PickMaterialsPage(selected: List.of(_selected)),
      ),
    );
    if (picked != null && mounted) _add(picked);
  }

  void _done() {
    RecentMaterialsStore.instance.remember(_selected);
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final materials = _selected.where((m) => m.kind == MaterialKind.material).toList();
    final tools = _selected.where((m) => m.kind == MaterialKind.tool).toList();
    final recent = _recent.where((m) => !_selected.contains(m)).toList();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MaterialsTopBar(onBack: () => Navigator.pop(context), onDone: _done),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  const PostHeading(
                    title: 'Materials and tools',
                    subtitle: "Credit where it's due. Brushes included.",
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: 'Search paints, surfaces, brushes',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _openSearch,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(StudioRadius.button),
                        ),
                        child: Row(
                          children: [
                            StudioIcon(StudioIcons.search, size: 20, color: c.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search paints, surfaces, brushes…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.sans(15, color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Recent',
                      style: StudioType.label13(weight: StudioType.medium, color: c.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in recent) _RecentChip(material: m, onTap: () => _add(m)),
                      ],
                    ),
                  ],
                  if (materials.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Group(
                      title: 'Materials',
                      items: materials,
                      onRemove: (m) => setState(() => _selected.remove(m)),
                    ),
                  ],
                  if (tools.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Group(
                      title: 'Tools',
                      items: tools,
                      onRemove: (m) => setState(() => _selected.remove(m)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back 22 on the left, "Done" 15/500 text on the right (12 8 padding).
class MaterialsTopBar extends StatelessWidget {
  const MaterialsTopBar({super.key, required this.onBack, required this.onDone});

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          PostIconButton(icon: StudioIcons.backBold, label: 'Back', onTap: onBack),
          const Spacer(),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onDone,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: StudioSize.tapTarget,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      'Done',
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 34 pill, 1 px Line Strong, 12 sides: a plus, the type 13 and "· brand" in Tertiary, 6
/// apart.
class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.material, required this.onTap});

  final PostMaterialOption material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      label: 'Add ${material.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: c.lineStrong),
            borderRadius: BorderRadius.circular(StudioRadius.round),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioIcon(StudioIcons.addBold, size: 14, color: c.textPrimary),
              const SizedBox(width: 6),
              Text(material.type, style: StudioType.label13(color: c.textPrimary)),
              if (material.brand.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${material.brand}',
                  style: StudioType.label13(color: c.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 17/500 group title with a Mono count in a 1 px Line circle, then rows: type 16 over
/// brand 13 Graphite, a 20 × in Tertiary, 1 px Line under each.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items, required this.onRemove});

  final String title;
  final List<PostMaterialOption> items;
  final ValueChanged<PostMaterialOption> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: StudioType.sans(17, weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(StudioRadius.round),
              ),
              child: Text('${items.length}', style: StudioType.mono(10, color: c.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final m in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.type, style: StudioType.sans(16, color: c.textPrimary)),
                      if (m.brand.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(m.brand, style: StudioType.label13(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Remove ${m.name}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onRemove(m),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      dimension: 36,
                      child: Center(
                        child: StudioIcon(StudioIcons.close, size: 18, color: c.textTertiary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

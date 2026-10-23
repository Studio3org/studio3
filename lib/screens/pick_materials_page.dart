import 'package:flutter/material.dart';

import '../data/post_material_options.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_icon.dart';
import 'add_materials_page.dart' show MaterialsTopBar;

/// Materials search (`PostMaterialsSearch`): the focused field (Card, 1.5 Ink border,
/// radius 12), suggestions as you type with the matched text in 500 and a Mono
/// material / tool tag, a custom entry only when nothing matches, and the note under it.
/// Tapping a suggestion returns it.
class PickMaterialsPage extends StatefulWidget {
  const PickMaterialsPage({super.key, required this.selected});

  /// Already picked; shown as such in the suggestions.
  final List<PostMaterialOption> selected;

  @override
  State<PickMaterialsPage> createState() => _PickMaterialsPageState();
}

class _PickMaterialsPageState extends State<PickMaterialsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final query = _controller.text.trim();
    final results = PostMaterialOptions.search(query);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MaterialsTopBar(
              onBack: () => Navigator.pop(context),
              onDone: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(StudioRadius.button),
                  border: Border.all(color: c.textPrimary, width: 1.5),
                ),
                child: Row(
                  children: [
                    StudioIcon(StudioIcons.search, size: 20, color: c.textPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: StudioType.sans(16, color: c.textPrimary),
                        cursorColor: c.textPrimary,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Search paints, surfaces, brushes…',
                          hintStyle: StudioType.sans(16, color: c.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  for (final m in results)
                    _Suggestion(
                      material: m,
                      query: query,
                      picked: widget.selected.contains(m),
                      onTap: () => Navigator.pop(context, m),
                    ),
                  if (query.isNotEmpty && results.isEmpty)
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, PostMaterialOption.custom(query)),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              StudioIcon(StudioIcons.addBold, size: 20, color: c.textPrimary),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Add “$query” as your own',
                                  style: StudioType.sans(16, color: c.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      "Picking from the list keeps things easy to find later. Use your own only "
                      "when it isn't here.",
                      style: StudioType.caption12(height: 1.5, color: c.textSecondary),
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

/// Type 16 with the matched part in 500, brand 13 Graphite, a Mono 11 tag in a 1 px Line
/// pill; 1 px Line under.
class _Suggestion extends StatelessWidget {
  const _Suggestion({
    required this.material,
    required this.query,
    required this.picked,
    required this.onTap,
  });

  final PostMaterialOption material;
  final String query;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final type = material.type;
    final at = type.toLowerCase().indexOf(query.toLowerCase());
    final base = StudioType.sans(16, color: c.textPrimary);
    final bold = base.copyWith(fontWeight: StudioType.medium);
    final title = at < 0 || query.isEmpty
        ? TextSpan(text: type)
        : TextSpan(
            children: [
              TextSpan(text: type.substring(0, at)),
              TextSpan(text: type.substring(at, at + query.length), style: bold),
              TextSpan(text: type.substring(at + query.length)),
            ],
          );
    return Semantics(
      button: true,
      selected: picked,
      label: material.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(title, style: base),
                    const SizedBox(height: 2),
                    Text(material.brand, style: StudioType.label13(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(StudioRadius.round),
                ),
                child: Text(
                  material.kind == MaterialKind.tool ? 'tool' : 'material',
                  style: StudioType.mono(10, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/post_material_options.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_chip.dart';
import '../studio/studio_field.dart';
import '../studio/studio_sheet.dart';

/// "Add your own" (not on the boards; the user's call, 2026-11-11): type the name of a
/// material or tool that isn't in the list. Material / Tool chips, a Name field (60
/// characters), and Add. Returns the new entry, or null if dismissed.
class MaterialNameSheet extends StatefulWidget {
  const MaterialNameSheet({
    super.key,
    this.initialName = '',
    this.initialKind = MaterialKind.material,
  });

  final String initialName;
  final MaterialKind initialKind;

  static const maxLength = 60;

  static Future<PostMaterialOption?> show(
    BuildContext context, {
    String initialName = '',
    MaterialKind initialKind = MaterialKind.material,
  }) {
    return showStudioSheet<PostMaterialOption>(
      context: context,
      builder: (_) => MaterialNameSheet(initialName: initialName, initialKind: initialKind),
    );
  }

  @override
  State<MaterialNameSheet> createState() => _MaterialNameSheetState();
}

class _MaterialNameSheetState extends State<MaterialNameSheet> {
  late final _controller = TextEditingController(text: widget.initialName);
  late MaterialKind _kind = widget.initialKind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, PostMaterialOption.custom(name, kind: _kind));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final empty = _controller.text.trim().isEmpty;
    final tool = _kind == MaterialKind.tool;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 6,
      scrollable: true,
      children: [
        Text('Add your own', style: StudioType.title22(color: c.textPrimary)),
        Text(
          "For a material or tool that isn't in the list.",
          style: StudioType.body14(color: c.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StudioChip(
              key: const Key('material-kind-material'),
              label: 'Material',
              selected: !tool,
              onTap: () => setState(() => _kind = MaterialKind.material),
            ),
            const SizedBox(width: 8),
            StudioChip(
              key: const Key('material-kind-tool'),
              label: 'Tool',
              selected: tool,
              onTap: () => setState(() => _kind = MaterialKind.tool),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StudioUnderlineField(
          key: const Key('material-name-field'),
          label: 'Name',
          hint: tool ? 'e.g. Palette knife' : 'e.g. Hand-ground pigment',
          controller: _controller,
          autofocus: true,
          valueSize: 18,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLength: MaterialNameSheet.maxLength,
          inputFormatters: [LengthLimitingTextInputFormatter(MaterialNameSheet.maxLength)],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        StudioButton(
          label: tool ? 'Add tool' : 'Add material',
          onPressed: empty ? null : _submit,
        ),
      ],
    );
  }
}

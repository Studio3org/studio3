import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import 'studio/studio_button.dart';
import 'studio/studio_field.dart';
import 'studio/studio_sheet.dart';
import '../theme/studio_type.dart';

/// Name field for a new folder or a rename. Names may repeat. 40 characters.
/// Returns the trimmed name, or null if the sheet is dismissed.
class CollectionNameSheet extends StatefulWidget {
  const CollectionNameSheet({
    super.key,
    this.initialName = '',
    this.title = 'New folder',
    this.actionLabel = 'Create folder',
    this.pieceTitle,
  });

  final String initialName;
  final String title;
  final String actionLabel;

  /// When set, the sheet says this piece will go in the new folder.
  final String? pieceTitle;

  static Future<String?> show(
    BuildContext context, {
    String initialName = '',
    String title = 'New folder',
    String actionLabel = 'Create folder',
    String? pieceTitle,
  }) {
    return showStudioSheet<String>(
      context: context,
      builder: (context) => CollectionNameSheet(
        initialName: initialName,
        title: title,
        actionLabel: actionLabel,
        pieceTitle: pieceTitle,
      ),
    );
  }

  @override
  State<CollectionNameSheet> createState() => _CollectionNameSheetState();
}

class _CollectionNameSheetState extends State<CollectionNameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final piece = widget.pieceTitle?.trim();
    final name = _controller.text.trim();
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 6,
      scrollable: true,
      children: [
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        if (piece != null && piece.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$piece will go in it.',
              style: StudioType.body14(color: c.textSecondary),
            ),
          ),
        StudioUnderlineField(
          label: 'Folder name',
          controller: _controller,
          autofocus: true,
          valueSize: 18,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        StudioButton(
          label: widget.actionLabel,
          onPressed: name.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

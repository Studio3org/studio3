import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_field.dart';
import '../studio/studio_sheet.dart';

/// Prompt for a series name (new or renamed). No board: a board sheet with a 22/500 title,
/// an underline field and a 52 primary button, off until there is a name. Returns the
/// trimmed name, or null when dismissed.
class CreateSeriesDialog extends StatefulWidget {
  const CreateSeriesDialog({
    super.key,
    this.initialName = '',
    this.title = 'New series',
    this.action = 'Create',
  });

  final String initialName;
  final String title;
  final String action;

  static Future<String?> show(
    BuildContext context, {
    String initialName = '',
    String title = 'New series',
    String action = 'Create',
  }) {
    return showStudioSheet<String>(
      context: context,
      builder: (context) =>
          CreateSeriesDialog(initialName: initialName, title: title, action: action),
    );
  }

  @override
  State<CreateSeriesDialog> createState() => _CreateSeriesDialogState();
}

class _CreateSeriesDialogState extends State<CreateSeriesDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  )..addListener(_changed);

  void _changed() => setState(() {});

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
    return StudioSheet(
      horizontalPadding: 24,
      gap: 20,
      children: [
        Text(widget.title, style: StudioType.title22(color: c.textPrimary)),
        StudioUnderlineField(
          label: 'Name',
          controller: _controller,
          hint: 'Series name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        StudioButton(
          label: widget.action,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'studio/studio.dart';

/// A label + read-only underline field that opens a sheet of options, for the small enum
/// settings (visibility, message permission, banner rule). Same field as the address form's
/// State: [StudioUnderlineField] with a chevron; the sheet is the title 22 over
/// [StudioSelectRow]s.
class LabeledDropdown extends StatefulWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;

  /// (value, display label) pairs.
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  State<LabeledDropdown> createState() => _LabeledDropdownState();
}

class _LabeledDropdownState extends State<LabeledDropdown> {
  late final _text = TextEditingController(text: _selectedLabel);

  String get _selectedLabel {
    for (final option in widget.options) {
      if (option.$1 == widget.value) return option.$2;
    }
    return widget.value;
  }

  @override
  void didUpdateWidget(LabeledDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != _selectedLabel) _text.text = _selectedLabel;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _openPicker() async {
    FocusScope.of(context).unfocus();
    final result = await showStudioSheet<String>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 0,
        scrollable: true,
        children: [
          const SizedBox(height: 12),
          Text(widget.label, style: StudioType.title22(color: sheetContext.studio.textPrimary)),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.options.length; i++)
            StudioSelectRow(
              title: widget.options[i].$2,
              selected: widget.options[i].$1 == widget.value,
              titleSize: 17,
              titleLetterSpacing: 0,
              verticalPadding: 14,
              ruleInset: 12,
              divider: i < widget.options.length - 1,
              onTap: () => Navigator.pop(sheetContext, widget.options[i].$1),
            ),
        ],
      ),
    );
    if (result != null && mounted) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return StudioUnderlineField(
      label: widget.label,
      controller: _text,
      readOnly: true,
      onTap: _openPicker,
      trailing: StudioIcon(StudioIcons.chevronDown, size: 18, color: context.studio.textTertiary),
    );
  }
}

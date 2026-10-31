import 'package:flutter/material.dart';

import '../data/post_picker_options.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import 'choose_location_sheet.dart' show PickerSheetFrame;
import 'post_picker_search_field.dart';
import 'studio/studio_button.dart';
import 'studio/studio_select_row.dart';
import 'studio/studio_sheet.dart';
import 'studio/studio_toast.dart';

enum PostPickerSelectionMode { singleRadio, multiCheckbox }

/// Option picker for medium and style (`PostMedium`): search, "N selected" in Mono, list
/// rows with the left-line selection, Done. Multi-select keeps the order things were
/// picked in (the first medium is the one shown on the piece).
class PostCreateOptionSheet extends StatefulWidget {
  const PostCreateOptionSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedIds,
    required this.mode,
    required this.onSelectionChanged,
    this.subtitle,
    this.maxSelections,
    this.closeOnSelection = false,
  });

  final String title;
  final String? subtitle;
  final String searchHint;
  final List<PostPickerOption> options;
  final Set<String> selectedIds;
  final PostPickerSelectionMode mode;
  final ValueChanged<Set<String>> onSelectionChanged;
  final int? maxSelections;
  final bool closeOnSelection;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String searchHint,
    required List<PostPickerOption> options,
    required Set<String> selectedIds,
    required PostPickerSelectionMode mode,
    required ValueChanged<Set<String>> onSelectionChanged,
    String? subtitle,
    int? maxSelections,
    bool closeOnSelection = false,
  }) {
    return showStudioSheet<void>(
      context: context,
      builder: (context) => PostCreateOptionSheet(
        title: title,
        subtitle: subtitle,
        searchHint: searchHint,
        options: options,
        selectedIds: selectedIds,
        mode: mode,
        onSelectionChanged: onSelectionChanged,
        maxSelections: maxSelections,
        closeOnSelection: closeOnSelection,
      ),
    );
  }

  @override
  State<PostCreateOptionSheet> createState() => _PostCreateOptionSheetState();
}

class _PostCreateOptionSheetState extends State<PostCreateOptionSheet> {
  final _searchController = TextEditingController();
  late final Set<String> _selectedIds = {...widget.selectedIds};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _multi => widget.mode == PostPickerSelectionMode.multiCheckbox;

  List<PostPickerOption> get _filtered {
    if (_query.isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options.where((o) => o.name.toLowerCase().contains(q)).toList();
  }

  void _toggle(PostPickerOption option) {
    if (!_multi) {
      setState(() {
        _selectedIds
          ..clear()
          ..add(option.id);
      });
      widget.onSelectionChanged({..._selectedIds});
      if (widget.closeOnSelection) Navigator.pop(context);
      return;
    }
    if (_selectedIds.contains(option.id)) {
      setState(() => _selectedIds.remove(option.id));
    } else {
      final max = widget.maxSelections;
      if (max != null && _selectedIds.length >= max) {
        showStudioToast(context, 'You can pick up to $max', icon: null);
        return;
      }
      setState(() => _selectedIds.add(option.id));
    }
    widget.onSelectionChanged({..._selectedIds});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final options = _filtered;
    final max = widget.maxSelections;
    return PickerSheetFrame(
      title: widget.title,
      subtitle:
          widget.subtitle ??
          (_multi
              ? (max == null
                    ? 'Pick all that apply. The first one shows on the piece.'
                    : 'Pick up to $max.')
              : 'Pick one.'),
      search: PostPickerSearchField(
        controller: _searchController,
        hintText: widget.searchHint,
        onChanged: (value) => setState(() => _query = value),
      ),
      header: _multi
          ? Text(
              max == null
                  ? '${_selectedIds.length} selected'
                  : '${_selectedIds.length} of $max selected',
              style: StudioType.mono11(color: c.textSecondary),
            )
          : null,
      maxHeight: MediaQuery.sizeOf(context).height - 120,
      done: StudioButton(label: 'Done', onPressed: () => Navigator.pop(context)),
      list: [
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Nothing matches', style: StudioType.body14(color: c.textSecondary)),
          ),
        for (var i = 0; i < options.length; i++)
          StudioListRow(
            title: options[i].name,
            selected: _selectedIds.contains(options[i].id),
            divider: i < options.length - 1,
            onTap: () => _toggle(options[i]),
          ),
      ],
    );
  }
}

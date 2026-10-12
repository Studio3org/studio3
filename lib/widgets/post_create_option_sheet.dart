import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_picker_options.dart';
import '../theme/home_feed_tokens.dart';
import 'post_picker_search_field.dart';

enum PostPickerSelectionMode { singleRadio, multiCheckbox }

/// Draggable option picker for medium / style (Figma medium & style sheets).
class PostCreateOptionSheet extends StatefulWidget {
  const PostCreateOptionSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedIds,
    required this.mode,
    required this.onSelectionChanged,
    this.maxSelections,
    this.closeOnSelection = false,
  });

  final String title;
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
    int? maxSelections,
    bool closeOnSelection = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => PostCreateOptionSheet(
        title: title,
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
  static const _sheetBg = Color(0xFF231F1B);
  static const _textSecondary = Color(0xFF8C8880);
  static const _handleColor = Color(0xFF4A4843);

  static const _initialSize = 0.33;
  static const _maxSize = 0.88;

  final _searchController = TextEditingController();
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PostPickerOption> get _filtered {
    if (_query.isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options
        .where((option) => option.name.toLowerCase().contains(q))
        .toList();
  }

  void _toggleOption(PostPickerOption option) {
    setState(() {
      if (widget.mode == PostPickerSelectionMode.singleRadio) {
        _selectedIds = {option.id};
        widget.onSelectionChanged(_selectedIds);
        if (widget.closeOnSelection) {
          Navigator.pop(context);
        }
        return;
      }

      if (_selectedIds.contains(option.id)) {
        _selectedIds.remove(option.id);
      } else {
        final max = widget.maxSelections;
        if (max != null && _selectedIds.length >= max) {
          _showMaxSelectionMessage(max);
          return;
        }
        _selectedIds.add(option.id);
      }
      widget.onSelectionChanged(Set<String>.from(_selectedIds));
    });
  }

  void _showMaxSelectionMessage(int max) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          duration: const Duration(seconds: 2),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'You can select up to $max styles at a time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showCounter =
        widget.mode == PostPickerSelectionMode.multiCheckbox &&
        widget.maxSelections != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: _initialSize,
        minChildSize: _initialSize,
        maxChildSize: _maxSize,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 82,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _handleColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: HomeFeedTokens.textInverse,
                          ),
                        ),
                      ),
                      if (showCounter)
                        Text(
                          '${_selectedIds.length}/${widget.maxSelections}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                  child: PostPickerSearchField(
                    controller: _searchController,
                    hintText: widget.searchHint,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 3),
                    itemBuilder: (context, index) {
                      final option = _filtered[index];
                      final selected = _selectedIds.contains(option.id);
                      return _OptionListTile(
                        label: option.name,
                        selected: selected,
                        mode: widget.mode,
                        onTap: () => _toggleOption(option),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OptionListTile extends StatelessWidget {
  const _OptionListTile({
    required this.label,
    required this.selected,
    required this.mode,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PostPickerSelectionMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textInverse,
                  ),
                ),
              ),
              _SelectionIndicator(selected: selected, mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected, required this.mode});

  static const _borderColor = Color(0xFF8C8880);

  final bool selected;
  final PostPickerSelectionMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == PostPickerSelectionMode.singleRadio) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? HomeFeedTokens.textInverse : _borderColor,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: HomeFeedTokens.textInverse,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      );
    }

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? HomeFeedTokens.textInverse : _borderColor,
          width: 1.5,
        ),
        color: selected ? HomeFeedTokens.textInverse : Colors.transparent,
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check, size: 12, color: HomeFeedTokens.textPrimary)
          : null,
    );
  }
}

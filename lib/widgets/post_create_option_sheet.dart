import 'package:flutter/material.dart';

import '../data/post_picker_options.dart';
import '../screens/profile/profile_constants.dart';
import '../theme/home_feed_tokens.dart';
import 'create_flow/create_flow_widgets.dart';
import 'post_picker_search_field.dart';
import '../theme/app_fonts.dart';

enum PostPickerSelectionMode { singleRadio, multiCheckbox }

/// Draggable option picker for medium / style.
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
  static const _sheetBg = HomeFeedTokens.background;
  static const _textSecondary = Color(0xFF8C8880);
  static const _handleColor = Color(0xFFC8C5BC);
  static const _disabledFill = Color(0xFFC8C5BC);

  static const _initialSize = 0.55;
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

  bool get _canSubmit => _selectedIds.isNotEmpty;

  void _toggleOption(PostPickerOption option) {
    setState(() {
      if (widget.mode == PostPickerSelectionMode.singleRadio) {
        _selectedIds = {option.id};
        if (widget.closeOnSelection) {
          widget.onSelectionChanged(_selectedIds);
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
    });
  }

  void _onDone() {
    if (!_canSubmit) return;
    widget.onSelectionChanged(Set<String>.from(_selectedIds));
    Navigator.pop(context);
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
              style: kProfileGeist(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: _initialSize,
        minChildSize: 0.4,
        maxChildSize: _maxSize,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: kProfileGeist(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: kProfileGeist(
                                  fontSize: 13,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showCounter)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_selectedIds.length}/${widget.maxSelections}',
                            style: kProfileGeist(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: PostPickerSearchField(
                    controller: _searchController,
                    hintText: widget.searchHint,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: _filtered.length,
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
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, safeBottom + 16),
                  child: CreateFlowBottomButton(
                    label: 'Done',
                    height: 40,
                    backgroundColor: _canSubmit
                        ? HomeFeedTokens.neutral800
                        : _disabledFill,
                    textColor: _canSubmit
                        ? HomeFeedTokens.textInverse
                        : HomeFeedTokens.textPrimary,
                    onTap: _canSubmit ? _onDone : null,
                    child: Text(
                      'Done',
                      style: AppFonts.geist(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _canSubmit
                            ? HomeFeedTokens.textInverse
                            : HomeFeedTokens.textPrimary,
                      ),
                    ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: kProfileGeist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: selected
                      ? HomeFeedTokens.textPrimary
                      : const Color(0xFF8C8880),
                ),
              ),
            ),
            _SelectionIndicator(selected: selected, mode: mode),
          ],
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
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: selected
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: HomeFeedTokens.textPrimary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? HomeFeedTokens.textPrimary : _borderColor,
          width: 1.5,
        ),
        color: selected ? HomeFeedTokens.textPrimary : Colors.transparent,
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check, size: 14, color: HomeFeedTokens.textInverse)
          : null,
    );
  }
}

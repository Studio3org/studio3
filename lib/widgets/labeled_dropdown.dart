import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// A label + tappable field that opens a bottom-sheet picker, for the small
/// enum settings (visibility, message permission, banner rule).
class LabeledDropdown extends StatelessWidget {
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

  String get _selectedLabel {
    for (final option in options) {
      if (option.$1 == value) return option.$2;
    }
    return value;
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OptionPickerSheet(
        label: label,
        value: value,
        options: options,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: HomeFeedTokens.textPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: HomeFeedTokens.textPrimary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionPickerSheet extends StatelessWidget {
  const _OptionPickerSheet({
    required this.label,
    required this.value,
    required this.options,
  });

  final String label;
  final String value;
  final List<(String, String)> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final option in options)
                  InkWell(
                    onTap: () => Navigator.pop(context, option.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.$2,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: option.$1 == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: HomeFeedTokens.textPrimary,
                              ),
                            ),
                          ),
                          if (option.$1 == value)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: HomeFeedTokens.textPrimary,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

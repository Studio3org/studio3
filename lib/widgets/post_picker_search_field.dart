import 'package:flutter/material.dart';

import '../theme/home_feed_tokens.dart';
import '../theme/app_fonts.dart';

/// Search field used in create-post bottom sheets.
class PostPickerSearchField extends StatelessWidget {
  const PostPickerSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  static const _textSecondary = Color(0xFF8C8880);

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: _textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textPrimary,
              ),
              cursorColor: HomeFeedTokens.textPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: AppFonts.geist(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

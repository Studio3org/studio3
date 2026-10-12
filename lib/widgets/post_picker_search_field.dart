import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _textSecondary.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 16,
            color: _textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textInverse,
              ),
              cursorColor: HomeFeedTokens.textInverse,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  fontSize: 12,
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

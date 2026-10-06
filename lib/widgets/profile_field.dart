import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Label + borderless text field, meant to sit inside a card container that
/// supplies its own visual boundary (see the field card on `EditProfilePage`).
class ProfileField extends StatelessWidget {
  const ProfileField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? error;

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
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: HomeFeedTokens.textPrimary,
          ),
          decoration: InputDecoration(
            errorText: error,
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }
}

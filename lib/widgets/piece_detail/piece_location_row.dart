import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

/// Shows the piece/scene's tagged location — self-hides when none was set.
class PieceLocationRow extends StatelessWidget {
  const PieceLocationRow({super.key, this.location});

  final String? location;

  @override
  Widget build(BuildContext context) {
    final text = location?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 14, color: HomeFeedTokens.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

class PieceActionBar extends StatelessWidget {
  const PieceActionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: liked ? Icons.favorite : Icons.favorite_border,
            label: liked ? 'Liked' : 'Like',
            color: liked ? const Color(0xFFFF3040) : HomeFeedTokens.textPrimary,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comment',
            onTap: onComment,
          ),
          // Share hidden for now — see plan/task history to re-enable.
          // _ActionButton(
          //   icon: Icons.ios_share_outlined,
          //   label: 'Share',
          //   onTap: onShare,
          // ),
          _ActionButton(
            icon: saved ? Icons.bookmark : Icons.bookmark_border,
            label: 'Save',
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = HomeFeedTokens.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

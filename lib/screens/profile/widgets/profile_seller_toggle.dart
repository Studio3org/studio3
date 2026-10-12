import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/home_feed_tokens.dart';

/// Artist ↔ Seller mode switch — Figma 1070-709.
class ProfileSellerToggle extends StatelessWidget {
  const ProfileSellerToggle({
    super.key,
    required this.sellerEnabled,
    required this.onChanged,
    this.loading = false,
  });

  final bool sellerEnabled;
  final ValueChanged<bool> onChanged;
  final bool loading;

  static const _track = Color(0xFFE8E4DC);
  static const _thumb = Color(0xFF231F1B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _track,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: sellerEnabled
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: _thumb,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Segment(
                    label: 'Artist',
                    selected: !sellerEnabled,
                    onTap: loading || !sellerEnabled
                        ? null
                        : () => onChanged(false),
                  ),
                ),
                Expanded(
                  child: _Segment(
                    label: 'Seller',
                    selected: sellerEnabled,
                    onTap: loading || sellerEnabled
                        ? null
                        : () => onChanged(true),
                  ),
                ),
              ],
            ),
            if (loading)
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HomeFeedTokens.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected
                  ? HomeFeedTokens.textInverse
                  : HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

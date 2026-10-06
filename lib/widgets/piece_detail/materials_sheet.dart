import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

/// Read-only bottom sheet listing a piece's materials.
Future<void> showMaterialsSheet(BuildContext context, List<String> materials) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => _MaterialsSheet(materials: materials),
  );
}

class _MaterialsSheet extends StatelessWidget {
  const _MaterialsSheet({required this.materials});

  final List<String> materials;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E5DF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Materials used',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final material in materials)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  material,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

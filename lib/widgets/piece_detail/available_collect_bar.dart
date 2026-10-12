import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/collect_detail_tokens.dart';

class AvailableCollectBar extends StatelessWidget {
  const AvailableCollectBar({
    super.key,
    required this.priceDisplay,
    this.onCollect,
    this.statusLabel,
  });

  final String priceDisplay;
  final VoidCallback? onCollect;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: CollectDetailTokens.background,
          border: Border(
            top: BorderSide(color: CollectDetailTokens.divider),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            CollectDetailTokens.horizontalPadding,
            12,
            CollectDetailTokens.horizontalPadding,
            12 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                priceDisplay,
                style: GoogleFonts.inter(
                  fontSize: CollectDetailTokens.barPriceSize,
                  fontWeight: FontWeight.w400,
                  height: CollectDetailTokens.barPriceLineHeight /
                      CollectDetailTokens.barPriceSize,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: CollectDetailTokens.collectButtonHeight,
                child: Material(
                  color: onCollect == null
                      ? CollectDetailTokens.ctaFill.withValues(alpha: 0.5)
                      : CollectDetailTokens.ctaFill,
                  borderRadius: BorderRadius.circular(
                    CollectDetailTokens.collectButtonRadius,
                  ),
                  child: InkWell(
                    onTap: onCollect,
                    borderRadius: BorderRadius.circular(
                      CollectDetailTokens.collectButtonRadius,
                    ),
                    child: Center(
                      child: Text(
                        statusLabel ?? 'Collect',
                        style: GoogleFonts.inter(
                          fontSize: CollectDetailTokens.collectLabelSize,
                          fontWeight: FontWeight.w400,
                          height: CollectDetailTokens.storyLineHeight /
                              CollectDetailTokens.collectLabelSize,
                          color: CollectDetailTokens.textInverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double totalHeight(BuildContext context) =>
      CollectDetailTokens.collectBarContentHeight +
      MediaQuery.paddingOf(context).bottom;
}

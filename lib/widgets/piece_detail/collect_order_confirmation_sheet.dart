import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/order.dart';
import '../../theme/collect_detail_tokens.dart';

/// Order confirmation shown after a successful collect + confirm.
class CollectOrderConfirmationSheet extends StatelessWidget {
  const CollectOrderConfirmationSheet({super.key, required this.order});

  final Order order;

  static Future<void> show(BuildContext context, {required Order order}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectOrderConfirmationSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isPaid = order.status == 'paid' || order.status == 'shipped' ||
        order.status == 'completed';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: CollectDetailTokens.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPaid ? Icons.check_circle : Icons.hourglass_top,
                color: CollectDetailTokens.brand,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                isPaid ? 'Order confirmed' : 'Order placed',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CollectDetailTokens.textPrimary,
                ),
              ),
              if (order.devMode == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Test mode — no real payment was captured.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CollectDetailTokens.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SummaryLine(label: 'Piece', value: order.artworkDisplay),
              const SizedBox(height: 8),
              _SummaryLine(label: 'Shipping', value: order.shippingDisplay),
              const SizedBox(height: 8),
              _SummaryLine(label: 'Tax', value: order.taxDisplay),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.totalDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: CollectDetailTokens.collectButtonHeight,
                width: double.infinity,
                child: Material(
                  color: CollectDetailTokens.ctaFill,
                  borderRadius: BorderRadius.circular(
                    CollectDetailTokens.collectButtonRadius,
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(
                      CollectDetailTokens.collectButtonRadius,
                    ),
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
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
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: CollectDetailTokens.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: CollectDetailTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

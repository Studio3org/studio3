import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../studio/studio.dart';

/// `pending_payment` → `Pending payment`.
String orderStatusLabel(String status) {
  final words = status.replaceAll('_', ' ').trim();
  if (words.isEmpty) return '';
  return words[0].toUpperCase() + words.substring(1);
}

/// The status word's colour: Completed in the positive green, Cancelled grey, the rest
/// Graphite. Status is the one place colour is allowed (`HandoffRules`).
/// [neutral] for the rest (Graphite by default).
Color orderStatusColor(StudioColors c, String status, {Color? neutral}) => switch (status) {
  'completed' => c.positive,
  'cancelled' || 'refunded' => c.textTertiary,
  _ => neutral ?? c.textSecondary,
};

/// An order in My orders / My sales (no board; the checkout rows): "Order" 15/500 with the
/// short id in Mono, "1 item · $3,500.00" 13 Graphite, the status 13/500 and a chevron; 14
/// above and below, a Line under.
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final shortId = order.id.substring(0, order.id.length > 8 ? 8 : order.id.length);
    final count = order.items.length;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Order '),
                          TextSpan(
                            text: '#$shortId',
                            style: StudioType.mono(14, color: c.textPrimary),
                          ),
                        ],
                      ),
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count item${count == 1 ? '' : 's'} · ${order.totalDisplay}',
                      style: StudioType.label13(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                orderStatusLabel(order.status),
                style: StudioType.label13(
                  weight: StudioType.medium,
                  color: orderStatusColor(c, order.status),
                ),
              ),
              const SizedBox(width: 8),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

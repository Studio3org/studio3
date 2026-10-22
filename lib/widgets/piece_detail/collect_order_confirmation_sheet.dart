import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../models/order.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_iridescent.dart';
import '../studio/studio_sheet.dart';
import 'piece_share_sheet.dart';

/// Shown after a successful collect + confirm (`CollectConfirm`): the piece in a 4 px
/// iridescent frame, "[Title] is yours", the artist line, a provenance card with the fields
/// the order has, then "View your orders" and Share. The iridescence stops with reduced
/// motion (`StudioIridescent`).
class CollectOrderConfirmationSheet extends StatelessWidget {
  const CollectOrderConfirmationSheet({super.key, required this.order, this.item});

  final Order order;

  /// The piece that was collected (title, artist, image, share). Older callers may not
  /// pass it; the sheet then falls back to "Order confirmed".
  final FeedPreviewItem? item;

  static Future<void> show(BuildContext context, {required Order order, FeedPreviewItem? item}) {
    return showStudioSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => CollectOrderConfirmationSheet(order: order, item: item),
    );
  }

  bool get _isPaid =>
      order.status == 'paid' || order.status == 'shipped' || order.status == 'completed';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  static String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  void _viewOrders(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed('/orders');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final mq = MediaQuery.of(context);
    final safeBottom = mq.viewPadding.bottom;
    final piece = item;
    final title = piece == null
        ? (_isPaid ? 'Order confirmed' : 'Order placed')
        : (_isPaid ? '${piece.title} is yours' : 'Order placed for ${piece.title}');
    final collected = order.createdAt;

    return SizedBox(
      height: mq.size.height * StudioSize.sheetMaxHeightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close (22 px, 44 target) top right.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: StudioIcon(StudioIcons.close, size: 22, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              children: [
                if (piece != null) ...[
                  Center(
                    child: StudioIridescent(
                      padding: const EdgeInsets.all(4),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F111111), // rgba(17,17,17,0.12)
                          offset: Offset(0, 18),
                          blurRadius: 40,
                        ),
                      ],
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 204,
                          height: 272,
                          child: FeedPicsumImage(
                            url: piece.heroImageUrl?.isNotEmpty == true
                                ? piece.heroImageUrl!
                                : feedPreviewImageUrl(piece),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: StudioType.sans(
                    28,
                    weight: StudioType.medium,
                    height: 1.15,
                    letterSpacing: -0.5,
                    color: c.textPrimary,
                  ),
                ),
                if (piece != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'By ${piece.displayName}.',
                    textAlign: TextAlign.center,
                    style: StudioType.body15(color: c.textSecondary),
                  ),
                ],
                if (order.devMode == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Test mode — no real payment was captured.',
                    textAlign: TextAlign.center,
                    style: StudioType.caption12(color: c.textSecondary),
                  ),
                ],
                if (collected != null) ...[
                  const SizedBox(height: 28),
                  _ProvenanceCard(rows: [('Collected', _date(collected.toLocal()))]),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              8,
              28,
              safeBottom > 0 ? safeBottom : StudioSize.noInsetBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioButton(
                  label: 'View your orders',
                  height: StudioSize.buttonPrimaryTall,
                  onPressed: () => _viewOrders(context),
                ),
                if (piece != null) ...[
                  const SizedBox(height: 4),
                  StudioButton(
                    label: 'Share',
                    variant: StudioButtonVariant.text,
                    onPressed: () => PieceShareSheet.show(context, piece),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Provenance card: a 1.5 px iridescent border (radius 14) around a 90 % page-colored
/// panel (radius 13, 14 16 6 padding); "Provenance" 14/500 with a 22 px iridescent dot,
/// then Mono 12 rows (label Graphite, value right), 10 above and below, hairline between.
/// Only rows the order has (Record no., Edition and Exhibited are not in the app's data).
class _ProvenanceCard extends StatelessWidget {
  const _ProvenanceCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioIridescent(
      padding: const EdgeInsets.all(1.5),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
          color: c.background.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Provenance',
                      style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                    ),
                  ),
                  StudioIridescent(
                    borderRadius: BorderRadius.circular(StudioRadius.round),
                    child: const SizedBox.square(dimension: 22),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: i < rows.length - 1 ? Border(bottom: BorderSide(color: c.line)) : null,
                ),
                child: Row(
                  children: [
                    Text(rows[i].$1, style: StudioType.mono(12, color: c.textSecondary)),
                    const Spacer(),
                    Text(rows[i].$2, style: StudioType.mono(12, color: c.textPrimary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

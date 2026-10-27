import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/order_service.dart';
import '../studio/studio.dart';

/// The bottom of a sold piece's page (`PieceCollected`, `PieceCollectedOwner`,
/// `PieceCollectedArtist`). No price and no Collect, ever.
///
/// Everyone: an iridescent Collected button (not tappable, 52, radius 12, 15/500 Ink) with the
/// message button beside it, as Collect plus message on a piece for sale. While the piece is
/// on its way, the collector and the artist get [PieceDeliveryCard] in its place instead.
class PieceCollectedBar extends StatelessWidget {
  const PieceCollectedBar({super.key, this.onMessage, this.delivery, this.onLink});

  /// Chat with the artist; null hides the message button (the artist's own piece).
  final VoidCallback? onMessage;

  /// The collector's or artist's delivery card; null shows the Collected button.
  final PieceDelivery? delivery;

  /// The card's arrow and the grey link under it.
  final VoidCallback? onLink;

  /// Bar height for the page's scroll padding.
  static double totalHeight(BuildContext context, {required bool withCard}) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return 28 + (withCard ? 182 + 4 + 40 : StudioSize.buttonPrimary) + (safe > 0 ? safe : 30);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final delivery = this.delivery;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        // `linear-gradient(to bottom, transparent 0, <background> 22px)`.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.background.withValues(alpha: 0), c.background],
            stops: const [0, 0.12],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, safe > 0 ? safe : 30),
          child: delivery == null
              ? Row(
                  children: [
                    const Expanded(child: CollectedButton()),
                    if (onMessage != null) ...[
                      const SizedBox(width: 10),
                      StudioMessageButton(onPressed: onMessage, semanticLabel: 'Message the artist'),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PieceDeliveryCard(delivery: delivery, onTap: onLink),
                    const SizedBox(height: 4),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: delivery.forArtist ? onLink : onMessage,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Text(
                              delivery.linkLabel,
                              style: StudioType.sans(
                                14,
                                weight: StudioType.medium,
                                color: c.textSecondary,
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

/// The iridescent Collected button: a status, not an action.
class CollectedButton extends StatelessWidget {
  const CollectedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Collected',
      excludeSemantics: true,
      child: SizedBox(
        height: StudioSize.buttonPrimary,
        child: StudioIridescent(
          borderRadius: BorderRadius.circular(StudioRadius.button),
          child: Center(
            child: Text(
              'Collected',
              style: StudioType.sans(15, weight: StudioType.medium, color: StudioColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a sold piece is on its way, for the collector or the artist.
///
/// Built from the viewer's order on the piece ([fromOrder]). The board's arrival window and
/// On time / Delayed (collector) and pickup date and "In 3 days" (artist) need the server
/// (BACKEND_CHANGES B32); until then the title says where it is and there is no label.
class PieceDelivery {
  const PieceDelivery({
    required this.forArtist,
    required this.step,
    required this.title,
    required this.heading,
    required this.detail,
    required this.linkLabel,
    this.label,
    this.labelLate = false,
    this.orderId,
  });

  final bool forArtist;

  /// 0–3: collected, packed (artist: label ready), shipped (artist: pickup), delivered.
  final int step;
  final String title;

  /// On time / Delayed, or "In 3 days"; null leaves it out.
  final String? label;
  final bool labelLate;
  final String heading;
  final String detail;

  /// The grey link under the card: "Message Amara" or "See shipping steps".
  final String linkLabel;
  final String? orderId;

  static const _closed = {'pending_payment', 'failed', 'cancelled', 'refunded'};

  /// The card for [order], or null once there is nothing to follow: delivered for the
  /// artist; confirmed (completed) for the collector, who still confirms receipt from here.
  static PieceDelivery? fromOrder(
    Order order, {
    required bool forArtist,
    required String artistName,
  }) {
    if (_closed.contains(order.status) || order.status == 'completed') return null;
    final shipment = order.shipment;
    final delivered = order.status == 'awaiting_confirmation' || (shipment?.isDelivered ?? false);
    final moving = order.status == 'shipped' ||
        shipment?.status == 'picked_up' ||
        shipment?.status == 'in_transit';
    final labelled = shipment != null;
    final step = delivered ? 3 : (moving ? 2 : (labelled ? 1 : 0));
    final courier = (shipment?.courier ?? '').trim();
    final tracking = (shipment?.trackingNumber ?? '').trim();
    final carrier = courier.isEmpty ? 'The courier' : courier;
    final trackingLine = tracking.isEmpty ? '' : ' Tracking $tracking.';
    final firstName = artistName.trim().split(' ').first;
    final shippedOn = shipment?.shipmentDate;

    if (forArtist) {
      if (delivered) return null;
      final (title, heading, detail) = switch (step) {
        0 => (
          'Get it ready to ship',
          'Pack it for pickup',
          'Have it wrapped and ready. We will send the label and the pickup time.',
        ),
        1 => ('Label ready', 'Pack it for pickup', '$carrier will pick it up from you.$trackingLine'),
        _ => (
          shippedOn == null ? 'Picked up' : 'Picked up ${_monthDay(shippedOn)}',
          'On its way',
          '$carrier has it on the way to the collector.$trackingLine',
        ),
      };
      return PieceDelivery(
        forArtist: true,
        step: step,
        title: title,
        heading: heading,
        detail: detail,
        linkLabel: 'See shipping steps',
        orderId: order.id,
      );
    }

    final disputed = order.isDisputed;
    final (title, heading, detail) = switch (step) {
      0 => ('Getting it ready', 'Being packed', '$firstName is getting it ready to ship.'),
      1 => ('Packed', 'Ready for pickup', '$carrier will pick it up from $firstName soon.$trackingLine'),
      2 => (
        shippedOn == null ? 'Shipped' : 'Shipped ${_monthDay(shippedOn)}',
        'On its way',
        '$carrier picked it up from $firstName.$trackingLine',
      ),
      _ => ('Delivered', 'Delivered', 'Confirm you got it so $firstName gets paid.'),
    };
    return PieceDelivery(
      forArtist: false,
      step: step,
      title: title,
      heading: disputed ? 'Issue reported' : heading,
      detail: disputed ? 'We are looking into it and will be in touch.' : detail,
      linkLabel: 'Message $firstName',
      orderId: order.id,
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _monthDay(DateTime at) {
    final local = at.toLocal();
    return '${_months[local.month - 1]} ${local.day}';
  }
}

/// The viewer's order on [pieceId]: their purchase, or as the artist their sale. Read from
/// the first page of Orders or Sales until the piece carries it (BACKEND_CHANGES B32).
Future<Order?> findViewerOrder(String pieceId, {required bool asSeller, bool refresh = false}) async {
  try {
    final page = asSeller
        ? await OrderService.instance.getMySalesCached(forceRefresh: refresh)
        : await OrderService.instance.getMyOrdersCached(forceRefresh: refresh);
    final matches = page.items
        .where((order) => order.items.any((item) => item.pieceId == pieceId))
        .where((order) => !PieceDelivery._closed.contains(order.status))
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return matches.isEmpty ? null : matches.first;
  } catch (_) {
    return null;
  }
}

/// `PieceCollectedOwner` delivery card: white (Card in dark) inside a 1.5 iridescent edge,
/// radius 20, 16 padding. Title 19/500 with an optional label (On time green, Delayed red, or a
/// Mono date label), then the tracker 16 above and below, then the current step 16/500 with
/// one line of detail 13 and an 18 arrow.
class PieceDeliveryCard extends StatelessWidget {
  const PieceDeliveryCard({super.key, required this.delivery, this.onTap});

  final PieceDelivery delivery;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final label = delivery.label;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StudioIridescent(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? c.card : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(18.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    delivery.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.sans(19, weight: StudioType.medium, color: c.textPrimary)
                        .copyWith(letterSpacing: -0.3),
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: delivery.forArtist
                          ? c.surface
                          : (delivery.labelLate ? c.alertBg : c.positiveBg),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: delivery.forArtist
                          ? StudioType.mono(11, color: c.textPrimary)
                          : StudioType.sans(
                              12,
                              weight: StudioType.medium,
                              color: delivery.labelLate ? c.alert : c.positive,
                            ),
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: DeliveryTracker(step: delivery.step, forArtist: delivery.forArtist),
            ),
            Semantics(
              button: onTap != null,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.heading,
                            style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            delivery.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(13, height: 1.45, color: c.textBody),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPrimary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four 22 round steps joined by 3 bars (6 in from each step): finished steps are Ink with a
/// check, the current one Ink with its own glyph and its bar half filled, the rest Surface with
/// a Tertiary glyph.
class DeliveryTracker extends StatelessWidget {
  const DeliveryTracker({super.key, required this.step, required this.forArtist});

  final int step;
  final bool forArtist;

  static const _names = ['Collected', 'Packed', 'Shipped', 'Delivered'];
  static const _artistNames = ['Collected', 'Label ready', 'Pickup', 'Delivered'];
  static const _glyphs = [StudioIcons.check, StudioIcons.package, StudioIcons.truck, StudioIcons.location];

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final names = forArtist ? _artistNames : _names;
    final children = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final done = i < step;
      final current = i == step;
      final reached = done || current;
      children.add(
        Semantics(
          label: '${names[i]}${done ? ', done' : (current ? ', now' : '')}',
          excludeSemantics: true,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? c.buttonFill : c.surface,
            ),
            child: StudioIcon(
              done ? StudioIcons.check : _glyphs[i],
              size: 11,
              color: reached ? c.buttonText : c.textTertiary,
            ),
          ),
        ),
      );
      if (i < 3) {
        final fill = i < step ? 1.0 : (i == step ? 0.5 : 0.0);
        children.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: c.line),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill,
                        child: ColoredBox(color: c.buttonFill),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Row(children: children);
  }
}

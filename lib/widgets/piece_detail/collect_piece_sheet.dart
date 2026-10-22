import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/collect_checkout.dart';
import '../../models/feed_preview_item.dart';
import '../../services/api_exception.dart';
import '../../services/order_service.dart';
import '../../theme/collect_detail_tokens.dart' show formatMoney, formatMoneyAmount;
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_sheet.dart';
import 'collect_order_confirmation_sheet.dart';
import 'collect_payment_sheet.dart';
import 'collect_shipping_method_sheet.dart';
import 'collect_shipping_sheet.dart';

/// Checkout (`BuyCheckoutEmpty` → `BuyCheckoutReady`), kept as a sheet: piece summary,
/// Shipping and Payment rows, order summary with "–" until an address is set, "All sales
/// are final. See terms" above "Collect this piece".
class CollectPieceSheet extends StatefulWidget {
  const CollectPieceSheet({
    super.key,
    required this.item,
    @visibleForTesting this.initialShipping,
    @visibleForTesting this.initialPayment,
  });

  final FeedPreviewItem item;

  /// Tests only: start with shipping / payment already chosen (`BuyCheckoutReady`).
  final CollectShippingSelection? initialShipping;
  final CollectPaymentMethod? initialPayment;

  static Future<void> show(BuildContext context, {required FeedPreviewItem item}) {
    return showStudioSheet<void>(
      context: context,
      builder: (context) => CollectPieceSheet(item: item),
    );
  }

  @override
  State<CollectPieceSheet> createState() => _CollectPieceSheetState();
}

class _CollectPieceSheetState extends State<CollectPieceSheet> {
  late CollectShippingSelection? _shipping = widget.initialShipping;
  late CollectPaymentMethod? _payment = widget.initialPayment;
  bool _collecting = false;

  FeedPreviewItem get item => widget.item;

  String get _imageUrl {
    final url = item.heroImageUrl;
    if (url != null && url.isNotEmpty) return url;
    return feedPreviewImageUrl(item);
  }

  /// Order summary amounts always show cents, as the board ("$3,500.00").
  static String _cents(int cents) {
    final amount = formatMoneyAmount(cents);
    return '\$${amount.contains('.') ? amount : '$amount.00'}';
  }

  int get _artworkCents => item.priceCents ?? 0;
  int get _shippingCents => _shipping?.method.priceCents ?? 0;
  int get _taxCents => (_artworkCents * 0.0825).round();
  int get _totalCents => _artworkCents + _shippingCents + _taxCents;

  Future<void> _openShipping() async {
    final address = await CollectShippingSheet.show(context, initial: _shipping?.address);
    if (!mounted || address == null) return;

    final selection = await CollectShippingMethodSheet.show(
      context,
      pieceId: item.id,
      address: address,
      initialMethodId: _shipping?.method.id,
    );
    if (!mounted || selection == null) return;
    setState(() => _shipping = selection);
  }

  Future<void> _openPayment() async {
    final result = await CollectPaymentSheet.show(context, initial: _payment);
    if (!mounted || result == null) return;
    setState(() => _payment = result);
  }

  Future<void> _onCollect() async {
    final shipping = _shipping;
    if (shipping == null || _collecting) return;
    setState(() => _collecting = true);
    try {
      final order = await OrderService.instance.collect(
        item.id,
        addressId: shipping.address.id,
        shippingMethod: shipping.method.id,
      );

      // Real Stripe PaymentIntent flow is not wired yet. Debug/profile may
      // use the server's auto-pay confirm; release builds skip confirm unless
      // explicitly enabled via --dart-define=ALLOW_DEV_CHECKOUT=true.
      const allowDevCheckout = bool.fromEnvironment('ALLOW_DEV_CHECKOUT', defaultValue: false);
      final canConfirm = kDebugMode || allowDevCheckout;

      if (!canConfirm) {
        if (!mounted) return;
        setState(() => _collecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payments are not live yet. Checkout confirm is disabled in this build.'),
          ),
        );
        return;
      }

      final confirmed = await OrderService.instance.confirm(order.id);
      if (!mounted) return;
      Navigator.pop(context);
      await CollectOrderConfirmationSheet.show(context, order: confirmed);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _collecting = false);
      final message = e.statusCode == 501
          ? 'Card payments are not set up yet (Stripe pending).'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _collecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete checkout. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final mq = MediaQuery.of(context);
    final safeBottom = mq.viewPadding.bottom;
    final shipping = _shipping;
    final address = shipping?.address;
    final place = address == null
        ? ''
        : [address.city, address.state].where((part) => part.trim().isNotEmpty).join(', ');

    return SizedBox(
      // As tall as a sheet may be (`HandoffSizes`: ≤ 90 %), so the button stays pinned.
      height: mq.size.height * StudioSize.sheetMaxHeightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: StudioSheetGrabber()),
          _Header(onClose: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                _PieceSummary(
                  imageUrl: _imageUrl,
                  title: item.title,
                  artistName: item.displayName,
                  priceDisplay: item.priceCents == null ? null : formatMoney(item.priceCents!),
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    children: [
                      _NavRow(
                        label: 'Shipping',
                        value: shipping == null
                            ? null
                            : [
                                shipping.method.title,
                                place,
                              ].where((part) => part.trim().isNotEmpty).join(' · '),
                        placeholder: 'Add a delivery address',
                        onTap: _openShipping,
                      ),
                      _NavRow(
                        label: 'Payment',
                        value: _payment?.label,
                        placeholder: 'Add a payment method',
                        onTap: _openPayment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _OrderSummary(
                  artwork: _cents(_artworkCents),
                  shipping: shipping == null ? null : _cents(_shippingCents),
                  tax: shipping == null ? null : _cents(_taxCents),
                  total: shipping == null ? null : _cents(_totalCents),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              safeBottom > 0 ? safeBottom : StudioSize.noInsetBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SalesFinalLine(),
                const SizedBox(height: 8 + 4),
                StudioButton(
                  label: 'Collect this piece',
                  height: StudioSize.buttonPrimaryTall,
                  loading: _collecting,
                  // Enabled once shipping is set, as before: payment is not charged yet
                  // (Stripe pending), so it is not required (section 0.3).
                  onPressed: shipping == null ? null : _onCollect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Close (22 px, 44 target) on the left, "Checkout" 16/500 centred (`BuyCheckoutEmpty`).
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Close',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: StudioIcon(StudioIcons.close, size: 22, color: c.textPrimary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Checkout',
                textAlign: TextAlign.center,
                style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

/// 64 × 85 thumbnail (radius 8), 14 gap, then title 16/500, artist 13 Graphite and price
/// 14, 3 apart.
class _PieceSummary extends StatelessWidget {
  const _PieceSummary({
    required this.imageUrl,
    required this.title,
    required this.artistName,
    required this.priceDisplay,
  });

  final String imageUrl;
  final String title;
  final String artistName;
  final String? priceDisplay;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(StudioRadius.small),
          child: SizedBox(width: 64, height: 85, child: FeedPicsumImage(url: imageUrl)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(artistName, style: StudioType.label13(color: c.textSecondary)),
              if (priceDisplay != null) ...[
                const SizedBox(height: 3),
                Text(priceDisplay!, style: StudioType.body14(color: c.textPrimary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shipping / Payment row: label 13 Graphite over the value 15 (placeholder #A3A3A3 until
/// set), 16 px chevron, 18 above and below, 1 px Line under.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final set = value != null && value!.isNotEmpty;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: StudioType.label13(color: c.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      set ? value! : placeholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, color: set ? c.textPrimary : c.textPlaceholder),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Order summary" 15/500, then Artwork, Shipping and Tax (14, label Graphite, 6 above and
/// below), a 1 px Line and Total 15/500. Until an address is set, Shipping, Tax and Total
/// show "–" in Mono with the line about shipping and tax under them. No Insurance or Fees:
/// the app has neither today.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.artwork,
    required this.shipping,
    required this.tax,
    required this.total,
  });

  final String artwork;
  final String? shipping;
  final String? tax;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    Widget line(String label, String? value, {bool strong = false}) {
      final style = strong
          ? StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary)
          : StudioType.body14(color: c.textPrimary);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: strong ? style : StudioType.body14(color: c.textSecondary)),
            const Spacer(),
            Text(
              value ?? '–',
              style: value == null
                  ? StudioType.mono(
                      strong ? 15 : 14,
                      weight: style.fontWeight!,
                      color: c.textPrimary,
                    )
                  : style,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Order summary',
          style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        line('Artwork', artwork),
        line('Shipping', shipping),
        line('Tax', tax),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: line('Total', total, strong: true),
        ),
        if (shipping == null) ...[
          const SizedBox(height: 8),
          Text(
            'Shipping and tax are added once you enter an address.',
            style: StudioType.caption12(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "All sales are final. See terms" (12 / 1.5, Graphite, the link in Ink), opening the
/// existing Terms page.
class _SalesFinalLine extends StatefulWidget {
  const _SalesFinalLine();

  @override
  State<_SalesFinalLine> createState() => _SalesFinalLineState();
}

class _SalesFinalLineState extends State<_SalesFinalLine> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).pushNamed('/terms');

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.caption12(height: 1.5, color: c.textSecondary);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'All sales are final. '),
          TextSpan(
            text: 'See terms',
            recognizer: _terms,
            style: style.copyWith(
              color: c.textPrimary,
              decoration: TextDecoration.underline,
              decorationColor: c.textPrimary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

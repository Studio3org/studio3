import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/collect_checkout.dart';
import '../../models/feed_preview_item.dart';
import '../../services/api_exception.dart';
import '../../services/order_service.dart';
import '../../theme/collect_detail_tokens.dart';
import '../home_feed/home_feed_widgets.dart';
import 'collect_order_confirmation_sheet.dart';
import 'collect_payment_sheet.dart';
import 'collect_shipping_method_sheet.dart';
import 'collect_shipping_sheet.dart';

/// Collect checkout sheet — Figma 2340-2049.
class CollectPieceSheet extends StatefulWidget {
  const CollectPieceSheet({
    super.key,
    required this.item,
  });

  final FeedPreviewItem item;

  static Future<void> show(BuildContext context, {required FeedPreviewItem item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectPieceSheet(item: item),
    );
  }

  @override
  State<CollectPieceSheet> createState() => _CollectPieceSheetState();
}

class _CollectPieceSheetState extends State<CollectPieceSheet> {
  CollectShippingSelection? _shipping;
  CollectPaymentMethod? _payment;
  bool _collecting = false;

  FeedPreviewItem get item => widget.item;

  String get _imageUrl {
    final url = item.heroImageUrl;
    if (url != null && url.isNotEmpty) return url;
    return feedPreviewImageUrl(item);
  }

  String get _location {
    final region = item.shippingRegion;
    if (region == null || region.isEmpty) return '—';
    const prefix = 'Ships from ';
    if (region.startsWith(prefix)) return region.substring(prefix.length);
    return region;
  }

  int get _artworkCents => item.priceCents ?? 0;
  int get _shippingCents => _shipping?.method.priceCents ?? 0;
  int get _taxCents => (_artworkCents * 0.0825).round();
  int get _totalCents => _artworkCents + _shippingCents + _taxCents;

  Future<void> _openShipping() async {
    final address = await CollectShippingSheet.show(
      context,
      initial: _shipping?.address,
    );
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
    final result = await CollectPaymentSheet.show(
      context,
      initial: _payment,
    );
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
      const allowDevCheckout = bool.fromEnvironment(
        'ALLOW_DEV_CHECKOUT',
        defaultValue: false,
      );
      final canConfirm = kDebugMode || allowDevCheckout;

      if (!canConfirm) {
        if (!mounted) return;
        setState(() => _collecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payments are not live yet. Checkout confirm is disabled in this build.',
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.96;
    final shippingPlaceholder = _shipping == null
        ? 'Shipping rates calculated after entry'
        : '${_shipping!.method.title} · ${_shipping!.method.priceDisplay}';
    final paymentPlaceholder =
        _payment?.label ?? 'Add a payment method';

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: CollectDetailTokens.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _Header(onClose: () => Navigator.pop(context)),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                  children: [
                    _PieceCard(
                      imageUrl: _imageUrl,
                      title: item.title,
                      artistName: item.displayName,
                      priceDisplay: formatCollectPrice(item.priceCents),
                      year: '${item.year}',
                      medium: item.medium,
                      size: item.dimensions,
                      edition: 'One of a kind',
                      location: _location,
                      onViewHistory: () {},
                    ),
                    const SizedBox(height: 20),
                    _NavRow(
                      label: 'Shipping',
                      placeholder: shippingPlaceholder,
                      filled: _shipping != null,
                      onTap: _openShipping,
                    ),
                    const SizedBox(height: 20),
                    _NavRow(
                      label: 'Payment',
                      placeholder: paymentPlaceholder,
                      filled: _payment != null,
                      onTap: _openPayment,
                    ),
                    const SizedBox(height: 20),
                    _OrderSummaryCard(
                      artworkDisplay: formatMoney(_artworkCents),
                      shippingDisplay: _shipping == null
                          ? '—'
                          : formatMoney(_shippingCents),
                      taxDisplay: formatMoney(_taxCents),
                      totalDisplay: formatCollectPrice(_totalCents),
                    ),
                    const SizedBox(height: 28),
                    _CollectCta(
                      loading: _collecting,
                      onTap: _shipping == null || _collecting
                          ? null
                          : _onCollect,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
              ),
            ),
            Text(
              'Collect',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CollectDetailTokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.imageUrl,
    required this.title,
    required this.artistName,
    required this.priceDisplay,
    required this.year,
    required this.medium,
    required this.size,
    required this.edition,
    required this.location,
    required this.onViewHistory,
  });

  final String imageUrl;
  final String title;
  final String artistName;
  final String priceDisplay;
  final String year;
  final String medium;
  final String size;
  final String edition;
  final String location;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 118,
                    height: 118,
                    child: FeedPicsumImage(url: imageUrl),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artistName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        priceDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: CollectDetailTokens.divider),
            const SizedBox(height: 12),
            Text(
              'Piece Details',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: CollectDetailTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Year', value: year),
            _DetailRow(label: 'Medium', value: medium),
            _DetailRow(label: 'Size', value: size),
            _DetailRow(label: 'Edition', value: edition),
            _DetailRow(label: 'Location', value: location),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Provenance',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onViewHistory,
                    child: Text(
                      'View History →',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: CollectDetailTokens.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: CollectDetailTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final String placeholder;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CollectDetailTokens.sheetCardFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: CollectDetailTokens.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  placeholder,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: filled
                        ? CollectDetailTokens.textPrimary
                        : CollectDetailTokens.textDisabled,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: CollectDetailTokens.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.artworkDisplay,
    required this.shippingDisplay,
    required this.taxDisplay,
    required this.totalDisplay,
  });

  final String artworkDisplay;
  final String shippingDisplay;
  final String taxDisplay;
  final String totalDisplay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: CollectDetailTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryLine(label: 'Piece', value: artworkDisplay),
            const SizedBox(height: 8),
            _SummaryLine(label: 'Shipping', value: shippingDisplay),
            const SizedBox(height: 8),
            _SummaryLine(label: 'Tax', value: taxDisplay),
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
                  totalDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ],
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

class _CollectCta extends StatelessWidget {
  const _CollectCta({required this.onTap, this.loading = false});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CollectDetailTokens.collectButtonHeight,
      width: double.infinity,
      child: Material(
        color: onTap == null
            ? CollectDetailTokens.ctaFill.withValues(alpha: 0.5)
            : CollectDetailTokens.ctaFill,
        borderRadius: BorderRadius.circular(
          CollectDetailTokens.collectButtonRadius,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            CollectDetailTokens.collectButtonRadius,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CollectDetailTokens.textInverse,
                    ),
                  )
                : Text(
                    'Collect this piece',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: CollectDetailTokens.textInverse,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

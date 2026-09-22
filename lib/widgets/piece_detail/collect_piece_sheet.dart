import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

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
import '../../theme/app_fonts.dart';

/// Collect checkout sheet — Figma 2340-2049. Also doubles as the auction winner's
/// checkout (pass [winningBidCents]) — same shipping/payment steps, just priced from
/// the winning bid and posted to `auction-checkout` instead of `collect`.
class CollectPieceSheet extends StatefulWidget {
  const CollectPieceSheet({
    super.key,
    required this.item,
    this.winningBidCents,
    this.prepaidCents,
  });

  final FeedPreviewItem item;
  final int? winningBidCents;

  /// What the auction already collected when it closed and captured the winner's hold.
  ///
  /// The hammer price is taken at close, not here, so this checkout settles shipping and tax
  /// only. Showing the full total as due would read as a second charge for the artwork — and
  /// pricing the payment intent that way would have *been* one.
  final int? prepaidCents;

  /// Resolves to `true` when a purchase actually completed, so the caller can refresh the
  /// piece it is showing behind the sheet — otherwise a collected piece keeps showing its
  /// old "Collect" button until the viewer leaves the page and comes back.
  static Future<bool> show(
    BuildContext context, {
    required FeedPreviewItem item,
    int? winningBidCents,
    int? prepaidCents,
  }) async {
    final collected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectPieceSheet(
        item: item,
        winningBidCents: winningBidCents,
        prepaidCents: prepaidCents,
      ),
    );
    return collected ?? false;
  }

  @override
  State<CollectPieceSheet> createState() => _CollectPieceSheetState();
}

class _CollectPieceSheetState extends State<CollectPieceSheet> {
  CollectShippingSelection? _shipping;
  /// Shown inside the sheet. A SnackBar would render behind it: the sheet is anchored
  /// to the bottom and takes 96% of the height, which is why a failing checkout looked
  /// like the button simply doing nothing.
  String? _error;
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

  bool get _isAuctionCheckout => widget.winningBidCents != null;
  int get _artworkCents => widget.winningBidCents ?? item.priceCents ?? 0;
  int get _shippingCents => _shipping?.method.priceCents ?? 0;
  int get _taxCents => (_artworkCents * 0.0825).round();
  int get _totalCents => _artworkCents + _shippingCents + _taxCents;

  /// Already paid by the hold captured when the auction closed. Zero for fixed-price work.
  int get _prepaidCents => widget.prepaidCents ?? 0;

  /// What this checkout actually collects.
  int get _balanceDueCents => _totalCents - _prepaidCents;

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
    setState(() {
      _collecting = true;
      _error = null;
    });
    try {
      final order = _isAuctionCheckout
          ? await OrderService.instance.auctionCheckout(
              item.id,
              addressId: shipping.address.id,
              shippingMethod: shipping.method.id,
            )
          : await OrderService.instance.collect(
              item.id,
              addressId: shipping.address.id,
              shippingMethod: shipping.method.id,
            );

      final bool paid;
      if (_balanceDueCents <= 0) {
        // Nothing owed — skip Stripe entirely. Routing a free/fully-prepaid
        // collect through the payment sheet was the actual cause of this
        // getting stuck: the sheet has no defined behavior for a $0 charge.
        await OrderService.instance.confirm(order.id);
        paid = true;
      } else {
        paid = await _payForOrder(order.id);
      }
      if (!paid) return;

      final confirmed = await OrderService.instance.getOrder(order.id);
      if (!mounted) return;
      // Opened from the navigator captured before the pop, not this sheet's own context —
      // that element is being torn down by the pop itself, and a defunct context finds no
      // navigator to push the confirmation onto.
      final navigator = Navigator.of(context);
      navigator.pop(true);
      await CollectOrderConfirmationSheet.show(navigator.context, order: confirmed);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _collecting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _collecting = false;
        _error = 'Could not complete checkout. Please try again.';
      });
    }
  }

  /// Takes payment for [orderId] and waits for it to actually clear.
  ///
  /// Returns false (having already shown a message and reset state) if the
  /// collector cancels or payment doesn't go through.
  /// A message that identifies the failure rather than just reporting one.
  static String _stripeErrorText(StripeException e) {
    final detail = e.error.localizedMessage ?? e.error.message;
    final code = e.error.code.name;
    return detail == null || detail.isEmpty
        ? 'Payment was not completed ($code).'
        : '$detail ($code)';
  }

  Future<bool> _payForOrder(String orderId) async {
    // No publishable key configured — fall back to the server's dev auto-pay so
    // the flow stays testable, but never in a release build.
    if (Stripe.publishableKey.isEmpty) {
      const allowDevCheckout =
          bool.fromEnvironment('ALLOW_DEV_CHECKOUT', defaultValue: false);
      if (!(kDebugMode || allowDevCheckout)) {
        if (!mounted) return false;
        setState(() {
          _collecting = false;
          _error = 'Payments are not available in this build.';
        });
        return false;
      }
      await OrderService.instance.confirm(orderId);
      return true;
    }

    debugPrint('[checkout] requesting payment intent for $orderId');
    final intent = await OrderService.instance.createPaymentIntent(orderId);
    debugPrint('[checkout] got client secret, calling initPaymentSheet');
    // Inside the try below, deliberately. This call was outside it, so a Stripe
    // setup failure here bypassed the StripeException handler entirely and landed
    // in the generic catch as "Could not complete checkout" — hiding the one
    // message that says what is actually wrong.
    try {
      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: intent.clientSecret,
              merchantDisplayName: 'Studiothree',
              style: ThemeMode.light,
              // Where Stripe sends the buyer back to. Redirect-based methods
              // (Klarna, Cash App, Amazon Pay, Affirm) hand off to another app
              // or the browser, and the SDK refuses to open the sheet at all
              // unless it knows the way back. Not a web address: this is the
              // app's own scheme, in AndroidManifest.xml and Info.plist.
              returnURL: 'studio3://stripe-redirect',
            ),
          )
          // Pure setup call to Stripe's own servers, no user interaction —
          // if this hangs, fail visibly instead of leaving the collector
          // stuck on a spinner forever.
          .timeout(const Duration(seconds: 20));
      debugPrint('[checkout] initPaymentSheet returned, presenting sheet');

      // Long backstop, not a short one: this call legitimately blocks on
      // the collector entering a card / confirming biometrics, so it must
      // not cut off someone who's just taking their time — it only matters
      // when the call is truly wedged (the bug this guards against).
      await Stripe.instance.presentPaymentSheet().timeout(const Duration(minutes: 5));
      debugPrint('[checkout] payment sheet completed');
    } on TimeoutException {
      debugPrint('[checkout] TIMED OUT waiting on the Stripe SDK');
      if (!mounted) return false;
      setState(() {
        _collecting = false;
        _error = 'Payment is taking longer than expected. Please try again.';
      });
      return false;
    } on StripeException catch (e) {
      if (!mounted) return false;
      // Stripe's localizedMessage is often null for setup failures (a missing
      // returnURL, an unconfigured payment method), which left the banner saying
      // only "Payment was not completed" — true, and useless for working out why.
      // Carry the code and raw message through so a failure names itself.
      debugPrint('PaymentSheet failed: code=${e.error.code} '
          'message=${e.error.message} localized=${e.error.localizedMessage} '
          'declineCode=${e.error.declineCode} type=${e.error.type}');
      setState(() {
        _collecting = false;
        // Cancelling isn't an error worth shouting about.
        _error = e.error.code == FailureCode.Canceled
            ? null
            : _stripeErrorText(e);
      });
      return false;
    }

    // The sheet succeeding isn't proof the order is paid: a Stripe webhook is
    // what actually marks it, so wait for that rather than assuming.
    final paid = await OrderService.instance.waitForPayment(orderId);
    if (!paid) {
      if (!mounted) return false;
      setState(() => _collecting = false);
      setState(() => _error = "Payment went through but we're still confirming it. "
          'Check your orders in a moment.');
      return false;
    }
    return true;
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
              _Header(
                title: _isAuctionCheckout ? 'Complete purchase' : 'Collect',
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                  children: [
                    _PieceCard(
                      imageUrl: _imageUrl,
                      title: item.title,
                      artistName: item.displayName,
                      priceDisplay: formatCollectPrice(_artworkCents),
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
                      // Only ever set for an auction win, where the hammer price was taken
                      // when the auction closed.
                      alreadyPaidDisplay: _prepaidCents > 0
                          ? formatMoney(_prepaidCents)
                          : null,
                      dueDisplay: formatCollectPrice(_balanceDueCents),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 28),
                    _CollectCta(
                      label: _isAuctionCheckout
                          ? 'Complete purchase'
                          : 'Collect this piece',
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
  const _Header({required this.onClose, this.title = 'Collect'});

  final VoidCallback onClose;
  final String title;

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
              title,
              style: AppFonts.inter(
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
                        style: AppFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artistName,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        priceDisplay,
                        style: AppFonts.inter(
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
              style: AppFonts.inter(
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
                    style: AppFonts.inter(
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
                      style: AppFonts.inter(
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
            style: AppFonts.inter(
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
              style: AppFonts.inter(
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
                  style: AppFonts.inter(
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
                  style: AppFonts.inter(
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
    required this.dueDisplay,
    this.alreadyPaidDisplay,
  });

  final String artworkDisplay;
  final String shippingDisplay;
  final String taxDisplay;
  final String totalDisplay;

  /// What the auction already collected. Null for fixed-price work, where the total and the
  /// amount due are the same number and a second line would just be noise.
  final String? alreadyPaidDisplay;

  /// What this checkout actually charges. Equals the total unless something was prepaid.
  final String dueDisplay;

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
              style: AppFonts.inter(
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
                  alreadyPaidDisplay == null ? 'Total' : 'Order total',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  totalDisplay,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
              ],
            ),
            // The two lines that stop an auction winner thinking they are being charged for
            // the artwork twice. Their bid was captured when the auction closed; all that is
            // left here is shipping and tax.
            if (alreadyPaidDisplay != null) ...[
              const SizedBox(height: 8),
              _SummaryLine(
                label: 'Paid when you won',
                value: '−$alreadyPaidDisplay',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Due now',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dueDisplay,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
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
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: CollectDetailTokens.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: CollectDetailTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5B4B4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFF9B2C2C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppFonts.inter(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9B2C2C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _CollectCta extends StatelessWidget {
  const _CollectCta({
    required this.onTap,
    this.loading = false,
    this.label = 'Collect this piece',
  });

  final VoidCallback? onTap;
  final bool loading;
  final String label;

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
                    label,
                    style: AppFonts.inter(
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

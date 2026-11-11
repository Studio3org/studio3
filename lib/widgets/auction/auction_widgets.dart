import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;

import '../../models/address.dart';
import '../../models/auction.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../services/bid_service.dart';
import '../../services/stripe_setup.dart';
import '../create_flow/post_availability_step.dart'
    show PostAvailabilityStep, PriceInputFormatter, formatUsd;
import '../piece_detail/collect_shipping_sheet.dart';
import '../studio/studio.dart';

/// Which bar an auction piece shows (`BuyPieceScrolled`, `BidLeading`, `BidOutbid`).
enum AuctionBarState {
  /// Bidding is open and the viewer has no bid here: Place a bid.
  open,

  /// The viewer is the highest bidder: green "Your bid", Raise your bid.
  leading,

  /// The viewer bid here but someone bid higher: red "Outbid", Bid [next minimum].
  outbid,

  /// The artist's own auction: the same info; Manage auction (extend, cancel, relist).
  owner,

  /// The viewer won and still has to confirm shipping: Finish checkout.
  won,

  /// The viewer won and shipping is charged without a checkout once Convelio prices it
  /// (FRONTEND_HANDOFF 7b `pending_quote`): a disabled "Shipping price on its way".
  shippingPending,

  /// The piece is offered to the viewer after the winner forfeited (7a.4): Accept for $X.
  secondChance,

  /// The viewer won and their card was declined: Update card.
  paymentFailed,

  /// Closed for the viewer.
  ended,
}

/// The bar's state from the auction and the viewer's own bid: the server's [myBidStatus]
/// (BACKEND_CHANGES B18) when it sends one, else what this phone remembers ([myTopBidCents]).
AuctionBarState auctionBarState({
  required AuctionSummary? auction,
  required bool isOwner,
  required int? myTopBidCents,
  String? myBidStatus,
}) {
  if (auction == null) return AuctionBarState.ended;
  if (auction.secondChanceOffer != null && !isOwner) return AuctionBarState.secondChance;
  if (auction.isWinner && auction.awaitingPayment) return AuctionBarState.paymentFailed;
  if (auction.isWinner && auction.isSettling) {
    return auction.autoCheckout?.isPendingQuote == true
        ? AuctionBarState.shippingPending
        : AuctionBarState.won;
  }
  if (!auction.isOpen) return AuctionBarState.ended;
  if (isOwner) return AuctionBarState.owner;
  if (auction.isHighestBidder) return AuctionBarState.leading;
  final outbid = myBidStatus != null ? myBidStatus == 'outbid' : myTopBidCents != null;
  if (outbid) return AuctionBarState.outbid;
  return AuctionBarState.open;
}

/// The auction piece's bottom bar. Info row: "Current bid · [N] bids" (or the viewer's
/// status with a 2 px green or red line, as the selected option rows) and Time remaining,
/// red under 24 hours; "Reserve not met yet" in Mono under it while that is true; then the
/// 52 button. No message button: piece messaging is off (as `BuyPiece`, section 0.3).
class AuctionBar extends StatelessWidget {
  const AuctionBar({
    super.key,
    required this.auction,
    required this.state,
    required this.onPrimary,
    this.now,
  });

  final AuctionSummary? auction;
  final AuctionBarState state;
  final VoidCallback? onPrimary;

  @visibleForTesting
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final a = auction;
    final at = now ?? DateTime.now();
    final soon = auctionEndingSoon(a?.endsAt, at);
    final label = switch (state) {
      AuctionBarState.open => 'Place a bid',
      AuctionBarState.leading => 'Raise your bid',
      AuctionBarState.outbid => 'Bid ${formatUsd(a?.minNextBidCents ?? 0)}',
      AuctionBarState.owner => 'Manage auction',
      AuctionBarState.won => 'Finish checkout',
      AuctionBarState.shippingPending => 'Shipping price on its way',
      AuctionBarState.secondChance =>
        'Accept for ${formatUsd(a?.secondChanceOffer?.amountCents ?? 0)}',
      AuctionBarState.paymentFailed => 'Update card',
      AuctionBarState.ended => 'Auction ended',
    };
    final enabled = state != AuctionBarState.ended && state != AuctionBarState.shippingPending;

    StudioBottomBarInfo? left;
    StudioBottomBarInfo? right;
    Widget? leftChild;
    if (a != null) {
      switch (state) {
        case AuctionBarState.secondChance:
          final offer = a.secondChanceOffer!;
          left = StudioBottomBarInfo(label: 'Your top bid', value: formatUsd(offer.amountCents));
          final expires = offer.expiresAt;
          if (expires != null) {
            right = StudioBottomBarInfo(label: 'Offer ends in', value: auctionCountdown(expires, at));
          }
        case AuctionBarState.shippingPending:
          left = StudioBottomBarInfo(
            label: 'Winning bid',
            value: formatUsd(a.winningBidCents ?? a.currentCents),
          );
        case AuctionBarState.won:
        case AuctionBarState.paymentFailed:
          left = StudioBottomBarInfo(
            label: 'Winning bid',
            value: formatUsd(a.winningBidCents ?? a.currentCents),
          );
          final deadline = a.winnerDeadlineAt;
          if (deadline != null) {
            right = StudioBottomBarInfo(label: 'Time to pay', value: auctionCountdown(deadline, at));
          }
        case AuctionBarState.ended:
          break;
        default:
          right = StudioBottomBarInfo(
            label: 'Time remaining',
            value: auctionTimeLeft(a.endsAt, at),
            valueColor: soon ? c.alert : null,
            strong: soon,
          );
          if (state == AuctionBarState.leading || state == AuctionBarState.outbid) {
            leftChild = _BidStatus(
              leading: state == AuctionBarState.leading,
              bidCount: a.bidCount,
              amountCents: a.currentCents,
            );
          } else {
            left = null;
            leftChild = _CurrentBid(auction: a);
          }
      }
    }
    final showReserve = a != null && a.isOpen && a.hasReserve && !a.reserveMet;
    return StudioBottomBar(
      left: left,
      leftChild: leftChild,
      right: right,
      note: showReserve
          ? Text('Reserve not met yet', style: StudioType.mono(11, color: c.textTertiary))
          : null,
      button: StudioButton(label: label, fontSize: 16, onPressed: enabled ? onPrimary : null),
    );
  }
}

/// "Current bid · [N] bids" (Starting bid before any) over the amount, Geist 17.
class _CurrentBid extends StatelessWidget {
  const _CurrentBid({required this.auction});

  final AuctionSummary auction;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final bids = auction.bidCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: bids == 0
                ? const [TextSpan(text: 'Starting bid')]
                : [
                    const TextSpan(text: 'Current bid · '),
                    TextSpan(text: '$bids', style: StudioType.mono(12, color: c.textSecondary)),
                    TextSpan(text: bids == 1 ? ' bid' : ' bids'),
                  ],
          ),
          style: StudioType.caption12(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          formatUsd(auction.currentCents),
          style: StudioType.header17(weight: StudioType.regular, color: c.textPrimary),
        ),
      ],
    );
  }
}

/// `BidLeading` / `BidOutbid`: a 2 px green or red line on the left (12 in), "Your bid" or
/// "Outbid" 500 in that colour, "· [N] bids", then the amount.
class _BidStatus extends StatelessWidget {
  const _BidStatus({required this.leading, required this.bidCount, required this.amountCents});

  final bool leading;
  final int bidCount;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final color = leading ? c.positive : c.alert;
    return Semantics(
      liveRegion: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(width: 2, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: leading ? 'Your bid' : 'Outbid',
                        style: StudioType.caption12(color: color).copyWith(
                          fontWeight: StudioType.medium,
                        ),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: '$bidCount',
                        style: StudioType.mono(12, color: c.textSecondary),
                      ),
                      TextSpan(text: bidCount == 1 ? ' bid' : ' bids'),
                    ],
                  ),
                  style: StudioType.caption12(color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  formatUsd(amountCents),
                  style: StudioType.header17(weight: StudioType.regular, color: c.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What `BidVerify` returns: the saved card and the Ship to address (null without Ship to).
typedef BidVerifyResult = ({String paymentMethodId, String? addressId});

/// "Before you bid" (`BidVerify`): first bid only. A Card row in a boxed field: it opens
/// Stripe's PaymentSheet on a SetupIntent (Apple Pay and Google Pay when configured), where
/// the bank checks the card once; nothing is held (FRONTEND_HANDOFF 7a.1). Then Ship to: a
/// saved address (the default, or the first), which opens the address picker. Save and
/// continue, then "Saving lets us charge this card if you win." with the bidding terms.
/// Returns the saved card's payment method id and the address id.
///
/// With [shipTo] off it is just the card (`BidPaymentFailed` Use another card): "Add a card".
class BidVerifySheet extends StatefulWidget {
  const BidVerifySheet({
    super.key,
    this.shipTo = true,
    this.saveCard,
    this.debugAddresses,
    this.pickAddress,
  });

  final bool shipTo;

  /// For tests: saving a card (Stripe's PaymentSheet is native). Null when they backed out.
  @visibleForTesting
  final Future<SavedCard?> Function()? saveCard;

  /// For tests: the saved addresses, and the picker Ship to opens.
  @visibleForTesting
  final List<Address>? debugAddresses;
  @visibleForTesting
  final Future<Address?> Function(Address? current)? pickAddress;

  static Future<BidVerifyResult?> show(BuildContext context, {bool shipTo = true}) {
    return showStudioSheet<BidVerifyResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => BidVerifySheet(shipTo: shipTo),
    );
  }

  @override
  State<BidVerifySheet> createState() => _BidVerifySheetState();
}

class _BidVerifySheetState extends State<BidVerifySheet> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).pushNamed('/terms');
  SavedCard? _card;
  bool _addingCard = false;
  bool _saving = false;
  String? _error;
  Address? _address;

  @override
  void initState() {
    super.initState();
    if (!widget.shipTo) return;
    loadBidShipTo(widget.debugAddresses, (a) {
      if (mounted && _address == null) setState(() => _address = a);
    });
  }

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  bool get _canAddCard => widget.saveCard != null || StripeSetup.ready;

  bool get _ready => _card != null && (!widget.shipTo || _address != null) && !_saving && !_addingCard;

  Future<void> _pickAddress() async {
    final picked = await (widget.pickAddress ??
        (current) => CollectShippingSheet.show(context, initial: current))(_address);
    if (picked != null && mounted) setState(() => _address = picked);
  }

  Future<void> _addCard() async {
    setState(() {
      _addingCard = true;
      _error = null;
    });
    try {
      final card = await (widget.saveCard ?? BidService.instance.saveCard)();
      if (!mounted) return;
      setState(() {
        _addingCard = false;
        if (card != null) _card = card;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addingCard = false;
        _error = e is ApiException
            ? e.message
            : e is StripeException
            ? (e.error.localizedMessage ?? "The card couldn't be saved.")
            : "The card couldn't be saved. Try again.";
      });
    }
  }

  Future<void> _save() async {
    final card = _card;
    if (card == null) return;
    setState(() => _saving = true);
    final zip = _address?.zip ?? '';
    // The ZIP, for the piece page's shipping estimate.
    if (zip.isNotEmpty) await BidStore.instance.saveZip(zip);
    if (mounted) {
      Navigator.pop<BidVerifyResult>(context, (
        paymentMethodId: card.id,
        addressId: widget.shipTo ? _address?.id : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final card = _card;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 18,
      scrollable: true,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.shipTo ? 'Before you bid' : 'Add a card',
              style: StudioType.sans(22, weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              widget.shipTo
                  ? 'If you win, this card is charged when the auction ends.'
                  : "It's charged for this piece right away.",
              style: StudioType.body15(height: 1.45, color: c.textSecondary),
            ),
          ],
        ),
        // The card in a 10 radius box (`BidVerify`), white on the sheet: tap to add one in
        // Stripe's sheet.
        Semantics(
          button: _canAddCard,
          label: card == null ? 'Card, add your card' : 'Card, ${card.label}',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: !_canAddCard || _addingCard || _saving ? null : _addCard,
            child: Container(
              key: const Key('bid-verify-card'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(StudioRadius.card),
                border: Border.all(color: c.lineStrong),
              ),
              child: !_canAddCard
                  ? Text(
                      'Card payments are not set up in this build yet.',
                      style: StudioType.body14(color: c.textSecondary),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Card', style: StudioType.sans(13, color: c.textSecondary)),
                              const SizedBox(height: 3),
                              Text(
                                card == null ? 'Add your card' : card.label,
                                style: StudioType.sans(
                                  15,
                                  color: card == null ? c.textTertiary : c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_addingCard)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: c.textSecondary),
                          )
                        else
                          StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
                      ],
                    ),
            ),
          ),
        ),
        if (widget.shipTo)
          BidShipToRow(
            key: const Key('bid-verify-ship-to'),
            address: _address,
            onTap: _saving ? null : _pickAddress,
          ),
        if (_error != null) Text(_error!, style: StudioType.body14(color: c.textPrimary)),
        StudioButton(
          label: 'Save and continue',
          height: StudioSize.buttonPrimaryTall,
          loading: _saving,
          onPressed: _ready ? _save : null,
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Saving lets us charge this card if you win. '),
              TextSpan(
                text: 'Bidding terms',
                recognizer: _terms,
                style: TextStyle(
                  color: c.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: c.textPrimary,
                ),
              ),
            ],
          ),
          style: StudioType.caption12(height: 1.5, color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Reads the bidder's saved addresses ([debug] in tests) and reports the preferred one: the
/// default, or the first. Failures leave Ship to empty.
void loadBidShipTo(List<Address>? debug, ValueChanged<Address?> onLoaded) {
  Address? preferred(List<Address> list) =>
      list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
  if (debug != null) {
    onLoaded(preferred(debug));
    return;
  }
  AddressService.instance
      .getAddresses()
      .then((list) => onLoaded(preferred(list)))
      .catchError((Object _) {});
}

/// Ship to (`BidVerify`): "Ship to" over the address on one line (or "Add your address"), a
/// chevron, a Line under. Opens the address picker.
class BidShipToRow extends StatelessWidget {
  const BidShipToRow({super.key, required this.address, required this.onTap});

  final Address? address;
  final VoidCallback? onTap;

  /// "Jordan Lee, 4521 Lovers Ln, Dallas, TX 75225".
  static String oneLine(Address a) {
    final name = [a.firstName, a.lastName].where((p) => p.trim().isNotEmpty).join(' ');
    return [
      if (name.isNotEmpty) name,
      a.line1,
      a.city,
      '${a.state} ${a.zip}'.trim(),
    ].where((p) => p.trim().isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final a = address;
    return Semantics(
      button: true,
      label: a == null ? 'Ship to, add your address' : 'Ship to, ${oneLine(a)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ship to', style: StudioType.sans(13, color: c.textSecondary)),
                    const SizedBox(height: 3),
                    Text(
                      a == null ? 'Add your address' : oneLine(a),
                      style: StudioType.sans(15, color: a == null ? c.textTertiary : c.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StudioIcon(StudioIcons.chevronRight, size: 18, color: c.textPlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}

/// Place a bid (`BidSheet`): Current bid · [N] bids and Time remaining; "Your bid" 32/500 on
/// an Ink underline with "at least $X"; three quick picks (the minimum, then one and two
/// steps up); Reserve not met yet with its tooltip; Bid $X; the fine print with the card.
/// A bid the server now finds too low keeps what was typed and says the new minimum.
/// Returns the auction after the bid.
///
/// [addressId] is the Ship to picked in `BidVerify`. A returning bidder (a saved card, so no
/// `BidVerify`) bidding on this piece for the first time gets the Ship to row here instead
/// ([shipTo]), so the win can be delivered without a checkout (FRONTEND_HANDOFF 7a.1, 7b).
class BidSheet extends StatefulWidget {
  const BidSheet({
    super.key,
    required this.pieceId,
    required this.auction,
    required this.card,
    this.addressId,
    this.shipTo = false,
    this.placeBid,
    this.refresh,
    this.now,
    this.debugAddresses,
    this.pickAddress,
  });

  final String pieceId;
  final AuctionSummary auction;
  final SavedCard card;
  final String? addressId;
  final bool shipTo;

  /// For tests: the saved addresses, and the picker Ship to opens.
  @visibleForTesting
  final List<Address>? debugAddresses;
  @visibleForTesting
  final Future<Address?> Function(Address? current)? pickAddress;

  /// For tests: the bid call, and re-reading the auction after a rejected bid.
  @visibleForTesting
  final Future<AuctionSummary> Function(int amountCents)? placeBid;
  final Future<AuctionSummary?> Function()? refresh;
  @visibleForTesting
  final DateTime? now;

  static Future<AuctionSummary?> show(
    BuildContext context, {
    required String pieceId,
    required AuctionSummary auction,
    required SavedCard card,
    String? addressId,
    bool shipTo = false,
    Future<AuctionSummary?> Function()? refresh,
  }) {
    return showStudioSheet<AuctionSummary>(
      context: context,
      useRootNavigator: true,
      builder: (_) => BidSheet(
        pieceId: pieceId,
        auction: auction,
        card: card,
        addressId: addressId,
        shipTo: shipTo,
        refresh: refresh,
      ),
    );
  }

  @override
  State<BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<BidSheet> {
  late AuctionSummary _auction = widget.auction;
  late final _amount = TextEditingController(text: formatUsd(_auction.minNextBidCents))
    ..addListener(() => setState(() => _error = null));
  bool _sending = false;
  String? _error;
  Address? _address;

  @override
  void initState() {
    super.initState();
    if (!widget.shipTo) return;
    loadBidShipTo(widget.debugAddresses, (a) {
      if (mounted && _address == null) setState(() => _address = a);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await (widget.pickAddress ??
        (current) => CollectShippingSheet.show(context, initial: current))(_address);
    if (picked != null && mounted) setState(() => _address = picked);
  }

  int? get _cents => PostAvailabilityStep.parseCents(_amount.text);

  void _pick(int cents) => _amount.text = formatUsd(cents);

  Future<void> _bid() async {
    final cents = _cents;
    if (cents == null || cents < _auction.minNextBidCents) return;
    setState(() => _sending = true);
    try {
      final after = await (widget.placeBid ??
          (amount) => BidService.instance.placeBid(
            widget.pieceId,
            amountCents: amount,
            paymentMethodId: widget.card.id,
            addressId: widget.shipTo ? _address?.id : widget.addressId,
          ))(cents);
      if (mounted) Navigator.pop(context, after);
    } on ApiException catch (e) {
      if (!mounted) return;
      final fresh = await widget.refresh?.call();
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (fresh != null) _auction = fresh;
        _error = e.message.isNotEmpty ? e.message : 'That bid didn\'t go through.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = "That bid didn't go through. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final a = _auction;
    final at = widget.now ?? DateTime.now();
    final soon = auctionEndingSoon(a.endsAt, at);
    final cents = _cents;
    // The server's step when it sends one, else the table on the current high bid.
    final picks = bidQuickPicks(
      a.minNextBidCents,
      stepCents: a.bidIncrementCents > 0 ? a.bidIncrementCents : bidIncrementCents(a.currentCents),
    );
    final valid = cents != null && cents >= a.minNextBidCents;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 18,
      scrollable: true,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CurrentBid(auction: a),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Time remaining', style: StudioType.caption12(color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  auctionTimeLeft(a.endsAt, at),
                  style: StudioType.header17(
                    weight: soon ? StudioType.medium : StudioType.regular,
                    color: soon ? c.alert : c.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your bid', style: StudioType.sans(13, color: c.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.textPrimary, width: 1.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [PriceInputFormatter()],
                      cursorColor: c.textPrimary,
                      style: StudioType.sans(
                        32,
                        weight: StudioType.medium,
                        letterSpacing: -0.5,
                        color: c.textPrimary,
                      ),
                      decoration: const InputDecoration.collapsed(hintText: null),
                    ),
                  ),
                  Text(
                    'at least ${formatUsd(a.minNextBidCents)}',
                    style: StudioType.caption12(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: StudioType.body14(color: c.textPrimary)),
            ],
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < picks.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _QuickPick(
                  label: formatUsd(picks[i]),
                  selected: cents == picks[i],
                  onTap: () => _pick(picks[i]),
                ),
              ),
            ],
          ],
        ),
        if (a.hasReserve) _ReserveLine(met: a.reserveMet),
        if (widget.shipTo)
          BidShipToRow(
            key: const Key('bid-sheet-ship-to'),
            address: _address,
            onTap: _sending ? null : _pickAddress,
          ),
        StudioButton(
          label: valid ? 'Bid ${formatUsd(cents)}' : 'Bid',
          height: StudioSize.buttonPrimaryTall,
          loading: _sending,
          onPressed: valid && !_sending ? _bid : null,
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: "Bids can't be taken back. The card ending ",
              ),
              TextSpan(
                text: widget.card.last4,
                style: StudioType.mono(12, color: c.textSecondary),
              ),
              const TextSpan(
                text: ' is charged only if you win, and shipping, insurance and tax follow on '
                    'it automatically where we can. All sales are final.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: StudioType.caption12(height: 1.5, color: c.textSecondary),
        ),
      ],
    );
  }
}

/// 40 tall, radius 10: the selected pick Ink with 500 text, the others outlined.
class _QuickPick extends StatelessWidget {
  const _QuickPick({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: StudioMotion.quick,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.buttonFill : null,
            borderRadius: BorderRadius.circular(StudioRadius.card),
            border: selected ? null : Border.all(color: c.lineStrong),
          ),
          child: Text(
            label,
            style: StudioType.sans(
              14,
              weight: selected ? StudioType.medium : StudioType.regular,
              color: selected ? c.buttonText : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Reserve not met yet" (or "Reserve met") in Mono 11 with a 6 px ring, and its tooltip.
/// The amount is never shown.
class _ReserveLine extends StatelessWidget {
  const _ReserveLine({required this.met});

  final bool met;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioTooltip(
      arrowLeft: 132,
      message: "The artist's private minimum. Below it, the piece doesn't sell and no one is charged.",
      builder: (context, toggle) => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met ? c.textSecondary : null,
              border: Border.all(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            met ? 'Reserve met' : 'Reserve not met yet',
            style: StudioType.mono(11, color: c.textSecondary),
          ),
          const SizedBox(width: 8),
          StudioInfoButton(onTap: toggle, semanticLabel: 'What is the reserve?'),
          const Spacer(),
        ],
      ),
    );
  }
}

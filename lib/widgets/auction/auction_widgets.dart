import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../models/auction.dart';
import '../../services/api_exception.dart';
import '../../services/bid_service.dart';
import '../../services/stripe_setup.dart';
import '../create_flow/post_availability_step.dart'
    show PostAvailabilityStep, PriceInputFormatter, formatUsd;
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

  /// The viewer won and their card was declined: Update card.
  paymentFailed,

  /// Closed for the viewer.
  ended,
}

/// The bar's state from the auction and what this phone knows about the viewer's bids.
AuctionBarState auctionBarState({
  required AuctionSummary? auction,
  required bool isOwner,
  required int? myTopBidCents,
}) {
  if (auction == null) return AuctionBarState.ended;
  if (auction.isWinner && auction.awaitingPayment) return AuctionBarState.paymentFailed;
  if (auction.isWinner && auction.isSettling) return AuctionBarState.won;
  if (!auction.isOpen) return AuctionBarState.ended;
  if (isOwner) return AuctionBarState.owner;
  if (auction.isHighestBidder) return AuctionBarState.leading;
  if (myTopBidCents != null) return AuctionBarState.outbid;
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
      AuctionBarState.paymentFailed => 'Update card',
      AuctionBarState.ended => 'Auction ended',
    };
    final enabled = state != AuctionBarState.ended;

    StudioBottomBarInfo? left;
    StudioBottomBarInfo? right;
    Widget? leftChild;
    if (a != null) {
      switch (state) {
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

/// "Add a card to bid" (`BidVerify`): first bid only. The card is checked with a setup
/// intent (no hold), and the ZIP is kept for the shipping estimate. Returns the saved
/// card's payment method id.
class BidVerifySheet extends StatefulWidget {
  const BidVerifySheet({super.key, this.saveCard, this.cardField});

  /// For tests: saving the card, and the card field (Stripe's is a platform view).
  @visibleForTesting
  final Future<String> Function(String zip)? saveCard;
  @visibleForTesting
  final Widget Function(ValueChanged<bool> onComplete)? cardField;

  static Future<String?> show(BuildContext context) {
    return showStudioSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const BidVerifySheet(),
    );
  }

  @override
  State<BidVerifySheet> createState() => _BidVerifySheetState();
}

class _BidVerifySheetState extends State<BidVerifySheet> {
  final _zip = TextEditingController();
  late final _terms = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).pushNamed('/terms');
  bool _cardComplete = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _zip.addListener(() => setState(() {}));
    BidStore.instance.zip().then((z) {
      if (mounted && z != null && _zip.text.isEmpty) _zip.text = z;
    });
  }

  @override
  void dispose() {
    _zip.dispose();
    _terms.dispose();
    super.dispose();
  }

  bool get _ready => _cardComplete && _zip.text.trim().length >= 5 && !_saving;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final zip = _zip.text.trim();
    try {
      final id = await (widget.saveCard ?? (z) => BidService.instance.saveCard(zip: z))(zip);
      await BidStore.instance.saveZip(zip);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException
            ? e.message
            : e is StripeException
            ? (e.error.localizedMessage ?? "The card couldn't be saved.")
            : "The card couldn't be saved. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    void onComplete(bool complete) {
      if (complete != _cardComplete) setState(() => _cardComplete = complete);
    }

    return StudioSheet(
      horizontalPadding: 24,
      gap: 18,
      scrollable: true,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a card to bid',
              style: StudioType.sans(22, weight: StudioType.medium, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll check it's valid. You're only charged if you win.",
              style: StudioType.body15(height: 1.45, color: c.textSecondary),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Card', style: StudioType.sans(13, color: c.textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.textPrimary, width: 1.5)),
              ),
              child: widget.cardField?.call(onComplete) ??
                  (StripeSetup.ready
                      ? CardField(
                          enablePostalCode: false,
                          style: StudioType.mono(17, color: c.textPrimary),
                          cursorColor: c.textPrimary,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onCardChanged: (details) => onComplete(details?.complete ?? false),
                        )
                      : Text(
                          'Card payments are not set up in this build yet.',
                          style: StudioType.body14(color: c.textSecondary),
                        )),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: StudioUnderlineField(
                label: 'ZIP',
                controller: _zip,
                mono: true,
                valueSize: 17,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                autofillHints: const [AutofillHints.postalCode],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'We use your ZIP to estimate shipping before you bid.',
                  style: StudioType.caption12(height: 1.45, color: c.textSecondary),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) Text(_error!, style: StudioType.body14(color: c.textPrimary)),
        StudioButton(
          label: 'Save card and continue',
          height: StudioSize.buttonPrimaryTall,
          loading: _saving,
          onPressed: _ready ? _save : null,
        ),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Card details are handled securely by Stripe. By continuing, you agree '
                    'to our ',
              ),
              TextSpan(
                text: 'bidding terms',
                recognizer: _terms,
                style: TextStyle(
                  color: c.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: c.textPrimary,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: StudioType.caption12(height: 1.5, color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Place a bid (`BidSheet`): Current bid · [N] bids and Time remaining; "Your bid" 32/500 on
/// an Ink underline with "at least $X"; three quick picks (the minimum, then one and two
/// steps up); Reserve not met yet with its tooltip; Bid $X; the fine print with the card.
/// A bid the server now finds too low keeps what was typed and says the new minimum.
/// Returns the auction after the bid.
class BidSheet extends StatefulWidget {
  const BidSheet({
    super.key,
    required this.pieceId,
    required this.auction,
    required this.card,
    this.placeBid,
    this.refresh,
    this.now,
  });

  final String pieceId;
  final AuctionSummary auction;
  final SavedCard card;

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
    Future<AuctionSummary?> Function()? refresh,
  }) {
    return showStudioSheet<AuctionSummary>(
      context: context,
      useRootNavigator: true,
      builder: (_) => BidSheet(pieceId: pieceId, auction: auction, card: card, refresh: refresh),
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

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
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
    final picks = bidQuickPicks(a.minNextBidCents);
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
                text: "Bids can't be taken back. Tax and shipping are added at checkout. If "
                    "you win, you'll confirm shipping and pay with the card ending ",
              ),
              TextSpan(
                text: widget.card.last4,
                style: StudioType.mono(12, color: c.textSecondary),
              ),
              const TextSpan(text: '. All sales are final.'),
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
      message:
          "The artist set a private minimum price. If bidding ends below it, the piece "
          "doesn't sell and no one is charged. This changes to Reserve met once a bid "
          'reaches it.',
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

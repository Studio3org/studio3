import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/saved_content_store.dart';
import '../widgets/save_flow.dart';
import '../models/auction.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/bid_service.dart';
import '../services/main_nav_service.dart';
import '../services/piece_service.dart';
import '../services/social_service.dart';
import '../utils/explore_detail_route.dart';
import '../utils/profile_navigation.dart';
import '../utils/require_login.dart';
import '../utils/slide_up_page_route.dart';
import '../widgets/auction/artist_auction.dart' show winnerDeadlinePhrase;
import '../widgets/auction/auction_widgets.dart';
import '../widgets/create_flow/post_availability_step.dart' show formatUsd;
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/studio/studio.dart';

/// Place a bid from the piece page (Flow 7): sign in, add a card and Ship to the first time
/// (`BidVerify`), then the bid sheet (`BidSheet`). A returning bidder (a saved card) picks Ship
/// to in the bid sheet on their first bid on this piece ([myBidStatus] none, or not sent).
/// Returns the auction after the bid.
Future<AuctionSummary?> startBidding(
  BuildContext context, {
  required String pieceId,
  required AuctionSummary auction,
  String? myBidStatus,
}) async {
  if (!await requireLogin(
    context,
    title: 'Sign in to bid',
    message: 'Log in or create a free account to bid on art.',
  )) {
    return null;
  }
  if (!context.mounted) return null;
  SavedCard? card;
  try {
    final cards = await BidService.instance.cards();
    if (cards.isNotEmpty) card = cards.first;
  } catch (_) {}
  if (!context.mounted) return null;
  String? addressId;
  var shipTo = false;
  if (card == null) {
    final verified = await BidVerifySheet.show(context);
    if (verified == null || !context.mounted) return null;
    final id = verified.paymentMethodId;
    addressId = verified.addressId;
    try {
      final cards = await BidService.instance.cards();
      card = cards.firstWhere((c) => c.id == id, orElse: () => SavedCard(id: id, brand: '', last4: ''));
    } catch (_) {
      card = SavedCard(id: id, brand: '', last4: '');
    }
    if (!context.mounted) return null;
  } else {
    shipTo = (myBidStatus == null || myBidStatus == 'none') && !auction.isHighestBidder;
  }
  final after = await BidSheet.show(
    context,
    pieceId: pieceId,
    auction: auction,
    card: card,
    addressId: addressId,
    shipTo: shipTo,
    refresh: () async => (await PieceService.instance.getById(pieceId)).auction,
  );
  if (after != null && context.mounted) {
    showStudioToast(
      context,
      after.isHighestBidder ? "You're the highest bidder" : 'Bid placed',
    );
  }
  return after;
}

/// Opens what an auction notification is about: You won (`BidWon`), the payment problem
/// (`BidPaymentFailed`), a second-chance offer (`BidSecondChance`), the loss (`BidLost`) or
/// the no-sale (`BidReserveNotMet`). A piece already bought (sold, or the viewer's order on
/// it) opens the piece itself, with its order and tracking (FRONTEND_HANDOFF 7b).
///
/// [fromPiece]: opened from the piece page, so "the piece" is the page underneath.
Future<void> openAuctionOutcome(
  BuildContext context, {
  required String pieceId,
  required String type,
  bool fromPiece = false,
}) async {
  PieceSummary piece;
  try {
    piece = await PieceService.instance.getById(pieceId);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not load the piece', icon: null);
    return;
  }
  if (!context.mounted) return;
  // "Your top bid" from the server, from any phone (BACKEND_CHANGES B18); else this phone's.
  final myTop = piece.myTopBidCents ?? await BidStore.instance.topBid(pieceId);
  if (!context.mounted) return;
  final page = auctionOutcomePage(piece, type: type, myTopBidCents: myTop, fromPiece: fromPiece);
  if (page == null) {
    if (!fromPiece) await openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(piece));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// The page [openAuctionOutcome] shows for [piece] after a [type] notification, or null for
/// the piece itself. Goes by the piece's current state first: the notification may be stale.
@visibleForTesting
Widget? auctionOutcomePage(
  PieceSummary piece, {
  required String type,
  int? myTopBidCents,
  bool fromPiece = false,
}) {
  final auction = piece.auction;
  // Bought: the auction summary is gone and the piece carries the order (7b).
  if (piece.status == 'sold' || piece.viewerOrder != null) return null;
  if (auction != null && auction.secondChanceOffer != null) {
    return SecondChancePage(piece: piece, auction: auction, fromPiece: fromPiece);
  }
  if (auction != null && auction.isWinner && auction.awaitingPayment) {
    return BidPaymentFailedPage(piece: piece, auction: auction, fromPiece: fromPiece);
  }
  if (auction != null && auction.isWinner && auction.isSettling) {
    return AuctionResultPage.won(piece: piece, auction: auction);
  }
  // Won, with nothing left to settle here: the piece.
  if (auction == null && piece.myBidStatus == 'won') return null;
  if (type == 'auction_no_sale') {
    return AuctionResultPage.reserveNotMet(piece: piece, auction: auction, myTopBidCents: myTopBidCents);
  }
  // An offer that is no longer there (taken, declined or expired): the piece.
  if (type == 'auction_second_chance') return null;
  return AuctionResultPage.lost(piece: piece, auction: auction, myTopBidCents: myTopBidCents);
}

/// After a payment went through on [pieceId] (a fixed card, an accepted offer): reads the piece
/// again and replaces the current page with what it now shows, so a stale summary is never
/// used. Without anything to show it returns to the piece.
Future<void> _showSettled(
  BuildContext context, {
  required String pieceId,
  required String type,
  required bool fromPiece,
  Future<PieceSummary> Function()? reload,
}) async {
  PieceSummary? piece;
  try {
    piece = await (reload ?? () => PieceService.instance.getById(pieceId))();
  } catch (_) {}
  if (!context.mounted) return;
  final page = piece == null ? null : auctionOutcomePage(piece, type: type, fromPiece: fromPiece);
  final nav = Navigator.of(context);
  if (page != null) {
    nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  } else if (fromPiece || piece == null) {
    nav.maybePop();
  } else {
    nav.pushReplacement(
      SlideUpPageRoute<void>(page: pieceDetailPageFor(FeedPreviewItem.fromPieceSummary(piece))),
    );
  }
}

enum AuctionOutcome { won, lost, reserveNotMet }

/// `BidWon`, `BidLost`, `BidReserveNotMet`: the piece full-bleed 520 tall (muted when it
/// ended for them) under a soft dark top with a white Close; a Mono label; the 24/500
/// title; a 15 Graphite line; a Line; two amounts; then the actions pinned at the bottom.
/// No iridescence: payment could still fail (`NoteBidWon`).
class AuctionResultPage extends StatelessWidget {
  const AuctionResultPage._({
    required this.outcome,
    required this.piece,
    this.auction,
    this.myTopBidCents,
    this.now,
  });

  factory AuctionResultPage.won({
    required PieceSummary piece,
    required AuctionSummary auction,
    DateTime? now,
  }) => AuctionResultPage._(outcome: AuctionOutcome.won, piece: piece, auction: auction, now: now);

  factory AuctionResultPage.lost({
    required PieceSummary piece,
    AuctionSummary? auction,
    int? myTopBidCents,
  }) => AuctionResultPage._(
    outcome: AuctionOutcome.lost,
    piece: piece,
    auction: auction,
    myTopBidCents: myTopBidCents,
  );

  factory AuctionResultPage.reserveNotMet({
    required PieceSummary piece,
    AuctionSummary? auction,
    int? myTopBidCents,
  }) => AuctionResultPage._(
    outcome: AuctionOutcome.reserveNotMet,
    piece: piece,
    auction: auction,
    myTopBidCents: myTopBidCents,
  );

  final AuctionOutcome outcome;
  final PieceSummary piece;
  final AuctionSummary? auction;
  final int? myTopBidCents;

  @visibleForTesting
  final DateTime? now;

  String get _artist {
    final name = piece.authorName?.trim() ?? '';
    return name.isNotEmpty ? name : (piece.authorUsername ?? 'the artist');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final a = auction;
    final at = now ?? DateTime.now();
    final muted = outcome != AuctionOutcome.won;
    // 7b: shipping is charged without a checkout once Convelio's price arrives.
    final shippingPending = a?.autoCheckout?.isPendingQuote == true;
    final (label, title, line) = switch (outcome) {
      AuctionOutcome.won => (
        'Auction won',
        '${piece.title} is yours',
        shippingPending
            ? "By $_artist. We'll charge shipping, insurance and tax to the same card and book "
                  'the courier. Nothing more to do.'
            : 'By $_artist. Confirm shipping and pay to bring it home.',
      ),
      AuctionOutcome.lost => (
        'Auction ended',
        '${piece.title} went to another collector',
        'Thanks for bidding. Nothing was charged.',
      ),
      AuctionOutcome.reserveNotMet => (
        'Auction closed',
        'Closed without selling',
        "Bids didn't reach the artist's minimum. Nothing was charged.",
      ),
    };
    final topCents = a?.winningBidCents ?? a?.highestBidCents;
    final leftLabel = switch (outcome) {
      AuctionOutcome.won => 'Winning bid',
      AuctionOutcome.lost => 'Final bid',
      AuctionOutcome.reserveNotMet => 'Top bid',
    };
    final deadline = a?.winnerDeadlineAt;
    final firstName = _artist.split(' ').first;
    final image = piece.mediaUrl;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    Widget amount(String label, String value, {bool end = false, bool mono = false}) => Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: StudioType.caption12(color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: mono
              ? StudioType.mono(18, color: c.textPrimary)
              : StudioType.sans(20, color: c.textPrimary),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 520,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: muted
                      ? const ColorFilter.matrix([
                          0.55, 0.3, 0.1, 0, 30, //
                          0.2, 0.65, 0.1, 0, 30,
                          0.2, 0.3, 0.45, 0, 30,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: image == null || image.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0, -0.58),
                      colors: [Color(0x61111111), Color(0x00111111)],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 6, 0),
                      child: StudioTopIcon(
                        icon: StudioIcons.close,
                        size: 22,
                        semanticLabel: 'Close',
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: StudioType.mono(11, color: c.textSecondary).copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: StudioType.sans(
                      24,
                      weight: StudioType.medium,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(line, style: StudioType.body15(color: c.textSecondary)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (topCents != null) amount(leftLabel, formatUsd(topCents)),
                        const Spacer(),
                        if (outcome == AuctionOutcome.won && deadline != null)
                          amount('Time to pay', auctionCountdown(deadline, at), end: true, mono: true)
                        else if (outcome != AuctionOutcome.won && myTopBidCents != null)
                          amount('Your top bid', formatUsd(myTopBidCents!), end: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, bottom > 30 ? bottom : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (outcome) {
                AuctionOutcome.won => [
                  StudioButton(
                    label: shippingPending ? 'Shipping price on its way' : 'Finish checkout',
                    height: StudioSize.buttonPrimaryTall,
                    onPressed: shippingPending
                        ? null
                        : () => CollectPieceSheet.show(
                            context,
                            item: FeedPreviewItem.fromPieceSummary(piece),
                            auction: a,
                          ),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Pay by '),
                          TextSpan(
                            text: auctionDateTime(deadline),
                            style: StudioType.mono(12, color: c.textSecondary),
                          ),
                          const TextSpan(text: ' to keep it.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: StudioType.caption12(color: c.textSecondary),
                    ),
                  ],
                ],
                AuctionOutcome.lost => [
                  StudioButton(
                    label: 'See more from $firstName',
                    height: StudioSize.buttonPrimaryTall,
                    onPressed: () => openUserProfile(context, piece.authorUsername),
                  ),
                  const SizedBox(height: 4),
                  _BackToExplore(),
                ],
                AuctionOutcome.reserveNotMet => [
                  StudioButton(
                    label: 'Save to hear if it comes back',
                    height: StudioSize.buttonPrimaryTall,
                    onPressed: piece.isSaved ? null : () => _save(context),
                  ),
                  const SizedBox(height: 4),
                  _BackToExplore(),
                ],
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    try {
      await SocialService.instance.savePiece(piece.id);
      SavedContentStore.instance.savePreview(FeedPreviewItem.fromPieceSummary(piece));
      if (context.mounted) {
        showSavedBar(
          context,
          entryId: piece.id,
          targetType: 'piece',
          title: piece.title,
          thumbnailUrl: piece.mediaUrl,
          message: "Saved. You'll hear if it comes back.",
        );
      }
    } catch (_) {
      if (context.mounted) showStudioToast(context, 'Could not save it. Try again.', icon: null);
    }
  }
}

class _BackToExplore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          if (!MainNavService.instance.goExplore()) Navigator.maybePop(context);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: StudioSize.tapTarget,
          child: Center(
            child: Text(
              'Back to Explore',
              style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Your card didn't go through" (`BidPaymentFailed`): the 48 ring with "!" and the 28/500
/// title in red (#B3261E), "[Title] is still yours…", Time left in Mono 22 (ticking each
/// minute), "We'll try again at …" (the server's next automatic retry), "[Card] · declined" in
/// Mono 11; Use another card (a new card, then the server tries again) and "Try the same card
/// again". Once it goes through, the piece is read again and shown as it now is.
class BidPaymentFailedPage extends StatefulWidget {
  const BidPaymentFailedPage({
    super.key,
    required this.piece,
    this.auction,
    this.fromPiece = false,
    this.debugCard,
    this.retry,
    this.newCard,
    this.reload,
  });

  final PieceSummary piece;
  final AuctionSummary? auction;

  /// Opened from the piece page: when done, back to it.
  final bool fromPiece;

  /// For tests: the saved card, the retry, adding a card and re-reading the piece.
  @visibleForTesting
  final SavedCard? debugCard;
  @visibleForTesting
  final Future<void> Function(String paymentMethodId)? retry;
  @visibleForTesting
  final Future<String?> Function()? newCard;
  @visibleForTesting
  final Future<PieceSummary> Function()? reload;

  @override
  State<BidPaymentFailedPage> createState() => _BidPaymentFailedPageState();
}

class _BidPaymentFailedPageState extends State<BidPaymentFailedPage> {
  late SavedCard? _card = widget.debugCard;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (_card == null) {
      BidService.instance.cards().then((cards) {
        if (mounted && cards.isNotEmpty) setState(() => _card = cards.first);
      }, onError: (Object _) {});
    }
    // The countdown moves on its own.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _retryWith(String? paymentMethodId) async {
    if (paymentMethodId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await (widget.retry ??
          (id) => BidService.instance.retryPayment(widget.piece.id, paymentMethodId: id))(
        paymentMethodId,
      );
      if (!mounted) return;
      showStudioToast(context, 'Payment went through');
      await _showSettled(
        context,
        pieceId: widget.piece.id,
        type: 'auction_payment_fixed',
        fromPiece: widget.fromPiece,
        reload: widget.reload,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'That card was declined too.', icon: null);
    }
  }

  Future<void> _updateCard() async {
    final id = await (widget.newCard ??
        () async => (await BidVerifySheet.show(context, shipTo: false))?.paymentMethodId)();
    if (!mounted || id == null) return;
    await _retryWith(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final now = DateTime.now();
    final deadline = widget.auction?.winnerDeadlineAt;
    final retryAt = widget.auction?.paymentRetryAt;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 150, 32, 24),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.alert, width: 1.5),
                    ),
                    child: Text(
                      '!',
                      style: StudioType.sans(22, weight: StudioType.medium, color: c.alert),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Your card didn't go through",
                    textAlign: TextAlign.center,
                    style: StudioType.sans(
                      28,
                      weight: StudioType.medium,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: c.alert,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Still yours. Update your card in time or it goes to the next bidder.',
                    textAlign: TextAlign.center,
                    style: StudioType.body15(height: 1.5, color: c.textSecondary),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: 24),
                    Text('Time left', style: StudioType.caption12(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      auctionCountdown(deadline, now),
                      style: StudioType.mono(22, color: c.textPrimary),
                    ),
                  ],
                  if (retryAt != null && retryAt.isAfter(now)) ...[
                    const SizedBox(height: 8),
                    Text(
                      "We'll try again at ${winnerDeadlinePhrase(retryAt, now)}",
                      textAlign: TextAlign.center,
                      style: StudioType.caption12(color: c.textSecondary),
                    ),
                  ],
                  if (_card != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${_card!.label} · declined',
                      style: StudioType.mono(11, color: c.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, bottom > 32 ? bottom : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioButton(
                  label: 'Use another card',
                  height: StudioSize.buttonPrimaryTall,
                  loading: _busy,
                  onPressed: _busy ? null : _updateCard,
                ),
                const SizedBox(height: 4),
                _TextLink(
                  label: 'Try the same card again',
                  onTap: _busy || _card == null ? null : () => _retryWith(_card!.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 44 tall centred 14/500 Graphite text action under the main button.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: StudioSize.tapTarget,
          child: Center(
            child: Text(
              label,
              style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Second chance (`NoteBidSecondChance`, FRONTEND_HANDOFF 7a.4), laid out as
/// `BidPaymentFailed`: the winner didn't pay, so the piece is offered to this bidder at their
/// top bid until the offer ends. "Accept and pay" charges their saved card at once; a decline
/// (402) shows why, with "Use another card"; "No thanks" passes it to the next bidder.
class SecondChancePage extends StatefulWidget {
  const SecondChancePage({
    super.key,
    required this.piece,
    required this.auction,
    this.fromPiece = false,
    this.accept,
    this.decline,
    this.newCard,
    this.reload,
  });

  final PieceSummary piece;
  final AuctionSummary auction;

  /// Opened from the piece page: when done, back to it.
  final bool fromPiece;

  /// For tests: accepting (with a new card's id, or null for the saved card), declining,
  /// adding a card and re-reading the piece.
  @visibleForTesting
  final Future<void> Function(String? paymentMethodId)? accept;
  @visibleForTesting
  final Future<void> Function()? decline;
  @visibleForTesting
  final Future<String?> Function()? newCard;
  @visibleForTesting
  final Future<PieceSummary> Function()? reload;

  @override
  State<SecondChancePage> createState() => _SecondChancePageState();
}

class _SecondChancePageState extends State<SecondChancePage> {
  bool _busy = false;
  Timer? _tick;

  /// Why the last try was declined: this session's 402, else the server's `lastError`.
  late String? _error = widget.auction.secondChanceOffer?.lastError;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _settled() => _showSettled(
    context,
    pieceId: widget.piece.id,
    type: 'auction_second_chance',
    fromPiece: widget.fromPiece,
    reload: widget.reload,
  );

  Future<void> _accept([String? paymentMethodId]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (widget.accept ??
          (id) => BidService.instance.acceptOffer(widget.piece.id, paymentMethodId: id))(
        paymentMethodId,
      );
      if (!mounted) return;
      showStudioToast(context, 'Payment went through');
      await _settled();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        setState(() {
          _busy = false;
          _error = e.message.isNotEmpty ? e.message : "That card didn't go through.";
        });
        return;
      }
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
      // No offer any more (404) or it ran out (409): show the piece as it now is.
      if (e.statusCode == 404 || e.statusCode == 409) await _settled();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, "That didn't go through. Try again.", icon: null);
    }
  }

  Future<void> _useAnotherCard() async {
    final id = await (widget.newCard ??
        () async => (await BidVerifySheet.show(context, shipTo: false))?.paymentMethodId)();
    if (!mounted || id == null) return;
    await _accept(id);
  }

  Future<void> _decline() async {
    if (_busy) return;
    final confirmed = await showStudioConfirm(
      context,
      title: 'Pass on this piece?',
      message: 'The offer goes to the next bidder. Nothing is charged.',
      confirmLabel: 'No thanks',
      cancelLabel: 'Keep the offer',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await (widget.decline ?? () => BidService.instance.declineOffer(widget.piece.id))();
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Offer declined');
      Navigator.maybePop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
      if (e.statusCode == 404 || e.statusCode == 409) await _settled();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, "That didn't go through. Try again.", icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final offer = widget.auction.secondChanceOffer;
    final expires = offer?.expiresAt;
    final error = _error;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 150, 32, 24),
              child: Column(
                children: [
                  Text(
                    'SECOND CHANCE',
                    style: StudioType.mono(11, color: c.textSecondary).copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.piece.title} can still be yours',
                    textAlign: TextAlign.center,
                    style: StudioType.sans(
                      28,
                      weight: StudioType.medium,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "The winning bidder didn't pay, so it's offered to you at your top bid. "
                    'Nothing is charged unless you accept.',
                    textAlign: TextAlign.center,
                    style: StudioType.body15(height: 1.5, color: c.textSecondary),
                  ),
                  if (offer != null) ...[
                    const SizedBox(height: 24),
                    Text('Your top bid', style: StudioType.caption12(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      formatUsd(offer.amountCents),
                      style: StudioType.mono(22, color: c.textPrimary),
                    ),
                  ],
                  if (expires != null) ...[
                    const SizedBox(height: 14),
                    Text('Offer ends in', style: StudioType.caption12(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      auctionCountdown(expires, DateTime.now()),
                      style: StudioType.mono(22, color: c.textPrimary),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: StudioType.body14(color: c.alert),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, bottom > 32 ? bottom : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioButton(
                  label: error != null ? 'Use another card' : 'Accept and pay',
                  height: StudioSize.buttonPrimaryTall,
                  loading: _busy,
                  onPressed: _busy ? null : (error != null ? _useAnotherCard : _accept),
                ),
                const SizedBox(height: 4),
                _TextLink(label: 'No thanks', onTap: _busy ? null : _decline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

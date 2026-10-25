import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/auction.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/bid_service.dart';
import '../services/main_nav_service.dart';
import '../services/piece_service.dart';
import '../services/social_service.dart';
import '../utils/profile_navigation.dart';
import '../utils/require_login.dart';
import '../widgets/auction/auction_widgets.dart';
import '../widgets/create_flow/post_availability_step.dart' show formatUsd;
import '../widgets/piece_detail/collect_piece_sheet.dart';
import '../widgets/studio/studio.dart';

/// Place a bid from the piece page (Flow 7): sign in, add a card the first time
/// (`BidVerify`), then the bid sheet (`BidSheet`). Returns the auction after the bid.
Future<AuctionSummary?> startBidding(
  BuildContext context, {
  required String pieceId,
  required AuctionSummary auction,
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
  if (card == null) {
    final id = await BidVerifySheet.show(context);
    if (id == null || !context.mounted) return null;
    try {
      final cards = await BidService.instance.cards();
      card = cards.firstWhere((c) => c.id == id, orElse: () => SavedCard(id: id, brand: '', last4: ''));
    } catch (_) {
      card = SavedCard(id: id, brand: '', last4: '');
    }
    if (!context.mounted) return null;
  }
  final after = await BidSheet.show(
    context,
    pieceId: pieceId,
    auction: auction,
    card: card,
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
/// (`BidPaymentFailed`), the loss (`BidLost`) or the no-sale (`BidReserveNotMet`).
Future<void> openAuctionOutcome(
  BuildContext context, {
  required String pieceId,
  required String type,
}) async {
  PieceSummary piece;
  try {
    piece = await PieceService.instance.getById(pieceId);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not load the piece', icon: null);
    return;
  }
  if (!context.mounted) return;
  final myTop = await BidStore.instance.topBid(pieceId);
  if (!context.mounted) return;
  final auction = piece.auction;
  final Widget page;
  if (type == 'auction_payment_failed' || (auction?.isWinner == true && auction!.awaitingPayment)) {
    page = BidPaymentFailedPage(piece: piece, auction: auction);
  } else if (type == 'auction_won' && auction != null && auction.isWinner) {
    page = AuctionResultPage.won(piece: piece, auction: auction);
  } else if (type == 'auction_no_sale') {
    page = AuctionResultPage.reserveNotMet(piece: piece, auction: auction, myTopBidCents: myTop);
  } else {
    page = AuctionResultPage.lost(piece: piece, auction: auction, myTopBidCents: myTop);
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
    final (label, title, line) = switch (outcome) {
      AuctionOutcome.won => (
        'Auction won',
        '${piece.title} is yours',
        'By $_artist. Confirm shipping and pay to bring it home.',
      ),
      AuctionOutcome.lost => (
        'Auction ended',
        '${piece.title} went to another collector',
        'Thanks for bidding. Nothing was charged.',
      ),
      AuctionOutcome.reserveNotMet => (
        'Auction closed',
        'Closed without selling',
        "Bids didn't reach the artist's minimum, so it wasn't sold and nothing was charged.",
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
                    label: 'Finish checkout',
                    height: StudioSize.buttonPrimaryTall,
                    onPressed: () => CollectPieceSheet.show(
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
      if (context.mounted) showStudioToast(context, "Saved. You'll hear if it comes back.");
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

/// "Your card didn't go through" (`BidPaymentFailed`): the 48 ring with "!", the 28/500
/// title, "[Title] is still yours…", Time left in Mono 22, "[Card] · declined" in Mono 11;
/// Update card (a new card, then the server tries again) and "Try the same card again".
class BidPaymentFailedPage extends StatefulWidget {
  const BidPaymentFailedPage({
    super.key,
    required this.piece,
    this.auction,
    this.debugCard,
    this.retry,
    this.newCard,
  });

  final PieceSummary piece;
  final AuctionSummary? auction;

  /// For tests: the saved card, the retry and adding a card.
  @visibleForTesting
  final SavedCard? debugCard;
  @visibleForTesting
  final Future<void> Function(String paymentMethodId)? retry;
  @visibleForTesting
  final Future<String?> Function()? newCard;

  @override
  State<BidPaymentFailedPage> createState() => _BidPaymentFailedPageState();
}

class _BidPaymentFailedPageState extends State<BidPaymentFailedPage> {
  late SavedCard? _card = widget.debugCard;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_card == null) {
      BidService.instance.cards().then((cards) {
        if (mounted && cards.isNotEmpty) setState(() => _card = cards.first);
      }, onError: (Object _) {});
    }
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
      final auction = widget.auction;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => auction == null
              ? AuctionResultPage.lost(piece: widget.piece)
              : AuctionResultPage.won(piece: widget.piece, auction: auction),
        ),
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
    final id = await (widget.newCard ?? () => BidVerifySheet.show(context))();
    if (!mounted || id == null) return;
    await _retryWith(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final deadline = widget.auction?.winnerDeadlineAt;
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
                      border: Border.all(color: c.textPrimary, width: 1.5),
                    ),
                    child: Text(
                      '!',
                      style: StudioType.sans(22, weight: StudioType.medium, color: c.textPrimary),
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
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.piece.title} is still yours. Update your card to finish paying.',
                    textAlign: TextAlign.center,
                    style: StudioType.body15(height: 1.5, color: c.textSecondary),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: 24),
                    Text('Time left', style: StudioType.caption12(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      auctionCountdown(deadline, DateTime.now()),
                      style: StudioType.mono(22, color: c.textPrimary),
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
                  label: 'Update card',
                  height: StudioSize.buttonPrimaryTall,
                  loading: _busy,
                  onPressed: _busy ? null : _updateCard,
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: _busy || _card == null ? null : () => _retryWith(_card!.id),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: StudioSize.tapTarget,
                      child: Center(
                        child: Text(
                          'Try the same card again',
                          style: StudioType.body14(
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
        ],
      ),
    );
  }
}

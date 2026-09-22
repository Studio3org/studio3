import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/feed_preview_item.dart';
import '../../models/saved_card.dart';
import '../../services/api_exception.dart';
import '../../services/bid_service.dart';
import '../../services/piece_service.dart';
import '../../services/saved_card_service.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../utils/auction_time.dart';
import '../home_feed/home_feed_widgets.dart';
import 'bid_card_picker_sheet.dart';
import 'place_bid_confirmation_sheet.dart';

/// Bid-amount sheet — Figma "Piece detail - bid" (2707:3664) flow, screens 1-2.
class PlaceBidSheet extends StatefulWidget {
  const PlaceBidSheet({super.key, required this.item});

  final FeedPreviewItem item;

  /// Resolves to `true` when a bid was actually placed, so the caller can refresh the
  /// piece it is showing behind the sheet.
  static Future<bool> show(BuildContext context, {required FeedPreviewItem item}) async {
    final placed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => PlaceBidSheet(item: item),
    );
    return placed ?? false;
  }

  @override
  State<PlaceBidSheet> createState() => _PlaceBidSheetState();
}

class _PlaceBidSheetState extends State<PlaceBidSheet> {
  late FeedPreviewItem _item;
  late final TextEditingController _amountController;
  bool _submitting = false;

  /// The card this bid will be authorised against.
  ///
  /// Required before the first bid on a piece, because a bid places a hold immediately and
  /// the same card is re-authorised weeks later with nobody present — there is no later
  /// point at which one could be collected. Loaded on open so a returning bidder sees their
  /// card already chosen rather than being asked again.
  SavedCard? _card;
  bool _loadingCards = true;

  /// Why the last attempt failed, shown inside the sheet rather than as a snackbar.
  ///
  /// A snackbar raised from here renders in the Scaffold *behind* this modal route, so a
  /// declined card or a rejected bid looked to the bidder like the button simply spun and
  /// then did nothing — the one case where silence is worst, because the money question is
  /// exactly what they are waiting on an answer to.
  String? _error;

  /// The server decides this. The increment is banded by price ($5 under $100 rising to
  /// $500 over $10,000) and the first bid on a piece may land exactly on the artist's
  /// starting bid, so there is no formula the client can safely reproduce. The fallback is
  /// the starting bid itself — the lowest value that is ever valid — not a guessed step.
  int get _minNextBidCents =>
      _item.minNextBidCents ??
      _item.startingBidCents ??
      _item.highestBidCents ??
      _item.priceCents ??
      0;

  /// Explains the minimum in the bidder's own terms: on an untouched auction it is the
  /// artist's asking minimum; once someone has bid it is a step above them.
  String get _minimumHint {
    final minimum = _formatDollars(_minNextBidCents);
    if ((_item.bidCount) == 0) {
      return 'The artist\'s minimum bid is $minimum';
    }
    final increment = _item.bidIncrementCents;
    if (increment == null || increment <= 0) {
      return 'Next bid must be at least $minimum';
    }
    return 'Bid at least $minimum — ${_formatDollars(increment)} above the current highest';
  }

  static String _formatDollars(int cents) {
    final dollars = cents / 100;
    final text = dollars == dollars.roundToDouble()
        ? dollars.toStringAsFixed(0)
        : dollars.toStringAsFixed(2);
    return '\$$text';
  }

  String get _imageUrl {
    final url = _item.heroImageUrl;
    if (url != null && url.isNotEmpty) return url;
    return feedPreviewImageUrl(_item);
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _amountController = TextEditingController(
      text: (_minNextBidCents / 100).toStringAsFixed(0),
    );
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await SavedCardService.instance.list();
      if (!mounted) return;
      setState(() {
        // First usable card wins. An expired one would only produce a decline the bidder
        // cannot act on from here.
        _card = cards.where((c) => !c.isExpired).firstOrNull;
        _loadingCards = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Not fatal: they can still open the picker and add one.
      setState(() => _loadingCards = false);
    }
  }

  Future<void> _chooseCard() async {
    final picked = await BidCardPickerSheet.show(context, selectedId: _card?.id);
    if (!mounted || picked == null) return;
    setState(() => _card = picked);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _enteredAmountCents {
    final dollars = int.tryParse(_amountController.text.trim());
    if (dollars == null) return null;
    return dollars * 100;
  }

  bool get _canSubmit {
    final amount = _enteredAmountCents;
    return !_submitting &&
        !_loadingCards &&
        _card != null &&
        amount != null &&
        amount >= _minNextBidCents;
  }

  Future<void> _refreshMinimum() async {
    try {
      final piece = await PieceService.instance.getById(_item.id);
      if (!mounted) return;
      setState(() {
        _item = _item.copyWith(
          highestBidCents: piece.highestBidCents,
          startingBidCents: piece.startingBidCents,
          bidIncrementCents: piece.bidIncrementCents,
          bidCount: piece.bidCount,
          minNextBidCents: piece.minNextBidCents,
          auctionEndsAt: piece.auctionEndsAt,
        );
        _amountController.text = (_minNextBidCents / 100).toStringAsFixed(0);
      });
    } catch (_) {
      // Best-effort refresh — the user can still retry with the stale minimum.
    }
  }

  Future<void> _onPlaceBid() async {
    final amount = _enteredAmountCents;
    if (amount == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final bid = await BidService.instance.placeBid(
        _item.id,
        amount,
        paymentMethodId: _card?.id,
      );
      if (!mounted) return;
      // The confirmation is opened from the navigator rather than from this sheet's own
      // context: by the time it runs this element is being torn down by the pop above, and
      // a defunct context finds no navigator to push onto — which is why the success path
      // showed nothing either.
      final navigator = Navigator.of(context);
      navigator.pop(true);
      await PlaceBidConfirmationSheet.show(navigator.context, bid: bid);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      await _refreshMinimum();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not place your bid. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final timeRemaining = formatTimeRemaining(_item.auctionEndsAt);

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
                    _PieceSummaryCard(
                      imageUrl: _imageUrl,
                      title: _item.title,
                      artistName: _item.displayName,
                      bidCount: _item.bidCount,
                      bidDisplay: formatCollectPrice(
                        _item.highestBidCents ?? _item.priceCents,
                      ),
                      timeRemaining: timeRemaining,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Bid amount',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CollectDetailTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _error = null),
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: CollectDetailTokens.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _minimumHint,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CollectDetailTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _CardRow(
                      label: _loadingCards
                          ? 'Checking your cards…'
                          : (_card?.label ?? 'Add a card to bid'),
                      hasCard: _card != null,
                      loading: _loadingCards,
                      onTap: _loadingCards ? null : _chooseCard,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // Said plainly, because it is the single most misunderstood thing
                      // about bidding: the money is reserved, not taken, and it is only
                      // taken if they win.
                      'We place a hold for your bid amount. Nothing is charged unless you '
                      'win — shipping and tax are added afterwards.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: CollectDetailTokens.textSecondary,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 28),
                    _PlaceBidCta(
                      loading: _submitting,
                      onTap: _canSubmit ? _onPlaceBid : null,
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
              'Place a bid',
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

class _PieceSummaryCard extends StatelessWidget {
  const _PieceSummaryCard({
    required this.imageUrl,
    required this.title,
    required this.artistName,
    required this.bidCount,
    required this.bidDisplay,
    this.timeRemaining,
  });

  final String imageUrl;
  final String title;
  final String artistName;
  final int bidCount;
  final String bidDisplay;
  final String? timeRemaining;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: FeedPicsumImage(url: imageUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artistName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CollectDetailTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: CollectDetailTokens.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bidCount > 0 ? 'Current bid · $bidCount bids' : 'Starting bid',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CollectDetailTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bidDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (timeRemaining != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Time remaining',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CollectDetailTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeRemaining!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: CollectDetailTokens.statusError,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceBidCta extends StatelessWidget {
  const _PlaceBidCta({required this.onTap, this.loading = false});

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
        borderRadius: BorderRadius.circular(CollectDetailTokens.collectButtonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CollectDetailTokens.collectButtonRadius),
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
                    'Place bid',
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


class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.label,
    required this.hasCard,
    required this.loading,
    this.onTap,
  });

  final String label;
  final bool hasCard;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CollectDetailTokens.sheetCardFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.credit_card,
                size: 20,
                color: CollectDetailTokens.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: hasCard
                        ? CollectDetailTokens.textPrimary
                        : CollectDetailTokens.textSecondary,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  hasCard ? 'Change' : 'Add',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reason a bid did not go through, shown where the bidder is already looking.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CollectDetailTokens.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CollectDetailTokens.statusError.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: CollectDetailTokens.statusError,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: CollectDetailTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

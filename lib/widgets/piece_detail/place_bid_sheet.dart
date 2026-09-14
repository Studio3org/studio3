import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/feed_preview_item.dart';
import '../../services/api_exception.dart';
import '../../services/bid_service.dart';
import '../../services/piece_service.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../utils/auction_time.dart';
import '../home_feed/home_feed_widgets.dart';
import 'place_bid_confirmation_sheet.dart';

/// Bid-amount sheet — Figma "Piece detail - bid" (2707:3664) flow, screens 1-2.
class PlaceBidSheet extends StatefulWidget {
  const PlaceBidSheet({super.key, required this.item});

  final FeedPreviewItem item;

  static Future<void> show(BuildContext context, {required FeedPreviewItem item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => PlaceBidSheet(item: item),
    );
  }

  @override
  State<PlaceBidSheet> createState() => _PlaceBidSheetState();
}

class _PlaceBidSheetState extends State<PlaceBidSheet> {
  late FeedPreviewItem _item;
  late final TextEditingController _amountController;
  bool _submitting = false;

  int get _minNextBidCents =>
      _item.minNextBidCents ?? ((_item.highestBidCents ?? _item.priceCents ?? 0) + 2500);

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
    return !_submitting && amount != null && amount >= _minNextBidCents;
  }

  Future<void> _refreshMinimum() async {
    try {
      final piece = await PieceService.instance.getById(_item.id);
      if (!mounted) return;
      setState(() {
        _item = _item.copyWith(
          highestBidCents: piece.highestBidCents,
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
    setState(() => _submitting = true);
    try {
      final bid = await BidService.instance.placeBid(_item.id, amount);
      if (!mounted) return;
      Navigator.pop(context);
      await PlaceBidConfirmationSheet.show(context, bid: bid);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      await _refreshMinimum();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not place your bid. Please try again.')),
      );
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
                      onChanged: (_) => setState(() {}),
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
                      'Minimum bid is \$25 above the current highest',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CollectDetailTokens.textSecondary,
                      ),
                    ),
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

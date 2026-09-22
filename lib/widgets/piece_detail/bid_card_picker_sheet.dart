import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/saved_card.dart';
import '../../services/api_exception.dart';
import '../../services/saved_card_service.dart';
import '../../theme/collect_detail_tokens.dart';
import '../loading/app_skeletons.dart';

/// Choosing which card a bid is authorised against.
///
/// Bidding needs a card *before* the bid, which is the thing that makes this different from
/// checkout. A bid places a hold immediately and the same card is re-authorised weeks later
/// with nobody present, so there is no later moment at which one could be asked for.
///
/// Expired cards are shown but not selectable. Hiding them would leave a collector wondering
/// where their card went; letting them pick one would produce a decline they cannot explain.
class BidCardPickerSheet extends StatefulWidget {
  const BidCardPickerSheet({super.key, this.selectedId});

  final String? selectedId;

  /// Returns the chosen card, or null if the collector backed out.
  static Future<SavedCard?> show(BuildContext context, {String? selectedId}) {
    return showModalBottomSheet<SavedCard>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => BidCardPickerSheet(selectedId: selectedId),
    );
  }

  @override
  State<BidCardPickerSheet> createState() => _BidCardPickerSheetState();
}

class _BidCardPickerSheetState extends State<BidCardPickerSheet> {
  List<SavedCard> _cards = const [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await SavedCardService.instance.list();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _error = null;
      });
      // Nothing saved yet, so go straight to adding one rather than showing an empty list
      // with a single button on it.
      if (cards.isEmpty) await _addCard();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your cards. Please try again.';
      });
    }
  }

  Future<void> _addCard() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final card = await SavedCardService.instance.addCard();
      if (!mounted) return;
      setState(() => _adding = false);
      // Null means they closed Stripe's sheet, which is not an error.
      if (card == null) return;
      Navigator.pop(context, card);
    } on CardSaveUnavailable catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = e.message;
      });
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = e.error.localizedMessage ?? 'That card could not be saved.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = 'That card could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Material(
          color: CollectDetailTokens.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                title: 'Card for bidding',
                onClose: () => Navigator.pop(context),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                  children: [
                    Text(
                      'Your card is held, not charged. We only take payment if you win.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: CollectDetailTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading && _cards.isEmpty)
                      const OptionListSkeleton(
                        itemCount: 3,
                        padding: EdgeInsets.zero,
                      )
                    else ...[
                      for (final card in _cards)
                        _CardRow(
                          card: card,
                          selected: card.id == widget.selectedId,
                          onTap: card.isExpired
                              ? null
                              : () => Navigator.pop(context, card),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: CollectDetailTokens.statusError,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _AddCardButton(loading: _adding, onTap: _addCard),
                    ],
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

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.selected, this.onTap});

  final SavedCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final expired = card.isExpired;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: CollectDetailTokens.sheetCardFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card,
                  size: 20,
                  color: expired
                      ? CollectDetailTokens.textSecondary
                      : CollectDetailTokens.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: expired
                              ? CollectDetailTokens.textSecondary
                              : CollectDetailTokens.textPrimary,
                        ),
                      ),
                      if (card.expiryLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          expired
                              ? 'Expired ${card.expiryLabel}'
                              : 'Expires ${card.expiryLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: expired
                                ? CollectDetailTokens.statusError
                                : CollectDetailTokens.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: CollectDetailTokens.textPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap, this.loading = false});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CollectDetailTokens.collectButtonHeight,
      width: double.infinity,
      child: Material(
        color: CollectDetailTokens.ctaFill,
        borderRadius: BorderRadius.circular(CollectDetailTokens.collectButtonRadius),
        child: InkWell(
          onTap: loading ? null : onTap,
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
                    'Add a card',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: CollectDetailTokens.textInverse,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
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
              title,
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

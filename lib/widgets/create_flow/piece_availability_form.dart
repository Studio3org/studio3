import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
import '../../theme/app_fonts.dart';

/// Figma 2716:6338 — piece posting Availability tab (not used for scenes).
class PieceAvailabilityForm extends StatelessWidget {
  const PieceAvailabilityForm({
    super.key,
    required this.forSale,
    required this.sellMode,
    required this.auctionDays,
    required this.priceController,
    required this.onForSaleChanged,
    required this.onSellModeChanged,
    required this.onAuctionDaysChanged,
  });

  static const selectedFill = HomeFeedTokens.neutral800; // #352F2A
  static const _divider = Color(0xFFC8C5BC);
  static const minAuctionDays = 3;
  static const maxAuctionDays = 14;

  final bool? forSale;
  final String? sellMode;
  final int auctionDays;
  final TextEditingController priceController;
  final ValueChanged<bool> onForSaleChanged;
  final ValueChanged<String> onSellModeChanged;
  final ValueChanged<int> onAuctionDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Is this piece for sale? ',
                style: kProfileGeist(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Yes',
                      selected: forSale == true,
                      onTap: () => onForSaleChanged(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceButton(
                      label: 'No',
                      selected: forSale == false,
                      onTap: () => onForSaleChanged(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (forSale == true) ...[
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How should it sell? ',
                  style: kProfileGeist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _SellModeCard(
                  title: 'Fixed price',
                  subtitle: 'One price, first to buy',
                  selected: sellMode == 'fixed',
                  onTap: () => onSellModeChanged('fixed'),
                ),
                const SizedBox(height: 16),
                _SellModeCard(
                  title: 'Auction',
                  subtitle: '3 - 14 days, highest bid wins',
                  selected: sellMode == 'auction',
                  onTap: () => onSellModeChanged('auction'),
                ),
              ],
            ),
          ),
          if (sellMode == 'fixed')
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price',
                    style: kProfileGeist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PriceField(controller: priceController),
                ],
              ),
            ),
          if (sellMode == 'auction')
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting bid',
                    style: kProfileGeist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PriceField(controller: priceController),
                  const SizedBox(height: 16),
                  Text(
                    'Duration',
                    style: kProfileGeist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DurationStepper(
                    days: auctionDays,
                    onChanged: onAuctionDaysChanged,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider, width: 0.5)),
      ),
      child: child,
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? PieceAvailabilityForm.selectedFill : null,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(color: HomeFeedTokens.textPrimary),
        ),
        child: Text(
          label,
          style: kProfileGeist(
            fontSize: 16,
            color: selected
                ? HomeFeedTokens.textInverse
                : HomeFeedTokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SellModeCard extends StatelessWidget {
  const _SellModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? PieceAvailabilityForm.selectedFill : null,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(color: PieceAvailabilityForm.selectedFill),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: kProfileGeist(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: kProfileGeist(
                fontSize: 12,
                color: selected
                    ? HomeFeedTokens.textInverse
                    : HomeFeedTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        cursorColor: HomeFeedTokens.neutral800,
        style: AppFonts.geist(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: HomeFeedTokens.neutral800,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          prefixText: '\$ ',
          prefixStyle: AppFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: HomeFeedTokens.neutral800,
          ),
          hintText: '0',
          hintStyle: AppFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: HomeFeedTokens.neutral800.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = days > PieceAvailabilityForm.minAuctionDays;
    final canInc = days < PieceAvailabilityForm.maxAuctionDays;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: Row(
        children: [
          _stepButton('−', enabled: canDec, onTap: () => onChanged(days - 1)),
          Expanded(
            child: Center(
              child: Text(
                '$days Days',
                style: kProfileGeist(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
          ),
          _stepButton('+', enabled: canInc, onTap: () => onChanged(days + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(
    String label, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 40,
        child: Center(
          child: Text(
            label,
            style: kProfileGeist(
              fontSize: 20,
              color: enabled
                  ? HomeFeedTokens.textPrimary
                  : HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

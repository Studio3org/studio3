import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_profile.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_field.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_progress_segments.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_tooltip.dart';

/// "How do you want to share it?" (`PostAvailFixed`, `PostNFSAvail`): step 1 of 3 of posting
/// a piece. Availability comes first because it decides which details are asked for.
///
/// Back and the progress bar; the "Your piece" card (54 × 72 cover, Mono photo count, Edit
/// back to the cover step); the 30/500 heading; Fixed price / Not for sale option rows (no
/// Auction: out of scope); for a fixed price, the Price underline field and the earnings
/// line from the seller's own commission quote; Continue, off until a price is set.
class PostAvailabilityStep extends StatefulWidget {
  const PostAvailabilityStep({
    super.key,
    required this.cover,
    required this.photoCount,
    required this.forSale,
    required this.onForSaleChanged,
    required this.priceController,
    required this.onBack,
    required this.onEdit,
    required this.onContinue,
    required this.quote,
  });

  /// The cover photo as framed, filling its box.
  final Widget cover;
  final int photoCount;
  final bool forSale;
  final ValueChanged<bool> onForSaleChanged;
  final TextEditingController priceController;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onContinue;

  /// What the seller keeps on a sale of the given cents; null hides the earnings line.
  final Future<CommissionQuote?> Function(int priceCents) quote;

  /// The price in dollars, or null when the field holds no price above zero.
  static double? parsePrice(String text) {
    final value = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    return value != null && value > 0 ? value : null;
  }

  @override
  State<PostAvailabilityStep> createState() => _PostAvailabilityStepState();
}

class _PostAvailabilityStepState extends State<PostAvailabilityStep> {
  CommissionQuote? _quote;
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.priceController.addListener(_onPriceChanged);
    if (widget.forSale) _fetchQuote();
  }

  @override
  void didUpdateWidget(PostAvailabilityStep old) {
    super.didUpdateWidget(old);
    if (old.priceController != widget.priceController) {
      old.priceController.removeListener(_onPriceChanged);
      widget.priceController.addListener(_onPriceChanged);
    }
    if (widget.forSale && !old.forSale) _fetchQuote();
  }

  @override
  void dispose() {
    widget.priceController.removeListener(_onPriceChanged);
    _debounce?.cancel();
    super.dispose();
  }

  int get _priceCents {
    final price = PostAvailabilityStep.parsePrice(widget.priceController.text);
    return price == null ? 0 : (price * 100).round();
  }

  void _onPriceChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    final request = ++_request;
    CommissionQuote? quote;
    try {
      quote = await widget.quote(_priceCents);
    } catch (_) {
      quote = null;
    }
    if (!mounted || request != _request) return;
    setState(() => _quote = quote);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final priced =
        PostAvailabilityStep.parsePrice(widget.priceController.text) != null;
    final canContinue = !widget.forSale || priced;
    final bottom = math.max(36.0, MediaQuery.viewPaddingOf(context).bottom);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onBack,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox.square(
                        dimension: StudioSize.tapTarget,
                        child: Center(
                          child: StudioIcon(
                            StudioIcons.backBold,
                            size: 22,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: StudioProgressSegments(current: 1, total: 3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PieceCard(
                      cover: widget.cover,
                      photoCount: widget.photoCount,
                      onEdit: widget.onEdit,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'How do you want to share it?',
                      style: StudioType.title30(color: c.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This decides what details we ask for next.',
                      style: StudioType.body15(color: c.textSecondary),
                    ),
                    const SizedBox(height: 26),
                    _option(
                      title: 'Fixed price',
                      subtitle: 'One price, first to collect it',
                      selected: widget.forSale,
                      onTap: () => widget.onForSaleChanged(true),
                    ),
                    _option(
                      title: 'Not for sale',
                      subtitle: 'Shows on your profile. You can list it later.',
                      selected: !widget.forSale,
                      onTap: () => widget.onForSaleChanged(false),
                      divider: false,
                    ),
                    if (widget.forSale) ...[
                      const SizedBox(height: 26),
                      StudioUnderlineField(
                        label: 'Price',
                        controller: widget.priceController,
                        hint: r'$0',
                        valueSize: 18,
                        strongUnderline: true,
                        required: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [PriceInputFormatter()],
                      ),
                      if (_quote != null) ...[
                        const SizedBox(height: 12),
                        _EarningsLine(quote: _quote!, priced: priced),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottom),
              child: StudioButton(
                label: 'Continue',
                height: StudioSize.buttonPrimaryTall,
                onPressed: canContinue ? widget.onContinue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool divider = true,
  }) {
    return StudioSelectRow(
      title: title,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
      divider: divider,
      titleSize: 19,
      titleLetterSpacing: -0.2,
      verticalPadding: 16,
      ruleInset: 18,
      subtitleSize: 13,
      subtitleGap: 4,
    );
  }
}

/// 54 × 72 cover (radius 8), "Your piece" 15/500 over the Mono 12 photo count, Edit 14/500.
class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.cover,
    required this.photoCount,
    required this.onEdit,
  });

  final Widget cover;
  final int photoCount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 54, height: 72, child: cover),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your piece',
                style: StudioType.sans(
                  15,
                  weight: StudioType.medium,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$photoCount ${photoCount == 1 ? 'photo' : 'photos'}',
                style: StudioType.mono(12, color: c.textSecondary),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: StudioSize.tapTarget,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: Text(
                    'Edit',
                    style: StudioType.body14(
                      weight: StudioType.medium,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Surface box, radius 12, 12 14 padding, 13 / 1.45 Graphite with the amount 500 Ink and a
/// 24 info button that explains the commission.
class _EarningsLine extends StatelessWidget {
  const _EarningsLine({required this.quote, required this.priced});

  final CommissionQuote quote;
  final bool priced;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.sans(13, height: 1.45, color: c.textBody);
    final rate =
        '${formatPercent(quote.commissionBps)} ${quote.reducedRate ? 'founding artist ' : ''}'
        'commission';
    return StudioTooltip(
      message:
          'The commission comes out of the price you set, never on top of it. '
          'Card processing is included.',
      builder: (context, toggle) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(StudioRadius.button),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible, as the board's span: the info button follows the text.
            Flexible(
              child: Text.rich(
                priced
                    ? TextSpan(
                        children: [
                          const TextSpan(text: "You'll receive "),
                          TextSpan(
                            text: formatUsd(quote.netCents),
                            style: TextStyle(
                              fontWeight: StudioType.medium,
                              color: c.textPrimary,
                            ),
                          ),
                          TextSpan(text: ' after the $rate.'),
                        ],
                      )
                    : TextSpan(
                        text: "You'll receive your price less the $rate.",
                      ),
                style: style,
              ),
            ),
            const SizedBox(width: 8),
            StudioInfoButton(
              onTap: toggle,
              semanticLabel: 'What is the commission?',
            ),
          ],
        ),
      ),
    );
  }
}

/// "$3,060", or "$3,060.50" when there are cents.
String formatUsd(int cents) {
  final dollars = cents ~/ 100;
  final rest = cents % 100;
  final grouped = dollars.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return rest == 0
      ? '\$$grouped'
      : '\$$grouped.${rest.toString().padLeft(2, '0')}';
}

/// 1500 → "15%", 1250 → "12.5%".
String formatPercent(int bps) {
  final value = bps / 100;
  return value == value.roundToDouble() ? '${value.round()}%' : '$value%';
}

/// Keeps a price as "$3,600" (or "$3,600.5", two decimals at most) while it is typed.
class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return const TextEditingValue();
    final dot = raw.indexOf('.');
    String whole = dot < 0 ? raw : raw.substring(0, dot);
    String? fraction = dot < 0
        ? null
        : raw.substring(dot + 1).replaceAll('.', '');
    if (fraction != null && fraction.length > 2) {
      fraction = fraction.substring(0, 2);
    }
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > 9) return oldValue;
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final text =
        '\$${grouped.isEmpty ? '0' : grouped}${fraction == null ? '' : '.$fraction'}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

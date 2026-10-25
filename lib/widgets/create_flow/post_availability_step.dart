import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/auction.dart';
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

/// How a piece is offered (`PostAvailFixed`, `PostAvailAuction`, `PostNFSAvail`).
enum SaleMode { fixed, auction, notForSale }

/// "How do you want to share it?" (`PostAvailFixed`, `PostAvailAuction`, `PostNFSAvail`):
/// step 1 of 3 of posting a piece. Availability comes first because it decides which details
/// are asked for. Also "How do you want to sell it?" when listing a piece later
/// (`ListPricing`: Fixed price or Auction, 2 steps, "List it").
///
/// Back and the progress bar; the piece card (54 × 72 cover, Mono photo count, Edit back to
/// the photos); the 30/500 heading; the option rows; then
/// - fixed price: the Price underline field and the earnings line from the seller's own
///   commission quote;
/// - auction: Starting bid, Duration (3 to 14 days, − / + in Mono, "Ends [date · time]") and
///   an optional private Reserve price, each with its tooltip;
/// and Continue, off until what is needed is set.
class PostAvailabilityStep extends StatefulWidget {
  const PostAvailabilityStep({
    super.key,
    required this.cover,
    required this.photoCount,
    required this.mode,
    required this.onModeChanged,
    required this.priceController,
    required this.startingBidController,
    required this.reserveController,
    required this.durationDays,
    required this.onDurationChanged,
    required this.onBack,
    required this.onContinue,
    required this.quote,
    this.onEdit,
    this.modes = SaleMode.values,
    this.pieceTitle = 'Your piece',
    this.heading = 'How do you want to share it?',
    this.subheading = 'This decides what details we ask for next.',
    this.step = 1,
    this.steps = 3,
    this.actionLabel = 'Continue',
    this.busy = false,
    this.now,
  });

  /// The cover photo as framed, filling its box.
  final Widget cover;
  final int photoCount;
  final SaleMode mode;
  final ValueChanged<SaleMode> onModeChanged;
  final TextEditingController priceController;
  final TextEditingController startingBidController;
  final TextEditingController reserveController;
  final int durationDays;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback onContinue;

  /// What the seller keeps on a sale of the given cents; null hides the earnings line.
  final Future<CommissionQuote?> Function(int priceCents) quote;

  /// The options offered, in order.
  final List<SaleMode> modes;
  final String pieceTitle;
  final String heading;
  final String subheading;
  final int step;
  final int steps;
  final String actionLabel;
  final bool busy;

  /// For tests: the time the end date is worked out from.
  @visibleForTesting
  final DateTime? now;

  /// The price in dollars, or null when the field holds no price above zero.
  static double? parsePrice(String text) {
    final value = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    return value != null && value > 0 ? value : null;
  }

  /// The amount in cents, or null.
  static int? parseCents(String text) {
    final value = parsePrice(text);
    return value == null ? null : (value * 100).round();
  }

  /// Whether the step can continue: a price for a fixed price; for an auction a starting
  /// bid of at least $1 and, if set, a reserve no lower than it.
  static bool isComplete({
    required SaleMode mode,
    required String price,
    required String startingBid,
    required String reserve,
  }) {
    switch (mode) {
      case SaleMode.notForSale:
        return true;
      case SaleMode.fixed:
        return parsePrice(price) != null;
      case SaleMode.auction:
        final start = parseCents(startingBid);
        if (start == null || start < 100) return false;
        final reserveCents = parseCents(reserve);
        return reserve.trim().isEmpty || (reserveCents != null && reserveCents >= start);
    }
  }

  @override
  State<PostAvailabilityStep> createState() => _PostAvailabilityStepState();
}

class _PostAvailabilityStepState extends State<PostAvailabilityStep> {
  CommissionQuote? _quote;
  Timer? _debounce;
  int _request = 0;

  List<TextEditingController> get _controllers => [
    widget.priceController,
    widget.startingBidController,
    widget.reserveController,
  ];

  @override
  void initState() {
    super.initState();
    widget.priceController.addListener(_onPriceChanged);
    widget.startingBidController.addListener(_changed);
    widget.reserveController.addListener(_changed);
    if (widget.mode == SaleMode.fixed) _fetchQuote();
  }

  @override
  void didUpdateWidget(PostAvailabilityStep old) {
    super.didUpdateWidget(old);
    if (old.priceController != widget.priceController) {
      old.priceController.removeListener(_onPriceChanged);
      widget.priceController.addListener(_onPriceChanged);
    }
    if (widget.mode == SaleMode.fixed && old.mode != SaleMode.fixed) _fetchQuote();
  }

  @override
  void dispose() {
    widget.priceController.removeListener(_onPriceChanged);
    widget.startingBidController.removeListener(_changed);
    widget.reserveController.removeListener(_changed);
    _debounce?.cancel();
    super.dispose();
  }

  void _changed() => setState(() {});

  int get _priceCents => PostAvailabilityStep.parseCents(widget.priceController.text) ?? 0;

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
    final [price, start, reserve] = _controllers;
    final canContinue = PostAvailabilityStep.isComplete(
      mode: widget.mode,
      price: price.text,
      startingBid: start.text,
      reserve: reserve.text,
    );
    final bottom = math.max(36.0, MediaQuery.viewPaddingOf(context).bottom);
    final modes = widget.modes;

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
                          child: StudioIcon(StudioIcons.backBold, size: 22, color: c.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StudioProgressSegments(current: widget.step, total: widget.steps),
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
                      title: widget.pieceTitle,
                      photoCount: widget.photoCount,
                      onEdit: widget.onEdit,
                    ),
                    const SizedBox(height: 26),
                    Text(widget.heading, style: StudioType.title30(color: c.textPrimary)),
                    const SizedBox(height: 8),
                    Text(widget.subheading, style: StudioType.body15(color: c.textSecondary)),
                    const SizedBox(height: 26),
                    for (var i = 0; i < modes.length; i++)
                      _option(modes[i], divider: i < modes.length - 1),
                    if (widget.mode == SaleMode.fixed) ...[
                      const SizedBox(height: 26),
                      StudioUnderlineField(
                        label: 'Price',
                        controller: price,
                        hint: r'$0',
                        valueSize: 18,
                        strongUnderline: true,
                        required: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [PriceInputFormatter()],
                      ),
                      if (_quote != null) ...[
                        const SizedBox(height: 12),
                        _EarningsLine(
                          quote: _quote!,
                          priced: PostAvailabilityStep.parsePrice(price.text) != null,
                        ),
                      ],
                    ],
                    if (widget.mode == SaleMode.auction) ...[
                      const SizedBox(height: 22),
                      _AuctionFields(
                        startingBid: start,
                        reserve: reserve,
                        days: widget.durationDays,
                        onDays: widget.onDurationChanged,
                        now: widget.now ?? DateTime.now(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottom),
              child: StudioButton(
                label: widget.actionLabel,
                height: StudioSize.buttonPrimaryTall,
                loading: widget.busy,
                onPressed: canContinue && !widget.busy ? widget.onContinue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(SaleMode mode, {required bool divider}) {
    final (title, subtitle) = switch (mode) {
      SaleMode.fixed => ('Fixed price', 'One price, first to collect it'),
      SaleMode.auction => ('Auction', '3 to 14 days, highest bid wins'),
      SaleMode.notForSale => ('Not for sale', 'Shows on your profile. You can list it later.'),
    };
    return StudioSelectRow(
      title: title,
      subtitle: subtitle,
      selected: widget.mode == mode,
      onTap: () => widget.onModeChanged(mode),
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

/// `PostAvailAuction`: Starting bid; Duration with − / + (28 boxes, radius 8) around the Mono
/// day count and "Ends [date · time]" under it; Reserve price with "optional · private". The
/// gaps between them are 20.
class _AuctionFields extends StatelessWidget {
  const _AuctionFields({
    required this.startingBid,
    required this.reserve,
    required this.days,
    required this.onDays,
    required this.now,
  });

  final TextEditingController startingBid;
  final TextEditingController reserve;
  final int days;
  final ValueChanged<int> onDays;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final start = PostAvailabilityStep.parseCents(startingBid.text);
    final reserveCents = PostAvailabilityStep.parseCents(reserve.text);
    final reserveLow = start != null && reserveCents != null && reserveCents < start;
    final ends = AuctionTerms(startingBidCents: 0, durationDays: days).endsAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioUnderlineField(
          label: 'Starting bid',
          controller: startingBid,
          hint: r'$0',
          valueSize: 18,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [PriceInputFormatter()],
        ),
        const SizedBox(height: 20),
        StudioTooltip(
          message:
              'Pick 3 to 14 days. The auction ends at the time shown and the highest bid '
              'wins. There are no extensions or maximum bids.',
          builder: (context, toggle) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Duration', style: StudioType.sans(13, color: c.textSecondary)),
                  StudioInfoButton(onTap: toggle, semanticLabel: 'What is auction timing?'),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineStrong))),
                child: Row(
                  children: [
                    _StepButton(
                      label: '−',
                      semanticLabel: 'Fewer days',
                      onTap: days > AuctionTerms.minDays ? () => onDays(days - 1) : null,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '$days days',
                      style: StudioType.mono(18, color: c.textPrimary),
                    ),
                    const SizedBox(width: 14),
                    _StepButton(
                      label: '+',
                      semanticLabel: 'More days',
                      onTap: days < AuctionTerms.maxDays ? () => onDays(days + 1) : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Ends '),
                    TextSpan(
                      text: auctionDateTime(ends),
                      style: StudioType.mono(12, color: c.textSecondary),
                    ),
                  ],
                ),
                style: StudioType.caption12(height: 1.45, color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StudioTooltip(
          message:
              "Your minimum. Bidders never see it. If bidding ends below it, the piece doesn't "
              'sell and nothing is charged.',
          builder: (context, toggle) => StudioUnderlineField(
            label: 'Reserve price',
            controller: reserve,
            hint: r'$0',
            valueSize: 18,
            labelTrailing: StudioInfoButton(
              onTap: toggle,
              semanticLabel: 'What is a reserve price?',
            ),
            trailing: Text(
              'optional · private',
              style: StudioType.mono(11, color: c.textSecondary),
            ),
            errorText: reserveLow ? 'Set it at or above the starting bid.' : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [PriceInputFormatter()],
          ),
        ),
      ],
    );
  }
}

/// A 28 × 28 box, radius 8, 1 px Line Strong, with − or + in Geist 16.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.semanticLabel, required this.onTap});

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Drawn 28 × 28 and flush, as the board; the tap area still reaches 44.
        child: SizedBox.square(
          dimension: 28,
          child: OverflowBox(
            maxWidth: StudioSize.tapTarget,
            maxHeight: StudioSize.tapTarget,
            child: SizedBox.square(
              dimension: StudioSize.tapTarget,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(StudioRadius.small),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Text(
                    label,
                    style: StudioType.sans(
                      16,
                      color: onTap == null ? c.textPlaceholder : c.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 54 × 72 cover (radius 8), the title 15/500 over the Mono 12 photo count, Edit 14/500.
class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.cover,
    required this.title,
    required this.photoCount,
    required this.onEdit,
  });

  final Widget cover;
  final String title;
  final int photoCount;
  final VoidCallback? onEdit;

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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '$photoCount ${photoCount == 1 ? 'photo' : 'photos'}',
                style: StudioType.mono(12, color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (onEdit != null)
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
                      style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary),
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
                            style: TextStyle(fontWeight: StudioType.medium, color: c.textPrimary),
                          ),
                          TextSpan(text: ' after the $rate.'),
                        ],
                      )
                    : TextSpan(text: "You'll receive your price less the $rate."),
                style: style,
              ),
            ),
            const SizedBox(width: 8),
            StudioInfoButton(onTap: toggle, semanticLabel: 'What is the commission?'),
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
  return rest == 0 ? '\$$grouped' : '\$$grouped.${rest.toString().padLeft(2, '0')}';
}

/// 1500 → "15%", 1250 → "12.5%".
String formatPercent(int bps) {
  final value = bps / 100;
  return value == value.roundToDouble() ? '${value.round()}%' : '$value%';
}

/// Keeps a price as "$3,600" (or "$3,600.5", two decimals at most) while it is typed.
class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return const TextEditingValue();
    final dot = raw.indexOf('.');
    String whole = dot < 0 ? raw : raw.substring(0, dot);
    String? fraction = dot < 0 ? null : raw.substring(dot + 1).replaceAll('.', '');
    if (fraction != null && fraction.length > 2) {
      fraction = fraction.substring(0, 2);
    }
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > 9) return oldValue;
    final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final text = '\$${grouped.isEmpty ? '0' : grouped}${fraction == null ? '' : '.$fraction'}';
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

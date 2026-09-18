import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';
import 'create_flow_widgets.dart';
import 'event_date_sheet.dart';

const ticketAccent = Color(0xFFC45C4A);
const _platformFee = 0.13;
const _hairline = Color(0xFFC8C5BC);
const _disabledFill = Color(0xFFC8C5BC);

class EventTicketTier {
  const EventTicketTier({
    required this.name,
    this.isFree = false,
    this.buyerPays,
    this.limitPurchaseWindow = false,
    this.startsSelling,
    this.stopsSelling,
    this.description = '',
    this.limitQuantity = false,
    this.quantity,
    this.limitPerOrder = false,
    this.perOrder,
  });

  final String name;
  final bool isFree;
  final double? buyerPays;
  final bool limitPurchaseWindow;
  final DateTime? startsSelling;
  final DateTime? stopsSelling;
  final String description;
  final bool limitQuantity;
  final int? quantity;
  final bool limitPerOrder;
  final int? perOrder;

  bool get isComplete {
    if (name.trim().isEmpty) return false;
    if (isFree) return true;
    return buyerPays != null && buyerPays! > 0;
  }

  String? get descriptionLine {
    final text = description.trim();
    return text.isEmpty ? null : text;
  }

  String get priceLine {
    if (isFree) {
      if (limitQuantity && quantity != null) return 'Free, $quantity available';
      return 'Free, unlimited capacity';
    }
    if (buyerPays == null || buyerPays! <= 0) {
      return 'Set a price, unlimited capacity';
    }
    final price = _formatDollars(buyerPays!);
    if (limitQuantity && quantity != null) return '$price, $quantity available';
    return '$price, unlimited capacity';
  }

  String get reviewDetailLine {
    final qty = limitQuantity && quantity != null
        ? '$quantity available'
        : 'unlimited';
    if (isFree) return 'Free · $qty';
    if (buyerPays == null || buyerPays! <= 0) return qty;
    return '${_formatDollars(buyerPays!)} · $qty';
  }

  bool get priceLineIsHint =>
      !isFree && (buyerPays == null || buyerPays! <= 0);

  String? get perOrderLine {
    if (!limitPerOrder || perOrder == null) return null;
    return 'max $perOrder per order';
  }
}

String _formatDollars(double value, {bool cents = false}) {
  if (!cents && value == value.roundToDouble()) {
    return '\$${value.round()}';
  }
  return '\$${value.toStringAsFixed(2)}';
}

/// Full-screen editor for one ticket tier (Figma Event Posting — Tickets).
class EventTicketEditPage extends StatefulWidget {
  const EventTicketEditPage({super.key, required this.initial});

  final EventTicketTier initial;

  static Future<EventTicketTier?> open(
    BuildContext context, {
    required EventTicketTier initial,
  }) {
    return Navigator.of(context).push<EventTicketTier>(
      MaterialPageRoute(
        builder: (_) => EventTicketEditPage(initial: initial),
      ),
    );
  }

  @override
  State<EventTicketEditPage> createState() => _EventTicketEditPageState();
}

class _EventTicketEditPageState extends State<EventTicketEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _perOrder;
  late bool _isFree;
  late bool _limitWindow;
  late bool _limitQuantity;
  late bool _limitPerOrder;
  DateTime? _startsSelling;
  DateTime? _stopsSelling;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial.name);
    _price = TextEditingController(
      text: initial.buyerPays == null
          ? ''
          : initial.buyerPays!.toStringAsFixed(2),
    );
    _description = TextEditingController(text: initial.description);
    _quantity = TextEditingController(
      text: initial.quantity == null ? '' : '${initial.quantity}',
    );
    _perOrder = TextEditingController(
      text: initial.perOrder == null ? '' : '${initial.perOrder}',
    );
    _isFree = initial.isFree;
    _limitWindow = initial.limitPurchaseWindow;
    _limitQuantity = initial.limitQuantity;
    _limitPerOrder = initial.limitPerOrder;
    _startsSelling = initial.startsSelling;
    _stopsSelling = initial.stopsSelling;
    _name.addListener(_onChanged);
    _price.addListener(_onChanged);
    _description.addListener(_onChanged);
    _quantity.addListener(_onChanged);
    _perOrder.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _quantity.dispose();
    _perOrder.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  double? get _buyerPays {
    final parsed = double.tryParse(_price.text.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  double? get _youReceive {
    final pays = _buyerPays;
    if (pays == null) return null;
    return pays * (1 - _platformFee);
  }

  bool get _canSave {
    if (_name.text.trim().isEmpty) return false;
    if (_isFree) return true;
    return _buyerPays != null;
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: HomeFeedTokens.neutral800,
              onPrimary: HomeFeedTokens.textInverse,
              surface: HomeFeedTokens.background,
              onSurface: HomeFeedTokens.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(
      context,
      EventTicketTier(
        name: _name.text.trim(),
        isFree: _isFree,
        buyerPays: _isFree ? null : _buyerPays,
        limitPurchaseWindow: _limitWindow,
        startsSelling: _limitWindow ? _startsSelling : null,
        stopsSelling: _limitWindow ? _stopsSelling : null,
        description: _description.text.trim(),
        limitQuantity: _limitQuantity,
        quantity: _limitQuantity ? int.tryParse(_quantity.text.trim()) : null,
        limitPerOrder: _limitPerOrder,
        perOrder: _limitPerOrder ? int.tryParse(_perOrder.text.trim()) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          CreateFlowBanner(
            topInset: topInset,
            title: 'Edit ticket',
            onClose: () => Navigator.pop(context),
            useBackChevron: true,
            height: 53,
          ),
          Expanded(
            child: ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _LabeledField(
                  label: 'Name',
                  child: _OutlineBox(
                    child: TextField(
                      controller: _name,
                      cursorColor: HomeFeedTokens.textPrimary,
                      style: _fieldStyle,
                      decoration: _hint('General Admission'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ToggleRow(
                  label: 'Make this ticket type free',
                  value: _isFree,
                  onChanged: (value) => setState(() => _isFree = value),
                ),
                if (!_isFree) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Buyer pays',
                          child: _PriceBox(
                            controller: _price,
                            enabled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LabeledField(
                          label: 'You receive',
                          child: _PriceBox(
                            display: _youReceive == null
                                ? ''
                                : _youReceive!.toStringAsFixed(2),
                            enabled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _ToggleRow(
                  label: 'Limit when this can be purchased',
                  value: _limitWindow,
                  onChanged: (value) => setState(() => _limitWindow = value),
                ),
                if (_limitWindow) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Starts selling',
                          child: _TapBox(
                            value: _startsSelling == null
                                ? null
                                : formatEventDateShort(_startsSelling!),
                            hint: 'Select date',
                            onTap: () async {
                              final picked = await _pickDate(_startsSelling);
                              if (picked != null) {
                                setState(() => _startsSelling = picked);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LabeledField(
                          label: 'Stops selling',
                          child: _TapBox(
                            value: _stopsSelling == null
                                ? null
                                : formatEventDateShort(_stopsSelling!),
                            hint: 'Select date',
                            onTap: () async {
                              final picked = await _pickDate(_stopsSelling);
                              if (picked != null) {
                                setState(() => _stopsSelling = picked);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _LabeledField(
                  label: 'Description',
                  child: _OutlineBox(
                    height: null,
                    child: TextField(
                      controller: _description,
                      maxLines: 3,
                      minLines: 3,
                      cursorColor: HomeFeedTokens.textPrimary,
                      style: _fieldStyle.copyWith(fontSize: 12),
                      decoration: _hint("What's included with this ticket?"),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ToggleRow(
                  label: 'Limit quantity',
                  value: _limitQuantity,
                  onChanged: (value) => setState(() => _limitQuantity = value),
                ),
                if (_limitQuantity) ...[
                  const SizedBox(height: 12),
                  _OutlineBox(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      cursorColor: HomeFeedTokens.textPrimary,
                      style: _fieldStyle,
                      decoration: _hint('100'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _ToggleRow(
                  label: 'Limit purchase per order',
                  value: _limitPerOrder,
                  onChanged: (value) => setState(() => _limitPerOrder = value),
                ),
                if (_limitPerOrder) ...[
                  const SizedBox(height: 12),
                  _OutlineBox(
                    child: TextField(
                      controller: _perOrder,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      cursorColor: HomeFeedTokens.textPrimary,
                      style: _fieldStyle,
                      decoration: _hint('4'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 16, 10, bottomInset + 16),
            child: CreateFlowBottomButton(
              label: 'Save and continue',
              height: 40,
              backgroundColor: _canSave
                  ? HomeFeedTokens.neutral800
                  : _disabledFill,
              textColor: _canSave
                  ? HomeFeedTokens.textInverse
                  : HomeFeedTokens.textPrimary,
              onTap: _canSave ? _save : null,
              child: Text(
                'Save and continue',
                style: GoogleFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: _canSave
                      ? HomeFeedTokens.textInverse
                      : HomeFeedTokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle get _fieldStyle => GoogleFonts.geist(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: HomeFeedTokens.textPrimary,
    );

InputDecoration _hint(String text) {
  return InputDecoration(
    isDense: true,
    border: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintText: text,
    hintStyle: GoogleFonts.geist(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: HomeFeedTokens.textSecondary,
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HomeFeedTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _OutlineBox extends StatelessWidget {
  const _OutlineBox({required this.child, this.height = 40, this.fill});

  final Widget child;
  final double? height;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: height == null ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeFeedTokens.textPrimary),
      ),
      child: child,
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({
    this.controller,
    this.display,
    required this.enabled,
  });

  final TextEditingController? controller;
  final String? display;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _OutlineBox(
      fill: enabled ? null : HomeFeedTokens.skeletonBase,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '\$',
              style: GoogleFonts.geist(
                fontSize: 10,
                color: HomeFeedTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: enabled
                ? TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    cursorColor: HomeFeedTokens.textPrimary,
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(right: 12, top: 2),
                    ),
                  )
                : Text(
                    display ?? '',
                    style: _fieldStyle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TapBox extends StatelessWidget {
  const _TapBox({
    required this.hint,
    required this.onTap,
    this.value,
  });

  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _OutlineBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            filled ? value! : hint,
            style: GoogleFonts.geist(
              fontSize: 13,
              color: filled
                  ? HomeFeedTokens.textPrimary
                  : HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: Colors.white,
          activeTrackColor: HomeFeedTokens.neutral800,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: _hairline,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }
}

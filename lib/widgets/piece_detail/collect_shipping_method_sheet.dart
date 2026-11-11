import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../models/collect_checkout.dart';
import '../../models/shipping_quote.dart';
import '../../screens/address_form_page.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../services/order_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';
import '../studio/studio_switch.dart';
import 'collect_shipping_sheet.dart';

/// Shipping (`BuyShipping`), kept as a sheet: "Ship to" with Change, the delivery options
/// from the shipping quote as select rows (left line, price on the right), the partner
/// line, and Continue (54).
///
/// With Convelio on (`live`, FRONTEND_HANDOFF 8.3): Speed (Regular / Express) and Delivery
/// (Curbside / White-glove) as the same select rows and an Insurance switch, then a live quote
/// for this address (2 to 9 seconds) with its shipping and insurance. A pending quote is priced
/// by hand ("we'll notify you") and can't be used yet. A server with Convelio off, or one that
/// says live quotes aren't switched on (409) or set up (503), gets the flat tiers as before.
class CollectShippingMethodSheet extends StatefulWidget {
  const CollectShippingMethodSheet({
    super.key,
    required this.pieceId,
    required this.address,
    this.initialMethodId,
    this.initialQuote,
    this.onMessageArtist,
    @visibleForTesting this.debugMethods,
    @visibleForTesting this.debugOptions,
  });

  final String pieceId;
  final Address address;
  final String? initialMethodId;

  /// The quote chosen before: its speed, delivery and insurance are kept.
  final ShippingQuote? initialQuote;

  /// "Message the artist" when the artist hasn't added what the courier needs (409).
  final VoidCallback? onMessageArtist;

  /// Tests only: show these instead of fetching the quote.
  final List<CollectShippingMethod>? debugMethods;

  /// The address each pending quote was asked for, so `shipping_quote_ready` can reopen
  /// checkout on it (the quote itself doesn't say).
  static final Map<String, Address> pendingQuoteAddresses = {};

  /// Tests only: the shipping mode instead of fetching it.
  final ShippingOptions? debugOptions;

  static Future<CollectShippingSelection?> show(
    BuildContext context, {
    required String pieceId,
    required Address address,
    String? initialMethodId,
    ShippingQuote? initialQuote,
    VoidCallback? onMessageArtist,
  }) {
    return showStudioSheet<CollectShippingSelection>(
      context: context,
      builder: (context) => CollectShippingMethodSheet(
        pieceId: pieceId,
        address: address,
        initialMethodId: initialMethodId,
        initialQuote: initialQuote,
        onMessageArtist: onMessageArtist,
      ),
    );
  }

  @override
  State<CollectShippingMethodSheet> createState() => _CollectShippingMethodSheetState();
}

class _CollectShippingMethodSheetState extends State<CollectShippingMethodSheet> {
  String? _selectedId;
  late Address _address;
  List<CollectShippingMethod> _methods = [];
  bool _loading = true;
  String? _error;

  /// Convelio is on: speed, delivery and insurance, then a live quote.
  bool _live = false;
  ShippingOptions _options = const ShippingOptions();
  String _speed = 'regular_speed';
  String _deliveryType = 'curbside';
  bool _insurance = true;
  ShippingQuote? _quote;
  bool _quoting = false;
  String? _quoteError;

  /// The quote refusal is the artist's to fix (409 "The artist needs to add…").
  bool _artistMissing = false;

  @override
  void initState() {
    super.initState();
    _address = widget.address;
    _selectedId = widget.initialMethodId;
    final initialQuote = widget.initialQuote;
    if (initialQuote != null) {
      _speed = initialQuote.speed;
      _deliveryType = initialQuote.deliveryType;
      _insurance = initialQuote.insurance;
    }
    final debug = widget.debugMethods;
    final debugOptions = widget.debugOptions;
    if (debugOptions != null) {
      _apply(debugOptions, quote: debugOptions.live);
    } else if (debug != null) {
      _methods = debug;
      _loading = false;
      _selectedId ??= debug.isEmpty ? null : debug.first.id;
    } else {
      _load();
    }
  }

  Future<void> _load({bool flatOnly = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await OrderService.instance.getShippingQuote(widget.pieceId);
      if (!mounted) return;
      if (flatOnly && options.methods.isEmpty) {
        setState(() {
          _loading = false;
          _error = _quoteError ?? 'Shipping rates are not available right now.';
        });
        return;
      }
      _apply(flatOnly ? ShippingOptions(methods: options.methods) : options, quote: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load shipping rates';
        _loading = false;
      });
    }
  }

  void _apply(ShippingOptions options, {required bool quote}) {
    setState(() {
      _options = options;
      _live = options.live;
      _loading = false;
      if (_live) {
        if (widget.initialQuote == null) _insurance = options.insuranceDefault;
        if (!options.speeds.contains(_speed) && options.speeds.isNotEmpty) _speed = options.speeds.first;
        if (!options.deliveryTypes.contains(_deliveryType) && options.deliveryTypes.isNotEmpty) {
          _deliveryType = options.deliveryTypes.first;
        }
      } else {
        _methods = options.methods.map(CollectShippingMethod.fromQuote).toList();
        _selectedId ??= _methods.isNotEmpty ? _methods.first.id : null;
      }
    });
    if (_live && quote) _requestQuote();
  }

  /// Changing a choice drops the quote; Get quote asks again.
  void _choose(VoidCallback change) {
    setState(() {
      change();
      _quote = null;
      _quoteError = null;
      _artistMissing = false;
    });
  }

  Future<void> _requestQuote() async {
    if (_quoting) return;
    setState(() {
      _quoting = true;
      _quote = null;
      _quoteError = null;
      _artistMissing = false;
    });
    try {
      final quote = await OrderService.instance.createShippingQuote(
        widget.pieceId,
        addressId: _address.id,
        speed: _speed,
        deliveryType: _deliveryType,
        insurance: _insurance,
      );
      if (quote.pending) CollectShippingMethodSheet.pendingQuoteAddresses[quote.id] = _address;
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _quoting = false);
      final message = e.message;
      final lower = message.toLowerCase();
      if ((e.statusCode == 409 && lower.contains("aren't switched on")) || e.statusCode == 503) {
        // Convelio is off after all: the flat tiers.
        _quoteError = message;
        await _load(flatOnly: true);
        return;
      }
      if (e.statusCode == 409 && lower.contains('contact details')) {
        setState(() => _quoteError = message);
        await _fixContactDetails();
        return;
      }
      setState(() {
        _quoteError = message;
        _artistMissing = e.statusCode == 409 && lower.contains('artist');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoting = false;
        _quoteError = "Couldn't get a shipping quote. Please try again.";
      });
    }
  }

  /// The courier needs the buyer's name and phone: edit the address, then quote again.
  Future<void> _fixContactDetails() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => AddressFormPage(existing: _address)),
    );
    if (!mounted || saved != true) return;
    try {
      final addresses = await AddressService.instance.getAddresses();
      final fresh = addresses.where((a) => a.id == _address.id).firstOrNull;
      if (!mounted) return;
      if (fresh != null) setState(() => _address = fresh);
    } catch (_) {
      // Quote with what we have; the server says if it is still missing.
    }
    if (mounted) await _requestQuote();
  }

  CollectShippingMethod? get _selected => _methods.where((m) => m.id == _selectedId).firstOrNull;

  /// A priced quote for the current choices.
  ShippingQuote? get _usableQuote {
    final quote = _quote;
    return quote != null && quote.isPriced ? quote : null;
  }

  void _save() {
    if (_live) {
      final quote = _usableQuote;
      if (quote == null) return;
      Navigator.pop(context, CollectShippingSelection(address: _address, quote: quote));
      return;
    }
    final method = _selected;
    if (method == null) return;
    Navigator.pop(context, CollectShippingSelection(address: _address, method: method));
  }

  Future<void> _changeAddress() async {
    final updated = await CollectShippingSheet.show(context, initial: _address);
    if (!mounted || updated == null) return;
    setState(() => _address = updated);
    if (_live) _requestQuote();
  }

  static String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  /// Speed, Delivery and Insurance, then the quote, its wait, or why there isn't one.
  List<Widget> _liveOptions(StudioColors c) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary)),
    );
    Widget group(List<String> values, String current, String Function(String) label, String? Function(String) sub,
        void Function(String) onPick) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++)
          StudioSelectRow(
            title: label(values[i]),
            subtitle: sub(values[i]),
            selected: current == values[i],
            titleSize: 17,
            titleLetterSpacing: 0,
            verticalPadding: 16,
            ruleInset: 16,
            subtitleSize: 13,
            subtitleGap: 3,
            divider: i < values.length - 1,
            onTap: _quoting ? null : () => _choose(() => onPick(values[i])),
          ),
      ],
    );
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: StudioType.body14(color: c.textSecondary)),
          const Spacer(),
          Text(value, style: StudioType.body14(color: c.textPrimary)),
        ],
      ),
    );
    final quote = _quote;
    return [
      heading('Speed'),
      group(
        _options.speeds,
        _speed,
        ShippingOptions.speedLabel,
        (v) => switch (v) {
          'express' => 'Faster, for a higher price',
          _ => null,
        },
        (v) => _speed = v,
      ),
      const SizedBox(height: 18),
      heading('Delivery'),
      group(
        _options.deliveryTypes,
        _deliveryType,
        ShippingOptions.deliveryLabel,
        (v) => switch (v) {
          'curbside' => 'Left at the door',
          'white_glove' => 'Brought in and unpacked',
          _ => null,
        },
        (v) => _deliveryType = v,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: Text('Insurance', style: StudioType.sans(16, color: c.textPrimary))),
          StudioSwitch(
            value: _insurance,
            onChanged: _quoting ? null : (v) => _choose(() => _insurance = v),
            semanticLabel: 'Insurance',
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (_quoting)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 12),
              Text('Getting a shipping quote…', style: StudioType.caption12(color: c.textSecondary)),
            ],
          ),
        )
      else if (quote != null && quote.pending)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Shipping quote on its way — we'll notify you",
            style: StudioType.body14(color: c.textPrimary),
          ),
        )
      else if (quote != null && quote.isPriced) ...[
        line('Shipping', _money(quote.shippingCents ?? quote.totalShippingCents!)),
        if (quote.insurance && (quote.insuranceCents ?? 0) > 0) line('Insurance', _money(quote.insuranceCents!)),
      ] else if (_quoteError != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // Errors are Ink, never red (`HandoffRules`).
          child: Text(_quoteError!, style: StudioType.body14(color: c.textPrimary)),
        ),
        if (_artistMissing && widget.onMessageArtist != null) ...[
          const SizedBox(height: 8),
          StudioButton(
            label: 'Message the artist',
            variant: StudioButtonVariant.outline,
            onPressed: () {
              Navigator.pop(context);
              widget.onMessageArtist!();
            },
          ),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final mq = MediaQuery.of(context);
    final safeBottom = mq.viewPadding.bottom;
    final address = _address;
    final street = [
      address.fullName,
      address.line1,
      if ((address.line2 ?? '').isNotEmpty) address.line2!,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return SizedBox(
      height: mq.size.height * StudioSize.sheetMaxHeightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: StudioSheetGrabber()),
          _SheetHeader(title: 'Shipping', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                // Ship to: label 13 Graphite, then the address in 15 (ZIP in Mono 14),
                // 3 apart; Change on the right.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ship to', style: StudioType.label13(color: c.textSecondary)),
                          const SizedBox(height: 3),
                          Text(street, style: StudioType.sans(15, color: c.textPrimary)),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${address.city}, ${address.state} '),
                                TextSpan(
                                  text: address.zip,
                                  style: StudioType.mono(14, color: c.textPrimary),
                                ),
                              ],
                            ),
                            style: StudioType.sans(15, color: c.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: _changeAddress,
                        behavior: HitTestBehavior.opaque,
                        // Underlined link, 6 above and below (`BuyShipping`); the padding
                        // also takes the tap target to 44.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 32),
                            child: Text(
                              'Change',
                              style: StudioType.body14(color: c.textSecondary).copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_live && !_loading && _error == null)
                  ..._liveOptions(c)
                else ...[
                Text(
                  'Delivery',
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    // Errors are Ink, never red (`HandoffRules`).
                    child: Text(_error!, style: StudioType.body14(color: c.textPrimary)),
                  )
                else
                  for (var i = 0; i < _methods.length; i++)
                    StudioSelectRow(
                      title: _methods[i].title,
                      subtitle: _methods[i].duration.isEmpty ? null : _methods[i].duration,
                      selected: _selectedId == _methods[i].id,
                      titleSize: 17,
                      titleLetterSpacing: 0,
                      verticalPadding: 16,
                      ruleInset: 16,
                      subtitleSize: 13,
                      subtitleGap: 3,
                      divider: i < _methods.length - 1,
                      trailing: Text(
                        _methods[i].priceDisplay,
                        style: StudioType.sans(
                          15,
                          color: _selectedId == _methods[i].id ? c.textPrimary : c.textTertiary,
                        ),
                      ),
                      onTap: () => setState(() => _selectedId = _methods[i].id),
                    ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Quotes come from our fine art shipping partner and include crating.',
                  style: StudioType.caption12(height: 1.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              safeBottom > 0 ? safeBottom : StudioSize.noInsetBottomPadding,
            ),
            child: _live && _usableQuote == null && !(_quote?.pending ?? false)
                ? StudioButton(
                    label: 'Get a quote',
                    height: StudioSize.buttonPrimaryTall,
                    loading: _quoting,
                    onPressed: _quoting || _loading ? null : _requestQuote,
                  )
                : StudioButton(
                    label: 'Continue',
                    height: StudioSize.buttonPrimaryTall,
                    onPressed: (_live ? _usableQuote != null : _selected != null) ? _save : null,
                  ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Back (22 px, 44 target) on the left, the title 16/500 centred.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: StudioIcon(StudioIcons.back, size: 22, color: c.textPrimary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

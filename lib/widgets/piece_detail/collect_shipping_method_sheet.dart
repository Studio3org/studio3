import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../models/collect_checkout.dart';
import '../../services/api_exception.dart';
import '../../services/order_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';
import 'collect_shipping_sheet.dart';

/// Shipping (`BuyShipping`), kept as a sheet: "Ship to" with Change, the delivery options
/// from the shipping quote as select rows (left line, price on the right), the partner
/// line, and Continue (54). No insurance card: the app does not offer insurance today.
class CollectShippingMethodSheet extends StatefulWidget {
  const CollectShippingMethodSheet({
    super.key,
    required this.pieceId,
    required this.address,
    this.initialMethodId,
    @visibleForTesting this.debugMethods,
  });

  final String pieceId;
  final Address address;
  final String? initialMethodId;

  /// Tests only: show these instead of fetching the quote.
  final List<CollectShippingMethod>? debugMethods;

  static Future<CollectShippingSelection?> show(
    BuildContext context, {
    required String pieceId,
    required Address address,
    String? initialMethodId,
  }) {
    return showStudioSheet<CollectShippingSelection>(
      context: context,
      builder: (context) => CollectShippingMethodSheet(
        pieceId: pieceId,
        address: address,
        initialMethodId: initialMethodId,
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

  @override
  void initState() {
    super.initState();
    _address = widget.address;
    _selectedId = widget.initialMethodId;
    final debug = widget.debugMethods;
    if (debug != null) {
      _methods = debug;
      _loading = false;
      _selectedId ??= debug.isEmpty ? null : debug.first.id;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quotes = await OrderService.instance.getShippingQuote(widget.pieceId);
      if (!mounted) return;
      setState(() {
        _methods = quotes.map(CollectShippingMethod.fromQuote).toList();
        _selectedId ??= _methods.isNotEmpty ? _methods.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load shipping rates';
        _loading = false;
      });
    }
  }

  CollectShippingMethod? get _selected => _methods.where((m) => m.id == _selectedId).firstOrNull;

  void _save() {
    final method = _selected;
    if (method == null) return;
    Navigator.pop(context, CollectShippingSelection(address: _address, method: method));
  }

  Future<void> _changeAddress() async {
    final updated = await CollectShippingSheet.show(context, initial: _address);
    if (!mounted || updated == null) return;
    setState(() => _address = updated);
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
            child: StudioButton(
              label: 'Continue',
              height: StudioSize.buttonPrimaryTall,
              onPressed: _selected != null ? _save : null,
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

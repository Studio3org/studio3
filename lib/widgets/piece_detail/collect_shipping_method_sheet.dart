import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/address.dart';
import '../../models/collect_checkout.dart';
import '../../services/api_exception.dart';
import '../../services/order_service.dart';
import '../../theme/collect_detail_tokens.dart';
import 'collect_shipping_sheet.dart';

/// Shipping method picker — Figma 2382-1648.
class CollectShippingMethodSheet extends StatefulWidget {
  const CollectShippingMethodSheet({
    super.key,
    required this.pieceId,
    required this.address,
    this.initialMethodId,
  });

  final String pieceId;
  final Address address;
  final String? initialMethodId;

  static Future<CollectShippingSelection?> show(
    BuildContext context, {
    required String pieceId,
    required Address address,
    String? initialMethodId,
  }) {
    return showModalBottomSheet<CollectShippingSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectShippingMethodSheet(
        pieceId: pieceId,
        address: address,
        initialMethodId: initialMethodId,
      ),
    );
  }

  @override
  State<CollectShippingMethodSheet> createState() =>
      _CollectShippingMethodSheetState();
}

class _CollectShippingMethodSheetState
    extends State<CollectShippingMethodSheet> {
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
    _load();
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

  CollectShippingMethod? get _selected =>
      _methods.where((m) => m.id == _selectedId).firstOrNull;

  void _save() {
    final method = _selected;
    if (method == null) return;
    Navigator.pop(
      context,
      CollectShippingSelection(address: _address, method: method),
    );
  }

  Future<void> _changeAddress() async {
    final updated = await CollectShippingSheet.show(
      context,
      initial: _address,
    );
    if (!mounted || updated == null) return;
    setState(() => _address = updated);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.96;
    final address = _address;

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
              _SheetHeader(
                title: 'Shipping',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : ListView(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                        children: [
                          DecoratedBox(
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
                                    children: [
                                      Text(
                                        'Ship to',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          color: CollectDetailTokens.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: _changeAddress,
                                        child: Text(
                                          'Change',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: CollectDetailTokens.textSecondary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _AddressLine(
                                    address.label?.isNotEmpty == true
                                        ? address.label!
                                        : address.fullName,
                                  ),
                                  _AddressLine(address.line1),
                                  if (address.line2 != null &&
                                      address.line2!.isNotEmpty)
                                    _AddressLine(address.line2!),
                                  _AddressLine(
                                    '${address.city}, ${address.state} ${address.zip}',
                                  ),
                                  _AddressLine(address.phone),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: CollectDetailTokens.sheetCardFill,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shipping method',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: CollectDetailTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_error != null)
                                    Text(
                                      _error!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.red.shade300,
                                      ),
                                    )
                                  else
                                    for (var i = 0; i < _methods.length; i++) ...[
                                      if (i > 0)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 10),
                                          child: Divider(
                                            height: 1,
                                            color: CollectDetailTokens.divider,
                                          ),
                                        ),
                                      _MethodOption(
                                        method: _methods[i],
                                        selected: _selectedId == _methods[i].id,
                                        onTap: () => setState(
                                          () => _selectedId = _methods[i].id,
                                        ),
                                      ),
                                    ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: CollectDetailTokens.collectButtonHeight,
                            width: double.infinity,
                            child: Material(
                              color: _selected != null
                                  ? CollectDetailTokens.ctaFill
                                  : CollectDetailTokens.ctaFill.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                CollectDetailTokens.collectButtonRadius,
                              ),
                              child: InkWell(
                                onTap: _selected != null ? _save : null,
                                borderRadius: BorderRadius.circular(
                                  CollectDetailTokens.collectButtonRadius,
                                ),
                                child: Center(
                                  child: Text(
                                    'Save and continue',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: CollectDetailTokens.textInverse,
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
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _AddressLine extends StatelessWidget {
  const _AddressLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: CollectDetailTokens.textPrimary,
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final CollectShippingMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 14,
              color: selected
                  ? CollectDetailTokens.textPrimary
                  : CollectDetailTokens.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  method.duration,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: CollectDetailTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            method.priceDisplay,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: CollectDetailTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

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
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
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

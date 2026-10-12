import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/address.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../screens/address_form_page.dart';
import '../../theme/collect_detail_tokens.dart';

/// Saved-address picker for checkout — Figma 2371-1692.
class CollectShippingSheet extends StatefulWidget {
  const CollectShippingSheet({
    super.key,
    this.initial,
  });

  final Address? initial;

  static Future<Address?> show(
    BuildContext context, {
    Address? initial,
  }) {
    return showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectShippingSheet(initial: initial),
    );
  }

  @override
  State<CollectShippingSheet> createState() => _CollectShippingSheetState();
}

class _CollectShippingSheetState extends State<CollectShippingSheet> {
  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initial?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await AddressService.instance.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
        _selectedId ??= addresses.where((a) => a.isDefault).map((a) => a.id).firstOrNull ??
            (addresses.isNotEmpty ? addresses.first.id : null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load addresses';
        _loading = false;
      });
    }
  }

  Future<void> _addAddress() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AddressFormPage()),
    );
    if (result == true) _load();
  }

  void _save() {
    final address = _addresses.where((a) => a.id == _selectedId).firstOrNull;
    if (address == null) return;
    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.96;

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
              _ShippingHeader(onBack: () => Navigator.pop(context)),
              Expanded(
                child: _buildBody(bottomInset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double bottomInset) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: CollectDetailTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
      children: [
        if (_addresses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No saved addresses yet. Add one to continue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: CollectDetailTokens.textSecondary,
              ),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: CollectDetailTokens.sheetCardFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final address in _addresses)
                    _AddressOption(
                      address: address,
                      selected: _selectedId == address.id,
                      onTap: () => setState(() => _selectedId = address.id),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _addAddress,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '+ Add new address',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CollectDetailTokens.brand,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: CollectDetailTokens.collectButtonHeight,
          width: double.infinity,
          child: Material(
            color: _selectedId != null
                ? CollectDetailTokens.ctaFill
                : CollectDetailTokens.ctaFill.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(
              CollectDetailTokens.collectButtonRadius,
            ),
            child: InkWell(
              onTap: _selectedId != null ? _save : null,
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
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ShippingHeader extends StatelessWidget {
  const _ShippingHeader({required this.onBack});

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
              'Shipping',
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

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: selected
                    ? CollectDetailTokens.textPrimary
                    : CollectDetailTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label?.isNotEmpty == true
                        ? address.label!
                        : address.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CollectDetailTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${address.line1}, ${address.city}, ${address.state} ${address.zip}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: CollectDetailTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

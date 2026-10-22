import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../screens/address_form_page.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_action_row.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';

/// Checkout's saved-address picker, the first half of `BuyAddress` (the form itself is
/// `AddressFormPage`): board sheet titled "Delivery address", saved addresses as select
/// rows (left line, no radios), "Add a new address", and "Save and continue" (54).
class CollectShippingSheet extends StatefulWidget {
  const CollectShippingSheet({
    super.key,
    this.initial,
    @visibleForTesting this.debugAddresses,
  });

  final Address? initial;

  /// Tests only: show these instead of loading.
  final List<Address>? debugAddresses;

  static Future<Address?> show(BuildContext context, {Address? initial}) {
    return showStudioSheet<Address>(
      context: context,
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
    final debug = widget.debugAddresses;
    if (debug != null) {
      _addresses = debug;
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
      final addresses = await AddressService.instance.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
        _selectedId ??=
            addresses.where((a) => a.isDefault).map((a) => a.id).firstOrNull ??
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
    final c = context.studio;
    final Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_error != null && _addresses.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: StudioType.body14(color: c.textSecondary),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No saved addresses yet. Add one to continue.',
                style: StudioType.body14(color: c.textSecondary),
              ),
            )
          else
            for (var i = 0; i < _addresses.length; i++)
              StudioSelectRow(
                title: _addresses[i].label?.isNotEmpty == true
                    ? _addresses[i].label!
                    : _addresses[i].fullName,
                subtitle: _oneLine(_addresses[i]),
                selected: _selectedId == _addresses[i].id,
                titleSize: 17,
                titleLetterSpacing: 0,
                verticalPadding: 16,
                ruleInset: 14,
                onTap: () => setState(() => _selectedId = _addresses[i].id),
              ),
          StudioActionRow(icon: StudioIcons.post, title: 'Add a new address', onTap: _addAddress),
        ],
      );
    }

    return StudioSheet(
      horizontalPadding: 24,
      gap: 12,
      scrollable: true,
      children: [
        _ShippingHeader(onBack: () => Navigator.pop(context)),
        content,
        const SizedBox(height: 8),
        StudioButton(
          label: 'Save and continue',
          height: StudioSize.buttonPrimaryTall,
          onPressed: _selectedId != null && _addresses.isNotEmpty ? _save : null,
        ),
      ],
    );
  }

  static String _oneLine(Address a) => [
    a.line1,
    if ((a.line2 ?? '').isNotEmpty) a.line2!,
    '${a.city}, ${a.state} ${a.zip}',
  ].join(', ');
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Back (22 px, 44 target) on the left, "Delivery address" 16/500 centred.
class _ShippingHeader extends StatelessWidget {
  const _ShippingHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SizedBox(
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StudioIcon(StudioIcons.backBold, size: 22, color: c.textPrimary),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Delivery address',
              textAlign: TextAlign.center,
              style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

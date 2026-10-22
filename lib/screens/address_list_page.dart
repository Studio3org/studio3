import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../services/connectivity_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_action_row.dart';
import '../widgets/studio/studio_empty_state.dart';
import '../widgets/studio/studio_icon.dart';
import '../widgets/studio/studio_sheet.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../widgets/offline_state.dart';
import 'address_form_page.dart';

/// Saved addresses from Settings. No board: rows on Line rules (name 15/500, address 13
/// Graphite, "Default" Mono pill), ⋯ opening an actions sheet (`ConvMenu` pattern).
class AddressListPage extends StatefulWidget {
  const AddressListPage({super.key});

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    _load();
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeReconnectHook(_onReconnected);
    super.dispose();
  }

  Future<void> _onReconnected() => _load(refresh: true);

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await AddressService.instance.getAddressesCached(forceRefresh: refresh);
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
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

  Future<void> _editAddress(Address address) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => AddressFormPage(existing: address)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address'),
        content: Text('Remove "${address.label ?? address.fullName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AddressService.instance.deleteAddress(address.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete address';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _setDefault(Address address) async {
    try {
      await AddressService.instance.setDefault(address.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not set default address';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(
        context: context,
        title: 'Shipping addresses',
        actions: [
          IconButton(
            onPressed: _addAddress,
            tooltip: 'Add address',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: StudioIcon(StudioIcons.post, size: 22, color: context.studio.textPrimary),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_addresses.isEmpty && !_loading && !ConnectivityService.instance.isOnline) {
      return OfflineState(onRetry: () => _load(refresh: true));
    }
    if (_loading && _addresses.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _addresses.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(_error!, style: StudioType.body14(color: context.studio.textSecondary)),
          ),
        ],
      );
    }
    if (_addresses.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          StudioEmptyState(title: 'No saved addresses yet'),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        StudioSpace.marginPage,
        8,
        StudioSpace.marginPage,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final address = _addresses[index];
        return _AddressCard(
          address: address,
          onEdit: () => _editAddress(address),
          onMore: () => _showActions(address),
        );
      },
    );
  }

  void _showActions(Address address) {
    showStudioSheet<void>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          StudioActionRow(
            icon: StudioIcons.renameFolder,
            title: 'Edit',
            onTap: () {
              Navigator.pop(sheetContext);
              _editAddress(address);
            },
          ),
          if (!address.isDefault)
            StudioActionRow(
              icon: StudioIcons.check,
              title: 'Set as default',
              onTap: () {
                Navigator.pop(sheetContext);
                _setDefault(address);
              },
            ),
          StudioActionRow(
            icon: StudioIcons.deleteFolder,
            title: 'Delete',
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteAddress(address);
            },
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onEdit, required this.onMore});

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final detail = StudioType.label13(color: c.textSecondary);
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.label?.isNotEmpty == true ? address.label! : address.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.sans(
                            15,
                            weight: StudioType.medium,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(StudioRadius.round),
                            border: Border.all(color: c.lineStrong),
                          ),
                          child: Text('Default', style: StudioType.mono11(color: c.textPrimary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address.fullName, style: detail),
                  Text(address.line1, style: detail),
                  if (address.line2 != null && address.line2!.isNotEmpty)
                    Text(address.line2!, style: detail),
                  Text('${address.city}, ${address.state} ${address.zip}', style: detail),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Address options',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onMore,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: StudioIcon(StudioIcons.more, size: 20, color: c.textTertiary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

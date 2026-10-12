import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/offline_state.dart';
import 'address_form_page.dart';

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
      final addresses =
          await AddressService.instance.getAddressesCached(forceRefresh: refresh);
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
      MaterialPageRoute<bool>(
        builder: (_) => AddressFormPage(existing: address),
      ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
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
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Shipping addresses',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: HomeFeedTokens.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: HomeFeedTokens.textPrimary),
            onPressed: _addAddress,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_addresses.isEmpty &&
        !_loading &&
        !ConnectivityService.instance.isOnline) {
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
            child: Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
            ),
          ),
        ],
      );
    }
    if (_addresses.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No saved addresses yet',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final address = _addresses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AddressCard(
            address: address,
            onEdit: () => _editAddress(address),
            onDelete: () => _deleteAddress(address),
            onSetDefault: () => _setDefault(address),
          ),
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label?.isNotEmpty == true
                            ? address.label!
                            : address.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.slate900,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.fullName,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
                  ),
                  Text(
                    address.line1,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
                  ),
                  if (address.line2 != null && address.line2!.isNotEmpty)
                    Text(
                      address.line2!,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
                    ),
                  Text(
                    '${address.city}, ${address.state} ${address.zip}',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.slate400),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
                if (value == 'default') onSetDefault();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!address.isDefault)
                  const PopupMenuItem(value: 'default', child: Text('Set as default')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

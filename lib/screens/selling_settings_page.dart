import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/user_profile.dart';
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/selling/pickup_address.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';

/// Selling (`SettingsSelling`, Flow 12), for seller profiles: a green dot and "Seller profile is
/// on"; Studio: Seller terms (the account's own rates from `/api/user/me/seller-terms`, e.g.
/// "15% on art · 8% on tickets", or "Includes fees" until they load; the seller terms page);
/// then Turn off seller profile ("Your listings and auctions without bids will come down."),
/// which asks first. Pops true once selling is off.
///
/// Pickup address (FRONTEND_HANDOFF 8.1, B31): the private address the courier collects sold
/// pieces from, its city or "Add", opening the saved-address picker; shown once the server
/// answers `GET /api/user/me/pickup-address`. Turning off takes listings and auctions without bids down (B34); the server
/// refuses (409) while an auction has bids or a sale is going through, and its message is shown.
class SellingSettingsPage extends StatefulWidget {
  const SellingSettingsPage({super.key, this.debugTurnOff, this.debugSellerTerms});

  /// For tests: what Turn off seller profile calls, instead of the server.
  @visibleForTesting
  final Future<void> Function()? debugTurnOff;

  /// For tests: the seller terms instead of loading them.
  @visibleForTesting
  final SellerTerms? debugSellerTerms;

  @override
  State<SellingSettingsPage> createState() => _SellingSettingsPageState();
}

class _SellingSettingsPageState extends State<SellingSettingsPage> {
  bool _busy = false;

  /// The rates line under Seller terms, once the server sent them.
  String? _rates;

  /// The pickup address; [_pickupKnown] once the server answered (an older server has none,
  /// and the row stays hidden).
  Address? _pickup;
  bool _pickupKnown = false;

  @override
  void initState() {
    super.initState();
    final given = widget.debugSellerTerms;
    if (given != null) {
      _rates = given.summary;
    } else {
      _loadTerms();
    }
    _loadPickup();
  }

  Future<void> _loadPickup() async {
    try {
      final pickup = await AddressService.instance.getPickupAddress();
      if (mounted) {
        setState(() {
          _pickup = pickup;
          _pickupKnown = true;
        });
      }
    } catch (_) {
      // No row.
    }
  }

  Future<void> _choosePickup() async {
    final saved = await choosePickupAddress(context, current: _pickup);
    if (saved != null && mounted) setState(() => _pickup = saved);
  }

  Future<void> _loadTerms() async {
    try {
      final terms = await UserService.instance.getSellerTerms();
      if (mounted) setState(() => _rates = terms.summary);
    } catch (_) {
      // "Includes fees" stays.
    }
  }

  Future<void> _turnOff() async {
    if (_busy) return;
    final confirmed = await showStudioConfirm(
      context,
      title: 'Turn off seller profile?',
      message: 'Your listings and auctions without bids will come down. Pieces stay on your profile as not for sale.',
      confirmLabel: 'Turn off',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await (widget.debugTurnOff ?? UserService.instance.disableSeller)();
      if (!mounted) return;
      showStudioToast(context, 'Seller profile is off');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showStudioToast(context, 'Could not turn off your seller profile.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Selling'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          // The status line: an 8 green dot, 8 apart, 14; 14 above and below, a Line under.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Seller profile is on', style: StudioType.body14(color: c.textPrimary)),
              ],
            ),
          ),
          const SettingsSectionLabel('Studio', top: 26),
          SettingsRow(
            label: 'Seller terms',
            subtitle: _rates ?? 'Includes fees',
            onTap: () => Navigator.pushNamed(context, '/terms'),
          ),
          if (_pickupKnown)
            SettingsRow(
              label: 'Pickup address',
              subtitle: 'Where the courier collects sold pieces. Only you see it.',
              value: _pickup == null || _pickup!.city.trim().isEmpty ? 'Add' : _pickup!.city,
              onTap: _choosePickup,
            ),
          const SizedBox(height: 24),
          SettingsRow(
            label: 'Turn off seller profile',
            subtitle: 'Your listings and auctions without bids will come down.',
            chevron: false,
            onTap: _busy ? null : _turnOff,
          ),
        ],
      ),
    );
  }
}

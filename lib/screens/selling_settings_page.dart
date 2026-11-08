import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';

/// Selling (`SettingsSelling`, Flow 12), for seller profiles: a green dot and "Seller profile is
/// on"; Studio: Seller terms ("Includes fees", the seller terms page); then Turn off seller
/// profile ("Your listings come down. Pieces stay on your profile."), which asks first. Pops
/// true once selling is off.
///
/// The board's Studio address row (the private pickup address, with its "Where your sold pieces
/// ship from." tooltip) waits on BACKEND_CHANGES B31, on hold with the other shipping work, so it
/// isn't shown. Turning off is refused by the server while anything is still listed or a sale is
/// in progress, and its message is shown; taking listings down for the seller is B34.
class SellingSettingsPage extends StatefulWidget {
  const SellingSettingsPage({super.key, this.debugTurnOff});

  /// For tests: what Turn off seller profile calls, instead of the server.
  @visibleForTesting
  final Future<void> Function()? debugTurnOff;

  @override
  State<SellingSettingsPage> createState() => _SellingSettingsPageState();
}

class _SellingSettingsPageState extends State<SellingSettingsPage> {
  bool _busy = false;

  Future<void> _turnOff() async {
    if (_busy) return;
    final confirmed = await showStudioConfirm(
      context,
      title: 'Turn off seller profile?',
      message: 'Your listings come down. Pieces stay on your profile as not for sale.',
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
            subtitle: 'Includes fees',
            onTap: () => Navigator.pushNamed(context, '/terms'),
          ),
          const SizedBox(height: 24),
          SettingsRow(
            label: 'Turn off seller profile',
            subtitle: 'Your listings come down. Pieces stay on your profile.',
            chevron: false,
            onTap: _busy ? null : _turnOff,
          ),
        ],
      ),
    );
  }
}

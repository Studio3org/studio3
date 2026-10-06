import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/payout_service.dart';
import '../widgets/seller_mode_required_dialog.dart';

/// True when the piece API rejected a listing because Connect is incomplete.
bool isPayoutSetupRequiredMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('payout setup') || lower.contains('finish payout');
}

/// Ensures the signed-in user can list a piece for sale.
///
/// Seller mode first, then Connect `canListForSale`. Returns true only after
/// a fresh status fetch says they can be paid.
Future<bool> ensureCanListForSale(BuildContext context) async {
  if (!AuthSession.instance.sellerEnabled) {
    final switchToSeller = await showSellerModeRequiredDialog(context);
    if (switchToSeller != true || !context.mounted) return false;
    await Navigator.pushNamed(context, '/profile-settings');
    if (!context.mounted) return false;
    if (!AuthSession.instance.sellerEnabled) return false;
  }

  try {
    final status = await PayoutService.instance.getStatus();
    if (status.canListForSale) return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    if (e.statusCode == 403) {
      final switchToSeller = await showSellerModeRequiredDialog(context);
      if (switchToSeller != true || !context.mounted) return false;
      await Navigator.pushNamed(context, '/profile-settings');
      if (!context.mounted) return false;
      if (!AuthSession.instance.sellerEnabled) return false;
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not check payout setup.')),
    );
    return false;
  }

  if (!context.mounted) return false;
  await Navigator.pushNamed(context, '/payout-setup');
  if (!context.mounted) return false;

  try {
    final status = await PayoutService.instance.getStatus();
    return status.canListForSale;
  } catch (_) {
    return AuthSession.instance.canListForSale == true;
  }
}

/// Opens the details-required page when a listing call 403s for payouts.
Future<void> openPayoutSetup(BuildContext context) {
  return Navigator.pushNamed(context, '/payout-setup');
}

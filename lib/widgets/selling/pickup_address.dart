import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../piece_detail/collect_shipping_sheet.dart';
import '../studio/studio_toast.dart';

/// Picks the artist's pickup address (FRONTEND_HANDOFF 8.1, B31): the saved-address picker
/// titled "Pickup address", then `PUT /api/user/me/pickup-address`. The server's 400s ("US
/// only", "Add a phone number…") are toasted as they are. Returns the address once it is set.
Future<Address?> choosePickupAddress(
  BuildContext context, {
  Address? current,
  @visibleForTesting Future<Address?> Function(BuildContext context)? debugPick,
}) async {
  final picked = debugPick != null
      ? await debugPick(context)
      : await CollectShippingSheet.show(context, initial: current, title: 'Pickup address');
  if (picked == null || !context.mounted) return null;
  try {
    final saved = await AddressService.instance.setPickupAddress(picked.id);
    if (context.mounted) showStudioToast(context, 'Pickup address saved');
    return saved ?? picked;
  } on ApiException catch (e) {
    if (context.mounted) showStudioToast(context, e.message, icon: null, duration: const Duration(seconds: 5));
  } catch (_) {
    if (context.mounted) showStudioToast(context, "Couldn't save the pickup address.", icon: null);
  }
  return null;
}

/// Whether a listing refusal names the pickup address (8.1: "To sell this piece, add its …
/// pickup address (Settings, Selling).").
bool mentionsPickupAddress(String message) => message.toLowerCase().contains('pickup address');

/// A refused listing: the server's message as it is; when it names the pickup address, the
/// toast offers to set it there and then.
void showListingError(BuildContext context, String message) {
  final pickup = mentionsPickupAddress(message);
  showStudioToast(
    context,
    message,
    icon: null,
    duration: const Duration(seconds: 6),
    actionLabel: pickup ? 'Pickup address' : null,
    onAction: pickup
        ? () {
            if (context.mounted) choosePickupAddress(context);
          }
        : null,
  );
}

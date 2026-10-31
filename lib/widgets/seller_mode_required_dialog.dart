import 'package:flutter/material.dart';

import 'studio/studio_sheet.dart';

/// Returns `true` if user chose Switch to Seller, `false` for Cancel.
Future<bool?> showSellerModeRequiredDialog(BuildContext context) {
  return showStudioConfirm(
    context,
    title: 'Seller profile required',
    message: 'To list a piece for sale, switch to a seller profile in Settings.',
    confirmLabel: 'Switch to Seller',
  );
}

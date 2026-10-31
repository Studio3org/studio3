import 'package:flutter/material.dart';

import 'studio/studio_sheet.dart';

/// "Delete [itemLabel]?" as a confirm sheet. Returns `true` if the user confirmed deletion,
/// `false` otherwise.
Future<bool?> showDeleteConfirmationDialog(
  BuildContext context, {
  required String itemLabel,
}) {
  return showStudioConfirm(
    context,
    title: 'Delete $itemLabel?',
    message: "This can't be undone. Your $itemLabel will be permanently removed.",
    confirmLabel: 'Delete',
  );
}

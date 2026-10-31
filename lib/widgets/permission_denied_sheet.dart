import 'package:flutter/material.dart';

import '../services/permission_service.dart';
import 'studio/studio_sheet.dart';

/// Shown only when a permission is permanently denied — offers a direct
/// path to Settings instead of re-prompting the OS dialog (which iOS/
/// Android will no longer show once permanently denied).
Future<void> showPermissionDeniedSheet(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final open = await showStudioConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: 'Open Settings',
    cancelLabel: 'Not now',
  );
  if (open) await PermissionService.instance.openSettings();
}

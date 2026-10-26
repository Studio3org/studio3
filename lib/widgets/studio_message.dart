import 'package:flutter/material.dart';

import 'studio/studio_icon.dart';
import 'studio/studio_toast.dart';

/// A short message that doesn't interrupt what's on screen (event save/RSVP failures, form
/// validation nudges). Now the shared toast ([showStudioToast]): a check for confirmations, no
/// icon for errors. For a failure big enough to stop a whole flow (e.g. an event failing to
/// publish), prefer a full-screen result overlay instead.
abstract final class StudioMessage {
  static void show(BuildContext context, String message, {bool isError = true}) {
    showStudioToast(context, message, icon: isError ? null : StudioIcons.check);
  }
}

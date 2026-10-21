import 'package:flutter/foundation.dart';

/// Bridges profile (and other overlays) back to `MainShell`'s Home tab.
class MainNavService {
  MainNavService._();
  static final instance = MainNavService._();

  VoidCallback? _goHome;
  VoidCallback? _goSaved;

  void register({required VoidCallback goHome, required VoidCallback goSaved}) {
    _goHome = goHome;
    _goSaved = goSaved;
  }

  void unregister() {
    _goHome = null;
    _goSaved = null;
  }

  /// Returns true if a mounted `MainShell` switched to Home.
  bool goHome() {
    final handler = _goHome;
    if (handler == null) return false;
    handler();
    return true;
  }

  /// Returns true if a mounted `MainShell` switched to Saved.
  bool goSaved() {
    final handler = _goSaved;
    if (handler == null) return false;
    handler();
    return true;
  }
}

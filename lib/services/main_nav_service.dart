import 'package:flutter/foundation.dart';

/// Bridges profile (and other overlays) back to `MainShell`'s Home tab.
class MainNavService {
  MainNavService._();
  static final instance = MainNavService._();

  VoidCallback? _goHome;
  VoidCallback? _goSaved;
  VoidCallback? _goExplore;
  VoidCallback? _goProfile;

  void register({
    required VoidCallback goHome,
    required VoidCallback goSaved,
    VoidCallback? goExplore,
    VoidCallback? goProfile,
  }) {
    _goHome = goHome;
    _goSaved = goSaved;
    _goExplore = goExplore;
    _goProfile = goProfile;
  }

  void unregister() {
    _goHome = null;
    _goSaved = null;
    _goExplore = null;
    _goProfile = null;
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

  /// Returns true if a mounted `MainShell` switched to the viewer's own Profile.
  bool goProfile() {
    final handler = _goProfile;
    if (handler == null) return false;
    handler();
    return true;
  }

  /// Returns true if a mounted `MainShell` switched to Explore.
  bool goExplore() {
    final handler = _goExplore;
    if (handler == null) return false;
    handler();
    return true;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/studio_colors.dart';

/// Light / Dark only (plan D6). Stored on the device so the last choice shows
/// before sign-in, offline, and after log out. A signed-in account's server
/// value replaces it (see [applyServerValue]).
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'theme_preference';

  ThemeMode mode = ThemeMode.light;

  String get preference => mode == ThemeMode.dark ? 'dark' : 'light';

  bool get isDark => mode == ThemeMode.dark;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    mode = prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _applyOverlay();
  }

  /// Server wins. A missing choice (`null`) is light.
  Future<void> applyServerValue(Object? raw) async {
    await setMode(raw == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setMode(ThemeMode next) async {
    final resolved = next == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    final previous = mode;
    mode = resolved;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, preference);
    } catch (_) {
      mode = previous;
      rethrow;
    }
    _applyOverlay();
    if (previous != resolved) notifyListeners();
  }

  SystemUiOverlayStyle get overlay {
    final colors = isDark ? StudioColors.dark : StudioColors.light;
    final base = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: colors.background,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  void _applyOverlay() {
    SystemChrome.setSystemUIOverlayStyle(overlay);
  }
}

/// What the phone's back button does on the app's main screen (the user's call, 2026-11-08,
/// as on Instagram). Pages opened on top (a piece, a profile, settings, posting) handle their
/// own back first; this only runs when the tabs themselves are showing.
///
/// - On any tab but Home (Explore, Scenes, Saved, Events, your Profile): go to Home.
/// - On Home: the first back scrolls the feed to the very top and refreshes it; the next back,
///   with the feed still at the top, closes the app. Scrolling down again, or leaving Home,
///   starts over.
enum ShellBackAction { goHome, refreshHome, exit }

class ShellBack {
  bool _armed = false;

  /// Whether the next back on Home (at the top) closes the app.
  bool get armed => _armed;

  ShellBackAction onBack({required bool onHome, required bool homeAtTop}) {
    if (!onHome) {
      _armed = false;
      return ShellBackAction.goHome;
    }
    if (_armed && homeAtTop) return ShellBackAction.exit;
    _armed = true;
    return ShellBackAction.refreshHome;
  }

  /// Leaving Home (a tab tap or a swipe) starts over.
  void reset() => _armed = false;
}

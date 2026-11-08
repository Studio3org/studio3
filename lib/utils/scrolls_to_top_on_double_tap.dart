import 'package:flutter/widgets.dart';

/// Implemented by a top-level page's `State` so `MainShell` can tell it to
/// scroll to top and refresh when its bottom-nav icon is double-tapped
/// (Instagram convention).
mixin ScrollsToTopOnDoubleTap<T extends StatefulWidget> on State<T> {
  void scrollToTopAndRefresh();

  /// Whether the page is scrolled to the very top (the phone's back on Home closes the app
  /// only from there; `ShellBack`).
  bool get isScrolledToTop => true;
}

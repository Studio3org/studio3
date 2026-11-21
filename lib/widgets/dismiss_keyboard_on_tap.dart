import 'package:flutter/material.dart';

/// The keyboard is open only while the cursor is in a text field, on every screen, sheet and
/// dialog (it wraps the whole app, above the navigator). It closes when:
///
/// - **a tap lands anywhere but a text field.** A field, button or link under the finger
///   takes the tap as before (it wins the gesture), so a button never loses its tap;
/// - **a finger starts scrolling a page or list** (as in Instagram). Scrolling *inside* a text
///   field (a long caption) doesn't count, nor does the app scrolling by itself (bringing
///   the field into view when the keyboard opens, jumping to an error): those carry no drag.
///
/// Only text focus is dropped, so other focus (hardware keyboard navigation) is left alone.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  static void dismiss() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) return;
    final editing = context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null;
    if (editing) focus!.unfocus();
  }

  /// A scroll a finger started, outside any text field.
  static bool _isUserScroll(ScrollStartNotification n) {
    if (n.dragDetails == null) return false;
    final scrolled = n.context;
    return scrolled == null || scrolled.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) {
        if (_isUserScroll(n)) dismiss();
        return false; // let the scroll carry on to everyone else
      },
      child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: dismiss, child: child),
    );
  }
}

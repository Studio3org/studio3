import 'package:flutter/material.dart';

/// Ensures a newly pushed route paints from the top of its scroll views.
class OpenAtTopObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _jumpRouteToTop(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _jumpRouteToTop(newRoute);
  }

  void _jumpRouteToTop(Route<dynamic> route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route is! ModalRoute) return;
      final context = route.subtreeContext;
      if (context == null || !context.mounted) return;
      void visit(Element element) {
        if (element.widget is Scrollable) {
          final state = element is StatefulElement ? element.state : null;
          if (state is ScrollableState) {
            final position = state.position;
            if (position.hasContentDimensions &&
                position.pixels > position.minScrollExtent) {
              position.jumpTo(position.minScrollExtent);
            }
          }
        }
        element.visitChildren(visit);
      }

      context.visitChildElements(visit);
    });
  }
}

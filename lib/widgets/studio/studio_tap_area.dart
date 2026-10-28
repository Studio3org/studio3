import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/studio_metrics.dart';

/// Makes [child] answer taps, and VoiceOver / TalkBack, over at least 44 × 44 without changing
/// its size or the layout around it (plan rule 8 and `HandoffRules`: 44 × 44 tap targets, while
/// the boards draw some controls smaller, such as the 34 Follow, the 36 chips or a 32 avatar).
///
/// The extra area is centred on the child. Taps in it go to the child; the accessibility node
/// covers it too. Only the part inside the parent's own bounds can be hit, as with any widget.
class StudioTapArea extends SingleChildRenderObjectWidget {
  const StudioTapArea({
    super.key,
    super.child,
    this.minSize = const Size(StudioSize.tapTarget, StudioSize.tapTarget),
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStudioTapArea(minSize);

  @override
  void updateRenderObject(BuildContext context, _RenderStudioTapArea renderObject) {
    renderObject.minSize = minSize;
  }
}

class _RenderStudioTapArea extends RenderProxyBox {
  _RenderStudioTapArea(this._minSize);

  Size _minSize;
  set minSize(Size value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsSemanticsUpdate();
  }

  Rect get _area {
    final dx = math.max(0.0, (_minSize.width - size.width) / 2);
    final dy = math.max(0.0, (_minSize.height - size.height) / 2);
    return Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_area.contains(position)) return false;
    final child = this.child;
    if (child == null) return false;
    // A tap in the extra area goes to the nearest point of the child.
    final inside = Offset(
      position.dx.clamp(0.0, math.max(0.0, size.width - 0.5)),
      position.dy.clamp(0.0, math.max(0.0, size.height - 0.5)),
    );
    final hit = result.addWithPaintOffset(
      offset: Offset.zero,
      position: inside,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  Rect get semanticBounds => _area;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Its own node, so the larger bounds are the ones VoiceOver and TalkBack use.
    config.isSemanticBoundary = true;
  }
}

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';

/// Field tooltip (`HandoffRules` "Tooltips", `PostDetailsForSale`): a dark box 8 below the
/// field, as wide as it, radius 12, 12 14 padding, 13 / 1.45 text, arrow 24 from the left.
/// Tap anywhere closes it, and only one is open at a time. Anything everyone needs must
/// also be shown inline, never only here.
///
/// ```dart
/// StudioTooltip(
///   message: 'Used only to get shipping quotes.',
///   builder: (context, toggle) => StudioUnderlineField(
///     label: 'Weight',
///     labelTrailing: StudioInfoButton(onTap: toggle, semanticLabel: 'What is weight?'),
///   ),
/// )
/// ```
class StudioTooltip extends StatefulWidget {
  const StudioTooltip({
    super.key,
    required this.message,
    required this.builder,
    this.arrowLeft = 24,
  });

  final String message;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;
  final double arrowLeft;

  @override
  State<StudioTooltip> createState() => _StudioTooltipState();
}

class _StudioTooltipState extends State<StudioTooltip> {
  static _StudioTooltipState? _open;

  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _region = Object();
  double _width = 0;

  void _toggle() => _portal.isShowing ? _hide() : _show();

  void _show() {
    if (_open != this) _open?._hide();
    _open = this;
    setState(_portal.show);
  }

  void _hide() {
    if (_open == this) _open = null;
    if (mounted && _portal.isShowing) setState(_portal.hide);
  }

  @override
  void dispose() {
    if (_open == this) _open = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: TapRegion(
            groupId: _region,
            onTapInside: (_) => _hide(),
            child: SizedBox(
              width: _width,
              child: StudioTooltipBox(message: widget.message, arrowLeft: widget.arrowLeft),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: TapRegion(
          groupId: _region,
          onTapOutside: (_) => _hide(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth;
              return widget.builder(context, _toggle);
            },
          ),
        ),
      ),
    );
  }
}

/// The tooltip's box and arrow on their own (also used by the component gallery).
class StudioTooltipBox extends StatelessWidget {
  const StudioTooltipBox({super.key, required this.message, this.arrowLeft = 24});

  final String message;
  final double arrowLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      liveRegion: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.tooltipFill,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x2E111111), offset: Offset(0, 10), blurRadius: 30),
              ],
            ),
            child: Text(message, style: StudioType.sans(13, height: 1.45, color: c.tooltipText)),
          ),
          Positioned(
            top: -6,
            left: arrowLeft,
            child: Transform.rotate(
              angle: 0.7853981633974483, // 45°
              child: SizedBox(width: 12, height: 12, child: ColoredBox(color: c.tooltipFill)),
            ),
          ),
        ],
      ),
    );
  }
}

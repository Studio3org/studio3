import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';

/// Likes on a piece page: no Like or Comment buttons. A double tap on the image likes the
/// piece, and another double tap takes the like back; a white heart bursts in the middle each
/// time (filled for a like, outline for taking it back). Each visit opens with a hint over the
/// image, a heart and "Double tap to like", that fades away, as on a reel.
///
/// A single tap still reaches [child] (the picture opens full screen), after the double-tap
/// wait. Screen readers get Like / Unlike as an action on the image.
class PieceDoubleTapLike extends StatefulWidget {
  const PieceDoubleTapLike({
    super.key,
    required this.liked,
    required this.onToggle,
    required this.child,
    this.showHint = true,
  });

  /// Whether the viewer likes the piece now.
  final bool liked;

  /// Likes or unlikes (may ask them to log in first). The burst follows what [liked] becomes.
  final Future<void> Function() onToggle;

  final Widget child;

  /// The "Double tap to like" hint when the page opens.
  final bool showHint;

  /// How long the hint stays before it fades.
  static const hintHold = Duration(milliseconds: 1800);

  @override
  State<PieceDoubleTapLike> createState() => PieceDoubleTapLikeState();
}

class PieceDoubleTapLikeState extends State<PieceDoubleTapLike> with TickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _burstLiked = true;

  bool _hintVisible = false;
  Timer? _hintIn;
  Timer? _hintOut;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.showHint) {
      // A moment after the page settles, then gone on its own.
      _hintIn = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _hintVisible = true);
        _hintOut = Timer(PieceDoubleTapLike.hintHold, _hideHint);
      });
    }
  }

  @override
  void dispose() {
    _hintIn?.cancel();
    _hintOut?.cancel();
    _burst.dispose();
    super.dispose();
  }

  void _hideHint() {
    _hintIn?.cancel();
    _hintOut?.cancel();
    if (mounted && _hintVisible) setState(() => _hintVisible = false);
  }

  /// While a double tap's toggle runs, the first change to [PieceDoubleTapLike.liked] is
  /// what it did (the like is shown at once, before the server answers), so that change
  /// bursts. A later roll-back after a failure doesn't.
  Future<void> _toggle() async {
    _hideHint();
    if (_busy) return;
    _busy = true;
    _pendingFrom = widget.liked;
    try {
      await widget.onToggle();
    } finally {
      _busy = false;
      // Wait for the frame that shows the change, then stop listening for one.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _pendingFrom = null);
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  /// [PieceDoubleTapLike.liked] when the double tap came; null when none is waiting.
  bool? _pendingFrom;

  @override
  void didUpdateWidget(covariant PieceDoubleTapLike oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = _pendingFrom;
    if (from != null && widget.liked != from) {
      _pendingFrom = null;
      _burstLiked = widget.liked;
      _burst.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.liked ? 'Unlike' : 'Like'): _toggle,
      },
      child: GestureDetector(
        onDoubleTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            IgnorePointer(
              child: AnimatedOpacity(
                key: const ValueKey('double-tap-hint'),
                opacity: _hintVisible ? 1 : 0,
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                child: const Center(child: _Hint()),
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) {
                  final t = _burst.value;
                  if (!_burst.isAnimating && (t == 0 || t == 1)) return const SizedBox.shrink();
                  // Pops in (0–20 %), holds, fades out (60–100 %).
                  final scale = reduceMotion ? 1.0 : (t < 0.2 ? 0.6 + 2.5 * t : 1.1 - 0.1 * ((t - 0.2) / 0.8));
                  final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: StudioIcon(
                          _burstLiked ? StudioIcons.liked : StudioIcons.like,
                          key: ValueKey(_burstLiked ? 'burst-liked' : 'burst-unliked'),
                          size: 96,
                          color: StudioColors.galleryWhite,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heart and "Double tap to like" on a soft dark pill, readable on any picture.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StudioIcon(StudioIcons.liked, size: 36, color: StudioColors.galleryWhite),
          const SizedBox(height: 8),
          Text(
            'Double tap to like',
            style: StudioType.body14(weight: StudioType.medium, color: StudioColors.galleryWhite),
          ),
        ],
      ),
    );
  }
}

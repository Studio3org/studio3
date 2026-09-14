import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../theme/home_feed_tokens.dart';

const Color kSceneVideoTrackFill = Color(0xFFE8E6DF);
const Color kSceneVideoTrimOrange = Color(0xFFC4541E);

/// Figma trim bar: 32px cream track with orange 2px edge bars on the selection.
class SceneVideoTrimTrack extends StatelessWidget {
  const SceneVideoTrimTrack({
    super.key,
    required this.startFraction,
    required this.endFraction,
    required this.onChanged,
  });

  final double startFraction;
  final double endFraction;
  final void Function(double start, double end) onChanged;

  static const _minSpan = 0.05;
  static const _handleHit = 28.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startX = startFraction.clamp(0.0, 1.0) * width;
        final endX = endFraction.clamp(0.0, 1.0) * width;
        return SizedBox(
          height: 32,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: kSceneVideoTrackFill,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                left: startX,
                width: (endX - startX).clamp(4.0, width),
                top: 0.5,
                bottom: 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: kSceneVideoTrimOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              _edgeHandle(
                left: startX - _handleHit / 2,
                onDrag: (dx) {
                  final next = ((startX + dx) / width).clamp(
                    0.0,
                    endFraction - _minSpan,
                  );
                  onChanged(next, endFraction);
                },
              ),
              _edgeHandle(
                left: endX - _handleHit / 2,
                onDrag: (dx) {
                  final next = ((endX + dx) / width).clamp(
                    startFraction + _minSpan,
                    1.0,
                  );
                  onChanged(startFraction, next);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _edgeHandle({
    required double left,
    required void Function(double dx) onDrag,
  }) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: _handleHit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      ),
    );
  }
}

/// Figma cover scrubber: cream track with an 8px orange double-line playhead.
class SceneVideoPlayheadTrack extends StatelessWidget {
  const SceneVideoPlayheadTrack({
    super.key,
    required this.fraction,
    required this.onChanged,
  });

  final double fraction;
  final ValueChanged<double> onChanged;

  static const _handleWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final x = fraction.clamp(0.0, 1.0) * width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            onChanged((details.localPosition.dx / width).clamp(0.0, 1.0));
          },
          onHorizontalDragUpdate: (details) {
            onChanged(((x + details.delta.dx) / width).clamp(0.0, 1.0));
          },
          child: SizedBox(
            height: 32,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: kSceneVideoTrackFill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: x - _handleWidth / 2,
                  top: 0.5,
                  bottom: 0.5,
                  width: _handleWidth,
                  child: Row(
                    children: [
                      Container(width: 2, color: kSceneVideoTrimOrange),
                      const Spacer(),
                      Container(width: 2, color: kSceneVideoTrimOrange),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SceneVideoMuteSwitch extends StatelessWidget {
  const SceneVideoMuteSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 33,
        height: 17,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: value ? HomeFeedTokens.textPrimary : const Color(0xFFC8C5BC),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAF7),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}

class SceneVideoFlowBanner extends StatelessWidget {
  const SceneVideoFlowBanner({
    super.key,
    required this.topInset,
    required this.title,
    required this.actionLabel,
    required this.onBack,
    required this.onAction,
    this.processing = false,
  });

  final double topInset;
  final String title;
  final String actionLabel;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 53,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      PostMediaAssets.createBannerBack,
                      width: 7,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        HomeFeedTokens.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.geist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            actionLabel,
                            style: GoogleFonts.geist(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: onAction == null
                                  ? HomeFeedTokens.textSecondary
                                  : HomeFeedTokens.textPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

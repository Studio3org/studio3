import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Test-only replica of the `SavedEmpty` board, value for value from
/// docs/new-ui/reference/SavedEmpty.dc.html. It exists to prove the board-vs-app comparison
/// pipeline (plan section 0.4) can confirm a near-exact match; the real screen is built in
/// Phase 5 with the shared tokens and components, not from this file.
class SavedEmptyReplica extends StatelessWidget {
  const SavedEmptyReplica({super.key});

  static const _ink = Color(0xFF111111);
  static const _graphite = Color(0xFF6B6B6B);
  static const _galleryWhite = Color(0xFFFAFAF8);

  static const _back =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#111111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg>';
  static const _mark =
      '<svg viewBox="40 28 370 292"><circle cx="147" cy="213" r="102" fill="#E3E3E0"/><circle cx="305" cy="98" r="66" fill="#E3E3E0"/><circle cx="366" cy="220" r="40" fill="#E3E3E0"/></svg>';
  static const _arrow =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#111111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="M13 6l6 6-6 6"/></svg>';

  @override
  Widget build(BuildContext context) {
    const geist = 'Geist';
    return Container(
      width: 390,
      height: 844,
      color: _galleryWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header: padding 12px 8px 0; back 44×44 (22 px chevron) · "Saved" 16/500 · 44 spacer
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: SvgPicture.string(_back, width: 22, height: 22)),
                ),
                const Text(
                  'Saved',
                  style: TextStyle(fontFamily: geist, fontSize: 16, fontWeight: FontWeight.w500, color: _ink),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          // main: padding 200px 44px 0; centered column, gap 10
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 200, 44, 0),
            child: Column(
              spacing: 10,
              children: [
                SvgPicture.string(_mark, width: 76, height: 60),
                // h1: margin-top 18 (on top of the 10 gap), 22/400, letter-spacing -0.3
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Text(
                    'Nothing saved yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: geist,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
                      color: _ink,
                    ),
                  ),
                ),
                // p: 15 / line-height 1.5, Graphite
                const Text(
                  'Tap the bookmark on any piece to keep it here. Only you can see what you save.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: geist,
                    fontSize: 15,
                    height: 1.5,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: _graphite,
                  ),
                ),
                // link: margin-top 10, 44 tall, gap 6, 15/500 + 16 px arrow
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        const Text(
                          'Browse the feed',
                          style: TextStyle(fontFamily: geist, fontSize: 15, fontWeight: FontWeight.w500, color: _ink),
                        ),
                        SvgPicture.string(_arrow, width: 16, height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/studio_colors.dart';

/// Brand files in `assets/brand/` (made by tool/new_ui/make_wordmark.py). Each wordmark's
/// box is the CSS 1em line box, so drawing it at the board's font-size (40 or 27) as its
/// height puts every glyph where the board has it.
abstract final class StudioBrandAssets {
  static String mark({required bool white}) =>
      'assets/brand/logo_mark_${white ? 'white' : 'black'}.svg';
  static String signInWordmark({required bool white}) =>
      'assets/brand/wordmark_signin_${white ? 'white' : 'black'}.svg';
  static String headerWordmark({required bool white}) =>
      'assets/brand/wordmark_header_${white ? 'white' : 'black'}.svg';
}

enum _Lockup { signIn, header, mark }

/// The Studio 3 logo, black in light and white in dark (or forced with [onDark]).
///
/// * [StudioLogo.signIn]: the large centred lockup on `SignInFirst` — mark in a 279 × 261
///   box, 8 gap, 40 px wordmark in a 146 wide box.
/// * [StudioLogo.header]: the 27 px wordmark in the `Main` top bar.
/// * [StudioLogo.mark]: the three-circle mark alone.
class StudioLogo extends StatelessWidget {
  const StudioLogo.signIn({super.key, this.onDark}) : _lockup = _Lockup.signIn, markWidth = 279;

  const StudioLogo.header({super.key, this.onDark}) : _lockup = _Lockup.header, markWidth = 0;

  const StudioLogo.mark({super.key, this.markWidth = 76, this.onDark}) : _lockup = _Lockup.mark;

  final _Lockup _lockup;
  final double markWidth;

  /// Null follows the theme; true/false forces the white/black files.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final white = onDark ?? Theme.of(context).brightness == Brightness.dark;
    final Widget logo;
    switch (_lockup) {
      case _Lockup.signIn:
        logo = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // viewBox 370 × 292 drawn "meet" in 279 × 261: 279 × 220, centred.
            SizedBox(
              width: 279,
              height: 261,
              child: SvgPicture.asset(StudioBrandAssets.mark(white: white)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 146,
              height: 40,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: SvgPicture.asset(StudioBrandAssets.signInWordmark(white: white), height: 40),
              ),
            ),
          ],
        );
      case _Lockup.header:
        logo = SvgPicture.asset(StudioBrandAssets.headerWordmark(white: white), height: 27);
      case _Lockup.mark:
        logo = SvgPicture.asset(StudioBrandAssets.mark(white: white), width: markWidth);
    }
    return Semantics(label: 'Studio 3', image: true, excludeSemantics: true, child: logo);
  }
}

/// The grey three-circle mark used by empty states (`SavedEmpty`: 76 × 60, #E3E3E0).
class StudioMarkGrey extends StatelessWidget {
  const StudioMarkGrey({super.key, this.width = 76});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      StudioBrandAssets.mark(white: false),
      width: width,
      colorFilter: ColorFilter.mode(context.studio.line, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

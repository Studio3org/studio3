import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';

/// Section tabs as the boards draw them (`ProfileCollector`, `EvSavedEvents`): equal-width
/// 44 tall tabs, 14/500, Ink with a 2 px underline when active, tertiary otherwise, over a
/// 1 px Line rule, 20 from the sides. Wraps [TabBar], so it needs a [TabController] or a
/// [DefaultTabController] above it.
class StudioTabBar extends StatelessWidget implements PreferredSizeWidget {
  const StudioTabBar({super.key, required this.labels, this.controller});

  final List<String> labels;
  final TabController? controller;

  /// Tab height including its 2 px underline, as the boards' `border-box` tabs.
  static const double height = 44;
  static const double _indicator = 2;

  /// The tabs plus the 1 px rule under them.
  @override
  Size get preferredSize => const Size.fromHeight(height + 1);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.body14(weight: StudioType.medium);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // The rule sits under the tabs, outside their 44 (TabBar's own divider would
      // overlap the underline).
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: TabBar(
          controller: controller,
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textTertiary,
          labelStyle: style,
          unselectedLabelStyle: style,
          labelPadding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: _indicator,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: c.textPrimary, width: _indicator),
          ),
          dividerHeight: 0,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          // TabBar adds the indicator weight under each tab.
          tabs: [for (final label in labels) Tab(height: height - _indicator, text: label)],
        ),
      ),
    );
  }
}

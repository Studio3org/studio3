import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';

/// Section tabs as the boards draw them (`ProfileCollector`, `EvSavedEvents`): equal-width
/// 44 tall tabs, 14/500, Ink with a 2 px underline when active, tertiary otherwise, over a
/// 1 px Line rule, 20 from the sides. Wraps [TabBar], so it needs a [TabController] or a
/// [DefaultTabController] above it.
class StudioTabBar extends StatelessWidget implements PreferredSizeWidget {
  const StudioTabBar({
    super.key,
    required this.labels,
    this.controller,
    this.counts,
    this.ruleFullWidth = false,
  });

  final List<String> labels;
  final TabController? controller;

  /// A Mono 11 Graphite count after a label, 6 apart (`NotifActivity` "Messages 2"); null
  /// or 0 shows none.
  final List<int?>? counts;

  /// The 1 px rule runs edge to edge under 20-inset tabs (`NotifActivity`) instead of
  /// stopping at the inset.
  final bool ruleFullWidth;

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
    final rule = BoxDecoration(border: Border(bottom: BorderSide(color: c.line)));
    Widget tab(int i) {
      final count = counts == null || i >= counts!.length ? null : counts![i];
      if (count == null || count <= 0) {
        return Tab(height: height - _indicator, text: labels[i]);
      }
      return Tab(
        height: height - _indicator,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labels[i]),
            const SizedBox(width: 6),
            Text('$count', style: StudioType.mono11(color: c.textSecondary)),
          ],
        ),
      );
    }

    final bar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // The rule sits under the tabs, outside their 44 (TabBar's own divider would
      // overlap the underline).
      child: Container(
        decoration: ruleFullWidth ? null : rule,
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
          tabs: [for (var i = 0; i < labels.length; i++) tab(i)],
        ),
      ),
    );
    return ruleFullWidth ? DecoratedBox(decoration: rule, child: bar) : bar;
  }
}

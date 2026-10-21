import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../profile_constants.dart';

class ProfileTabs extends StatefulWidget {
  const ProfileTabs({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.showCollect = false,
    this.collectSegment = 'all',
    this.onCollectSegmentChanged,
  });

  final String currentTab;
  final ValueChanged<String> onTabChanged;
  final bool showCollect;
  final String collectSegment;
  final ValueChanged<String>? onCollectSegmentChanged;

  @override
  State<ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<ProfileTabs> {
  final _collectTabKey = GlobalKey();
  final _tabsBarKey = GlobalKey();
  bool _collectMenuOpen = false;

  Future<void> _openCollectFilterMenu() async {
    final collectBox =
        _collectTabKey.currentContext?.findRenderObject() as RenderBox?;
    final barBox = _tabsBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (collectBox == null || barBox == null || !mounted) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final collectRight = collectBox.localToGlobal(
      collectBox.size.topRight(Offset.zero),
      ancestor: overlay,
    );
    final barBottom = barBox.localToGlobal(
      barBox.size.bottomLeft(Offset.zero),
      ancestor: overlay,
    );

    setState(() => _collectMenuOpen = true);
    widget.onTabChanged('collect');
    final selected = await showCollectFilterMenu(
      context: context,
      right: collectRight.dx,
      top: barBottom.dy + 9,
      currentSegment: widget.collectSegment,
    );
    if (!mounted) return;
    setState(() => _collectMenuOpen = false);

    if (selected != null) {
      widget.onTabChanged('collect');
      widget.onCollectSegmentChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <({String id, String label})>[
      (id: 'pieces', label: 'Pieces'),
      (id: 'scenes', label: 'Scenes'),
      (id: 'series', label: 'Series'),
      if (widget.showCollect) (id: 'collect', label: 'Collect'),
    ];

    final c = context.studio;
    return ColoredBox(
      key: _tabsBarKey,
      color: c.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kProfileHorizontalPad, 18, kProfileHorizontalPad, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: tab.id == 'collect'
                      ? _CollectTabItem(
                          key: _collectTabKey,
                          active: widget.currentTab == tab.id,
                          menuOpen: _collectMenuOpen,
                          onTabTap: () {
                            if (widget.currentTab == 'collect') {
                              _openCollectFilterMenu();
                            } else {
                              widget.onTabChanged(tab.id);
                            }
                          },
                          onFilterTap: _openCollectFilterMenu,
                        )
                      : _TabItem(
                          label: tab.label,
                          active: widget.currentTab == tab.id,
                          onTap: () => widget.onTabChanged(tab.id),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma 2652:2859 — Collect filter list under the Collect tab.
Future<String?> showCollectFilterMenu({
  required BuildContext context,
  required double right,
  required double top,
  required String currentSegment,
}) {
  const menuWidth = 168.0;

  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Collect filter',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      var left = right - menuWidth;
      left = left.clamp(10.0, screenWidth - menuWidth - 10.0);

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: _CollectFilterMenu(
                currentSegment: currentSegment,
                onSelected: (value) => Navigator.pop(context, value),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CollectFilterMenu extends StatelessWidget {
  const _CollectFilterMenu({
    required this.currentSegment,
    required this.onSelected,
  });

  final String currentSegment;
  final ValueChanged<String> onSelected;

  static const _options = [
    (id: 'all', label: 'All'),
    (id: 'available', label: 'Available'),
    (id: 'sold', label: 'Sold'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(StudioRadius.button),
          border: Border.all(color: c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in _options)
                _CollectFilterOption(
                  label: option.label,
                  selected: currentSegment == option.id,
                  onTap: () => onSelected(option.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectFilterOption extends StatelessWidget {
  const _CollectFilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.body14(
                weight: selected ? StudioType.medium : StudioType.regular,
                color: selected ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.body14(
                weight: StudioType.medium,
                color: active ? c.textPrimary : c.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectTabItem extends StatelessWidget {
  const _CollectTabItem({
    super.key,
    required this.active,
    required this.menuOpen,
    required this.onTabTap,
    required this.onFilterTap,
  });

  final bool active;
  final bool menuOpen;
  final VoidCallback onTabTap;
  final VoidCallback onFilterTap;

  static const _chevronAsset = 'assets/profile/icon_collect_chevron.svg';

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final labelColor = active ? c.textPrimary : c.textTertiary;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? c.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onTabTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Collect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.body14(weight: StudioType.medium, color: labelColor),
                ),
              ),
            ),
            GestureDetector(
              onTap: onFilterTap,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 28,
                height: 44,
                child: Center(
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: menuOpen ? 0.5 : 0,
                    child: SvgPicture.asset(
                      _chevronAsset,
                      width: 8,
                      height: 4,
                      colorFilter: ColorFilter.mode(labelColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

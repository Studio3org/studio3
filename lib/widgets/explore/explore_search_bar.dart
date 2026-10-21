import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';

/// Explore search pill: 48 tall, round, surface fill, 20 icon, 15 placeholder.
class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({
    super.key,
    this.controller,
    this.onChanged,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      key: const Key('explore-search'),
      height: 48,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StudioRadius.round),
      ),
      padding: const EdgeInsets.symmetric(horizontal: StudioSpace.s16),
      child: Row(
        children: [
          StudioIcon(StudioIcons.search, size: 20, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: 1,
              cursorColor: c.textPrimary,
              textAlignVertical: TextAlignVertical.center,
              style: StudioType.body15(color: c.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Search artists, pieces, events',
                hintStyle: StudioType.body15(color: c.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

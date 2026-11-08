import 'package:flutter/material.dart';

import '../../../theme/studio_colors.dart';
import '../../../theme/studio_type.dart';
import '../profile_constants.dart';

/// The profile's tabs (`HandoffProfiles`, `ProfileSeller`, `ProfileCollector`): Pieces, Scenes
/// and Collection for everyone, evenly spaced and always shown. 44 tall, 14/500, the active one
/// Ink with a 2 Ink underline, the others grey; a hairline under the row, 18 below the header.
/// Series are the shelf at the top of Pieces; Collection is what they've bought.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  /// `pieces`, `scenes` or `collection`.
  final String currentTab;
  final ValueChanged<String> onTabChanged;

  static const tabs = <({String id, String label})>[
    (id: 'pieces', label: 'Pieces'),
    (id: 'scenes', label: 'Scenes'),
    (id: 'collection', label: 'Collection'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return ColoredBox(
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
                  child: _TabItem(
                    label: tab.label,
                    active: currentTab == tab.id,
                    onTap: () => onTabChanged(tab.id),
                  ),
                ),
            ],
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
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
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
      ),
    );
  }
}

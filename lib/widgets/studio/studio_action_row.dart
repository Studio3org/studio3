import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import 'studio_avatar.dart';
import 'studio_icon.dart';

/// A row in an actions sheet (`ConvMenu`): 22 px outline icon, 14 gap, title 16 with an
/// optional 12 Graphite line under it, 14 above and below, 1 px Line under the row. Ink
/// for every action, Block and Report included: no red outside status (`HandoffRules`).
class StudioActionRow extends StatelessWidget {
  const StudioActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              StudioIcon(icon, size: 22, color: c.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: StudioType.sans(16, color: c.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: StudioType.caption12(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// The person header at the top of an actions sheet (`ConvMenu`): 40 avatar, 12 gap,
/// name 16/500 over handle 12 Graphite, 8 below.
class StudioActionSheetPerson extends StatelessWidget {
  const StudioActionSheetPerson({
    super.key,
    required this.name,
    required this.handle,
    this.avatarUrl,
  });

  final String name;
  final String handle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          StudioAvatar(url: avatarUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.caption12(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

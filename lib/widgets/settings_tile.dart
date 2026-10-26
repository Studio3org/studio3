import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import 'studio/studio_icon.dart';
import 'studio/studio_switch.dart';

/// A section label in Settings-family screens (as `NotifSettings`): Mono 11/500 Tertiary caps,
/// 22 above and 2 below.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key, this.top = 22});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(11, weight: StudioType.medium, color: context.studio.textTertiary)
            .copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// A Settings row (no board; the `NotifSettings` row and the checkout rows): label 15 Ink with
/// an optional 12 Graphite line under it, a 16 chevron (or [trailing]), 14 above and below and
/// a 1 px Line under. Every action is Ink, Log out and Delete included (`HandoffRules`).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.chevron = true,
  });

  final String label;
  final String? subtitle;

  /// Null makes the row inert — no navigation. Used while a row's destination depends on
  /// state that hasn't loaded yet.
  final VoidCallback? onTap;

  /// Replaces the chevron (e.g. a status word or a loading bar).
  final Widget? trailing;

  /// False for actions that open nothing (Log out).
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: StudioType.sans(15, color: c.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: StudioType.caption12(height: 1.45, color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  (chevron
                      ? StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Settings switch row: label 15 (and an optional 12 line) with the [StudioSwitch] on the
/// right; 14 above and below, 1 px Line under (`NotifSettings`).
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StudioType.sans(15, color: c.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: StudioType.caption12(height: 1.45, color: c.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          StudioSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}

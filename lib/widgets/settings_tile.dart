import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/studio_colors.dart';

/// Shared settings-list row: icon + label + trailing chevron, used across
/// Settings-family screens (promoted out of `profile_settings_page.dart` so
/// new settings screens can reuse it instead of duplicating the pattern).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Overrides the trailing chevron (e.g. a pending-count badge).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.studio;
    final color = destructive ? const Color(0xFFE05252) : colors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon,
                  size: 22, color: color.withValues(alpha: destructive ? 1 : 0.75)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: color.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared settings-list toggle row: icon + label + trailing switch, with a
/// bottom divider (promoted out of the seller-only `_SellerToggleTile`).
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.studio;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.line),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../theme/studio_colors.dart';
import '../../../theme/studio_metrics.dart';
import '../../../theme/studio_type.dart';
import '../../../widgets/follow_button.dart';
import '../profile_constants.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.handle,
    required this.followingCount,
    required this.followersCount,
    required this.bio,
    this.piecesCount,
    this.scenesCount,
    this.savesCount,
    this.collectedCount,
    this.sellerMode = false,
    this.collectorMode = false,
    this.isOwnProfile = true,
    this.followState = FollowState.none,
    this.followBusy = false,
    this.onFollow,
    this.onMessage,
    this.onEditProfile,
    this.onShare,
    this.onTapFollowing,
    this.onTapFollowers,
  });

  final String name;
  final String handle;
  final int followingCount;
  final int followersCount;
  final String bio;
  final int? piecesCount;
  final int? scenesCount;
  final int? savesCount;
  final int? collectedCount;
  final bool sellerMode;

  /// `ProfileCollector`: a collector without seller mode. The board's stats are
  /// collected · artists · saves; the profile payload has no artists count, so that
  /// one stays off (plan rule 5) and the row is collected · saves.
  final bool collectorMode;
  final bool isOwnProfile;
  final FollowState followState;
  final bool followBusy;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;

  /// `ProfileOwn`: Edit profile and Share replace Message and Follow on your own
  /// profile. Shown only when [isOwnProfile] and a callback is given.
  final VoidCallback? onEditProfile;
  final VoidCallback? onShare;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapFollowers;

  String _formatCount(int? value) {
    if (value == null) return '—';
    if (value >= 1000) {
      final k = value / 1000;
      final text = k.truncateToDouble() == k ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return '${text}k';
    }
    return '$value';
  }

  List<({String value, String label})> get _stats => sellerMode
      ? [
          (value: _formatCount(piecesCount), label: 'pieces'),
          (value: _formatCount(collectedCount), label: 'collected'),
          (value: _formatCount(savesCount), label: 'saves'),
        ]
      : collectorMode
      ? [
          (value: _formatCount(collectedCount), label: 'collected'),
          (value: _formatCount(savesCount), label: 'saves'),
        ]
      : [
          (value: _formatCount(piecesCount), label: 'pieces'),
          (value: _formatCount(scenesCount), label: 'scenes'),
          (value: _formatCount(savesCount), label: 'saves'),
        ];

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return ColoredBox(
      color: c.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kProfileHorizontalPad, 14, kProfileHorizontalPad, 0),
        child: Column(
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: StudioType.sans(
                22,
                weight: StudioType.medium,
                letterSpacing: -0.3,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              handle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StudioType.label13(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: onTapFollowers,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '$followersCount followers',
                            style: StudioType.label13(color: c.textSecondary),
                          ),
                        ),
                      ),
                      TextSpan(
                        text: ' · ',
                        style: StudioType.label13(color: c.textSecondary),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: onTapFollowing,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '$followingCount following',
                            style: StudioType.label13(color: c.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                bio,
                textAlign: TextAlign.center,
                style: StudioType.body14(height: 1.5, color: c.textBody),
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _StatsRow(stats: _stats),
            ),
            if (isOwnProfile && (onEditProfile != null || onShare != null)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onEditProfile != null)
                    Expanded(
                      child: _ProfileActionButton(
                        label: 'Edit profile',
                        filled: true,
                        onPressed: onEditProfile,
                      ),
                    ),
                  if (onEditProfile != null && onShare != null) const SizedBox(width: 10),
                  if (onShare != null)
                    _ProfileActionButton(
                      label: 'Share',
                      filled: false,
                      hug: true,
                      onPressed: onShare,
                    ),
                ],
              ),
            ],
            if (!isOwnProfile) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ProfileActionButton(
                      label: 'Message',
                      filled: false,
                      onPressed: onMessage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileActionButton(
                      label: followState.actionLabel,
                      filled: followState.filled,
                      busy: followBusy,
                      onPressed: followBusy ? null : onFollow,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<({String value, String label})> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final stat in stats)
          Expanded(
            child: _StatBlock(value: stat.value, label: stat.label),
          ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StudioType.mono(17, weight: StudioType.medium, color: c.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StudioType.caption12(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.filled,
    this.onPressed,
    this.busy = false,
    this.hug = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  final bool busy;

  /// Size to the label with 16 each side (`ProfileOwn` Share) instead of filling.
  final bool hug;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final foreground = filled ? c.buttonText : c.textPrimary;
    return SizedBox(
      height: kProfileButtonHeight,
      child: Material(
        color: filled ? c.buttonFill : Colors.transparent,
        borderRadius: BorderRadius.circular(StudioRadius.button),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(StudioRadius.button),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StudioRadius.button),
              border: filled ? null : Border.all(color: c.lineStrong),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hug ? 16 : 0),
              child: Center(
                widthFactor: hug ? 1 : null,
                child: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: foreground),
                      )
                    : Text(
                        label,
                        style: StudioType.body14(weight: StudioType.medium, color: foreground),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

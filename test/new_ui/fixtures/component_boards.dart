import 'package:flutter/material.dart';
import 'package:studio3/widgets/studio/studio.dart';

/// Test-only compositions of two boards built ONLY from the Phase 1 tokens and components,
/// laid out value for value from `docs/new-ui/reference/<Board>.dc.html`. Their goldens are
/// compared with the board renders (plan section 0.4) to check the components themselves;
/// the real screens are built in their phases.

/// `SavedEmpty`: header, then [StudioEmptyState] 200 below it.
class SavedEmptyFromComponents extends StatelessWidget {
  const SavedEmptyFromComponents({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      width: 390,
      height: 844,
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: StudioIcon(StudioIcons.backBold, size: 22, color: c.textPrimary),
                  ),
                ),
                Text(
                  'Saved',
                  style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          const SizedBox(height: 200),
          StudioEmptyState(
            title: 'Nothing saved yet',
            message:
                'Tap the bookmark on any piece to keep it here. Only you can see what you save.',
            actionLabel: 'Browse the feed',
            onAction: () {},
          ),
        ],
      ),
    );
  }
}

/// `SignIn4Intention`: progress segments, title block, [StudioSelectRow]s and the pinned
/// primary (54) + text buttons.
class SignIn4IntentionFromComponents extends StatelessWidget {
  const SignIn4IntentionFromComponents({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    const rows = [
      ('Collecting art', 'Available pieces and prices first'),
      ('Sharing my work', 'Post pieces and build a following'),
      ('Exploring and events', "A bit of everything, plus what's on at The Space"),
    ];
    return Container(
      width: 390,
      height: 844,
      color: c.background,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: StudioIcon(StudioIcons.backBold, size: 22, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: StudioProgressSegments(current: 3, total: 3)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'What brings you to Studio 3?',
                      style: StudioType.title32(color: c.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "We'll use this to get your feed started.",
                      style: StudioType.body16(color: c.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    for (final (i, (title, subtitle)) in rows.indexed)
                      StudioSelectRow(
                        title: title,
                        subtitle: subtitle,
                        selected: i == 0,
                        divider: i < rows.length - 1,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioButton(
                  label: 'Continue',
                  height: StudioSize.buttonPrimaryTall,
                  onPressed: () {},
                ),
                const SizedBox(height: 4),
                Center(
                  child: StudioButton(
                    label: 'Skip for now',
                    variant: StudioButtonVariant.text,
                    expand: false,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top of `SignInFirst` / `SignInFirstDark`: [StudioHaze] full screen with
/// [StudioLogo.signIn] 175 from the top. (The form below it is built in Phase 4.)
class SignInHazeFromComponents extends StatelessWidget {
  const SignInHazeFromComponents({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 390,
      height: 844,
      child: Stack(
        children: [
          Positioned.fill(child: StudioHaze()),
          Positioned(left: 0, right: 0, top: 175, child: Center(child: StudioLogo.signIn())),
        ],
      ),
    );
  }
}

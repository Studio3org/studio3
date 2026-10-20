import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/studio/studio.dart';

/// Debug-only page showing every new-UI component in light and dark, for checking them
/// against the boards (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 1). Reachable only in
/// debug builds at `/studio-gallery`.
class StudioGalleryPage extends StatefulWidget {
  const StudioGalleryPage({super.key, this.initialDark = false});

  final bool initialDark;

  static const routeName = '/studio-gallery';

  @override
  State<StudioGalleryPage> createState() => _StudioGalleryPageState();
}

class _StudioGalleryPageState extends State<StudioGalleryPage> {
  late bool _dark = widget.initialDark;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? AppTheme.dark : AppTheme.light,
      child: Builder(
        builder: (context) {
          final c = context.studio;
          return Scaffold(
            backgroundColor: c.background,
            appBar: AppBar(
              title: const Text('Components'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Text('Dark', style: StudioType.label13(color: c.textSecondary)),
                      const SizedBox(width: 8),
                      StudioSwitch(
                        value: _dark,
                        semanticLabel: 'Dark theme',
                        onChanged: (v) => setState(() => _dark = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: const StudioGalleryBody(),
          );
        },
      ),
    );
  }
}

/// The gallery's content, also rendered by the golden test in both themes.
class StudioGalleryBody extends StatefulWidget {
  const StudioGalleryBody({super.key});

  @override
  State<StudioGalleryBody> createState() => _StudioGalleryBodyState();
}

class _StudioGalleryBodyState extends State<StudioGalleryBody> {
  int _role = 0;
  int _chip = 0;
  int _nav = 0;
  bool _switch = true;
  final _price = TextEditingController(text: '3,500');

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        _section(context, 'Type'),
        Text('Enter your code', style: StudioType.title32(color: c.textPrimary)),
        Text('Bodies in Color', style: StudioType.title26(color: c.textPrimary)),
        Text('Shelf header', style: StudioType.header20(color: c.textPrimary)),
        Text('Body copy at 16 / 1.45.', style: StudioType.body16(color: c.textPrimary)),
        Text('Secondary 14', style: StudioType.body14(color: c.textSecondary)),
        Text('24 × 36 in · 2025', style: StudioType.mono13(color: c.textPrimary)),
        _section(context, 'Logo'),
        const Center(child: StudioLogo.header()),
        const SizedBox(height: 12),
        const Center(child: FittedBox(child: StudioLogo.signIn())),
        _section(context, 'Buttons'),
        StudioButton(label: 'Continue', onPressed: () {}),
        const SizedBox(height: 10),
        const StudioButton(label: 'Continue (disabled)', onPressed: null),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StudioButton(
                label: 'Message',
                variant: StudioButtonVariant.outline,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StudioButton(
                label: 'Follow',
                variant: StudioButtonVariant.inline,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StudioButton(label: 'Follow', variant: StudioButtonVariant.small, onPressed: () {}),
            const Spacer(),
            StudioButton(
              label: 'Skip for now',
              variant: StudioButtonVariant.text,
              onPressed: () {},
            ),
          ],
        ),
        _section(context, 'Fields'),
        StudioUnderlineField(label: 'Title', hint: 'Portrait Dream', required: true),
        const SizedBox(height: 24),
        StudioTooltip(
          message: 'Used only to get shipping quotes. It never shows on your piece.',
          builder: (context, toggle) => StudioUnderlineField(
            label: 'Weight',
            controller: _price,
            unit: 'lb',
            mono: true,
            labelTrailing: StudioInfoButton(onTap: toggle, semanticLabel: 'What is weight?'),
          ),
        ),
        const SizedBox(height: 24),
        const StudioUnderlineField(
          label: 'Phone · optional',
          hint: '(000) 000-0000',
          mono: true,
          helper: 'For shipping and delivery updates. You can add it later.',
        ),
        const SizedBox(height: 16),
        const StudioTooltipBox(message: 'Tooltip box: tap anywhere to close.'),
        _section(context, 'Selection'),
        for (final (i, (t, s)) in const [
          ('Collecting art', 'Available pieces and prices first'),
          ('Sharing my work', 'Post pieces and build a following'),
          ('Exploring and events', "A bit of everything, plus what's on at The Space"),
        ].indexed)
          StudioSelectRow(
            title: t,
            subtitle: s,
            selected: _role == i,
            divider: i < 2,
            onTap: () => setState(() => _role = i),
          ),
        _section(context, 'Chips and switch'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in const ['All', 'Painting', 'Photography'].indexed)
              StudioChip(
                label: label,
                selected: _chip == i,
                onTap: () => setState(() => _chip = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StudioStatusChip(StudioStatus.available),
            StudioStatusChip(StudioStatus.collected),
            StudioStatusChip(StudioStatus.notForSale),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Push notifications', style: StudioType.body15(color: c.textPrimary)),
            const Spacer(),
            StudioSwitch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
          ],
        ),
        _section(context, 'Progress'),
        const StudioProgressSegments(current: 2, total: 3),
        _section(context, 'Avatars'),
        const Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StudioAvatar(url: null, size: 22),
            StudioAvatar(url: null, size: 36),
            StudioAvatar(url: null, size: 56),
            StudioAvatar(url: null, size: 72),
            StudioAvatar.profile(url: null),
          ],
        ),
        _section(context, 'On images'),
        ClipRRect(
          borderRadius: BorderRadius.circular(StudioRadius.card),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Color(0xFF6FA3B0))),
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: StudioTopIconBar(
                    leading: [
                      StudioTopIcon(icon: StudioIcons.back, onTap: () {}, semanticLabel: 'Back'),
                    ],
                    trailing: [
                      StudioTopIcon(icon: StudioIcons.save, onTap: () {}, semanticLabel: 'Save'),
                      StudioTopIcon(icon: StudioIcons.share, onTap: () {}, semanticLabel: 'Share'),
                      StudioTopIcon(icon: StudioIcons.more, onTap: () {}, semanticLabel: 'More'),
                    ],
                  ),
                ),
                const Positioned(left: 12, bottom: 12, child: StudioImageLabel('1 / 4')),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child: StudioImageLabel(
                    'Cover',
                    mono: false,
                    size: 13,
                    weight: StudioType.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
        _section(context, 'Iridescent'),
        Center(
          child: StudioIridescent(
            padding: const EdgeInsets.all(4),
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 102,
                height: 136,
                child: ColoredBox(color: Color(0xFFB9A98C)),
              ),
            ),
          ),
        ),
        _section(context, 'Toast'),
        const Center(child: StudioToastBox(message: 'Saved. Welcome to Studio 3, Jordan.')),
        const SizedBox(height: 10),
        Center(
          child: StudioButton(
            label: 'Show toast',
            variant: StudioButtonVariant.small,
            onPressed: () => showStudioToast(context, 'Saved to Favourites'),
          ),
        ),
        _section(context, 'Sheet'),
        Center(
          child: StudioButton(
            label: 'Open sheet',
            variant: StudioButtonVariant.small,
            onPressed: () => showStudioSheet<void>(
              context: context,
              builder: (context) => StudioSheet(
                children: [
                  Text(
                    'Sign in to save this piece',
                    style: StudioType.title22(color: context.studio.textPrimary),
                  ),
                  StudioButton(label: 'Continue', onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ),
        _section(context, 'Empty state'),
        StudioEmptyState(
          title: 'Nothing saved yet',
          message: 'Tap the bookmark on any piece to keep it here. Only you can see what you save.',
          actionLabel: 'Browse the feed',
          onAction: () {},
        ),
        _section(context, 'Sign-in haze'),
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(StudioRadius.card),
            child: const StudioHaze(),
          ),
        ),
        _section(context, 'Bottom bar'),
        StudioBottomBar(
          left: const StudioBottomBarInfo(label: 'Price', value: r'$3,500'),
          right: const StudioBottomBarInfo(label: 'Ships in', value: '7–10 days'),
          button: StudioButton(label: 'Collect', fontSize: 16, onPressed: () {}),
          messageButton: StudioMessageButton(onPressed: () {}),
        ),
        _section(context, 'Floating nav'),
        MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: StudioFloatingNav(
            currentIndex: _nav,
            onTap: (i) => setState(() => _nav = i),
            items: const [
              StudioNavItem(label: 'Home', icon: StudioIcons.home),
              StudioNavItem(label: 'Explore', icon: StudioIcons.explore),
              StudioNavItem(label: 'Post', icon: StudioIcons.post, iconSize: 26),
              StudioNavItem(label: 'Events', icon: StudioIcons.events),
              StudioNavItem(label: 'Profile', isProfile: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: StudioType.mono11(color: context.studio.textTertiary, letterSpacing: 0.6),
      ),
    );
  }
}

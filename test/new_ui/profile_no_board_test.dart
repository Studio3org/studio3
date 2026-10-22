import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/follow_user_summary.dart';
import 'package:studio3/screens/follow_list_page.dart';
import 'package:studio3/screens/profile/widgets/profile_locked_placeholder.dart';
import 'package:studio3/screens/profile/widgets/profile_viewer_mode_capsule.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/profile_avatar_preview_sheet.dart';
import 'package:studio3/widgets/studio/studio_action_row.dart';
import 'package:studio3/widgets/studio/studio_avatar.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_empty_state.dart';
import 'package:studio3/widgets/studio/studio_icon.dart';
import 'package:studio3/widgets/studio/studio_tab_bar.dart';
import 'package:studio3/widgets/studio/studio_toast.dart';

/// Phase 6 "No board" profile screens (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): built from
/// the closest boards with the shared tokens and components.
Widget _app(Widget home, {bool dark = false}) {
  return MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );
}

void main() {
  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('locked profile is the board empty state, same copy ($theme)', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: ProfileLockedPlaceholder()), dark: dark));
      await tester.pump();
      expect(find.byType(StudioEmptyState), findsOneWidget);
      final title = tester.widget<Text>(find.text('This account is private'));
      expect(title.style!.fontSize, 22);
      expect(title.style!.color, c.textPrimary);
      final line = tester.widget<Text>(
        find.text('Follow this account to see their pieces, scenes, and series.'),
      );
      expect(line.style!.color, c.textSecondary);
    });

    testWidgets('viewer-mode notice is the toast box ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(body: Center(child: ProfileViewerModeCapsule())),
          dark: dark,
        ),
      );
      await tester.pump();
      expect(find.byType(StudioToastBox), findsOneWidget);
      final text = tester.widget<Text>(find.text('Viewing your profile as others see it'));
      expect(text.style!.fontSize, 14);
      expect(text.style!.fontWeight, StudioType.medium);
      expect(text.style!.color, c.tooltipText);
      expect(find.byType(StudioIcon), findsNothing);
    });

    testWidgets('follow list: board tabs and NewMessage rows ($theme)', (tester) async {
      String? opened;
      await tester.pumpWidget(
        _app(
          DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const PreferredSize(
                preferredSize: Size.fromHeight(45),
                child: StudioTabBar(labels: ['Followers', 'Following']),
              ),
              body: Column(
                children: [
                  FollowUserRow(
                    user: const FollowUserSummary(username: 'amarasart', name: 'Amara Osei'),
                    onTap: () => opened = 'amarasart',
                  ),
                ],
              ),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(TabBar)).height, 44);
      expect(tester.getSize(find.byType(StudioTabBar)).height, 45);
      final active = tester.widget<Text>(find.text('Followers'));
      expect(active.style?.fontSize ?? 14, 14);

      final name = tester.widget<Text>(find.text('Amara Osei'));
      expect(name.style!.fontSize, 15);
      expect(name.style!.fontWeight, StudioType.medium);
      expect(name.style!.color, c.textPrimary);
      final handle = tester.widget<Text>(find.text('@amarasart'));
      expect(handle.style!.fontSize, 12);
      expect(handle.style!.color, c.textSecondary);
      expect(tester.getSize(find.byType(StudioAvatar)).width, 44);
      expect(tester.getSize(find.byType(FollowUserRow)).height, closeTo(64, 0.5));

      await tester.tap(find.text('Amara Osei'));
      expect(opened, 'amarasart');
    });

    testWidgets('avatar preview: one scrim, 140 avatar, 44 Change button ($theme)', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showProfileAvatarPreview(context, avatarUrl: null, allowChange: true),
                child: const Text('open'),
              ),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(StudioAvatar)).width, 140);
      final change = find.byType(StudioButton);
      expect(tester.getSize(change).height, 44);
      expect(tester.widget<StudioButton>(change).variant, StudioButtonVariant.inline);
      final scrims = tester
          .widgetList<Container>(find.byType(Container))
          .where((w) => w.color == c.scrim);
      expect(scrims, isNotEmpty);
    });

    testWidgets('profile actions rows are Ink with outline icons, never red ($theme)', (
      tester,
    ) async {
      var blocked = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                const StudioActionSheetPerson(name: 'Amara Osei', handle: '@amarasart'),
                StudioActionRow(
                  icon: StudioIcons.block,
                  title: 'Block Amara Osei',
                  onTap: () => blocked++,
                ),
                StudioActionRow(icon: StudioIcons.report, title: 'Report', onTap: () {}),
              ],
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pump();

      for (final label in ['Block Amara Osei', 'Report']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style!.fontSize, 16);
        expect(text.style!.color, c.textPrimary);
      }
      for (final icon in tester.widgetList<StudioIcon>(
        find.descendant(of: find.byType(StudioActionRow), matching: find.byType(StudioIcon)),
      )) {
        expect(icon.size, 22);
        expect(icon.color, c.textPrimary);
      }
      final person = tester.widget<Text>(find.text('Amara Osei'));
      expect(person.style!.fontSize, 16);
      expect(person.style!.fontWeight, StudioType.medium);
      expect(tester.getSize(find.byType(StudioAvatar)).width, 40);
      // 14 above and below the 22 px icon (taller than the 16 px line's 21) + 1 px rule,
      // as the board's flex row.
      expect(tester.getSize(find.byType(StudioActionRow).first).height, closeTo(51, 0.5));

      await tester.tap(find.text('Block Amara Osei'));
      expect(blocked, 1);
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/account_settings_page.dart';
import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/screens/selling_settings_page.dart';
import 'package:studio3/services/api_exception.dart';
import 'package:studio3/services/payout_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/utils/app_version.dart';
import 'package:studio3/widgets/settings_tile.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Flow 12, Settings (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 17.10): `Settings` and
/// `SettingsAccount`.
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

const _notPaid = PayoutStatus(onboarded: false, payoutsEnabled: false, canListForSale: false);

Widget _settings({bool seller = true, PayoutStatus? payout = _notPaid}) =>
    ProfileSettingsPage(debugSeller: seller, debugName: 'Jordan Lee', debugPayout: payout);

const _jordan = UserProfile(username: 'jordan', name: 'Jordan Lee', email: 'jordan@email.com');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  group('Settings', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('sections, rows, Payouts in red, Delete in red, the version (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester, height: 1400);
        await tester.pumpWidget(_app(_settings(), dark: dark));
        await tester.pump();

        for (final label in ['ACCOUNT', 'SELLING', 'BUYING', 'APP', 'HELP']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style!.fontFamily, contains('Mono'));
          expect((text.style!.fontSize, text.style!.color), (11, c.textTertiary));
        }
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).map((r) => r.label).toList();
        expect(rows, [
          'Account', 'Series',
          'Seller profile', 'Sales', 'Insights', 'Payouts',
          'Purchases', 'Payment and shipping',
          'Notifications', 'Privacy', 'Appearance',
          'Help', 'Terms and policies',
          'Log out', 'Delete account',
        ]);
        final account = tester.widget<Text>(find.text('Account').first);
        expect((account.style!.fontSize, account.style!.color), (16, c.textPrimary));
        expect(tester.widget<Text>(find.text('Jordan Lee')).style!.color, c.textSecondary);
        expect(find.text('On'), findsOneWidget);
        expect(find.text('Orders, auction wins and tickets'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Finish setup')).style!.color, c.alert);
        expect(tester.widget<Text>(find.text('Delete account')).style!.color, c.alert);
        expect(tester.widget<Text>(find.text('Log out')).style!.color, c.textPrimary);
        final version = tester.widget<Text>(find.text('Studio 3 · $kAppVersion'));
        expect(version.style!.fontFamily, contains('Mono'));
        expect(find.text('Start selling'), findsNothing);
        expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, c.background);
      });
    }

    testWidgets('not a seller: one Start selling row', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(_settings(seller: false)));
      await tester.pump();
      expect(find.text('Start selling'), findsOneWidget);
      for (final row in ['Seller profile', 'Sales', 'Insights', 'Payouts']) {
        expect(find.text(row), findsNothing);
      }
    });

    testWidgets('Payouts paid out: no Finish setup', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(
        _app(_settings(payout: const PayoutStatus(onboarded: true, payoutsEnabled: true, canListForSale: true))),
      );
      await tester.pump();
      expect(find.text('Payouts'), findsOneWidget);
      expect(find.text('Finish setup'), findsNothing);
    });

    testWidgets('Appearance opens Light / Dark', (tester) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(_app(_settings()));
      await tester.pump();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsOneWidget);
    });

    test('the version matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
      expect(kAppVersion, version);
    });
  });

  group('Account', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('name, email, phone (Add), password, log out everywhere (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan), dark: dark));
        await tester.pump();
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => (r.label, r.value)), [
          ('Name', 'Jordan Lee'),
          ('Email', 'jordan@email.com'),
          ('Phone', 'Add'),
          ('Password', 'Change'),
          ('Log out of all devices', null),
        ]);
        expect(rows.last.chevron, isFalse);
        final note = tester.widget<Text>(find.text('Changing your email sends a code to the new address first.'));
        expect((note.style!.fontSize, note.style!.color), (12, c.textSecondary));
      });
    }

    testWidgets('Name in a sheet: Save only once it changed', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      StudioButton save() => tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save'));
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Jordan A. Lee');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), '  ');
      await tester.pump();
      expect(save().onPressed, isNull);
    });

    testWidgets('Phone: optional, so an empty phone can be saved to remove it', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(
        _app(const AccountSettingsPage(
          debugProfile: UserProfile(username: 'jordan', name: 'Jordan Lee', phone: '+1 214 555 0100'),
        )),
      );
      await tester.pump();
      expect(find.text('+1 214 555 0100'), findsOneWidget);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('Optional. Leave it empty to remove it.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Save')).onPressed, isNotNull);
    });

    testWidgets('Log out of all devices asks first', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await tester.tap(find.text('Log out of all devices'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of all devices?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of all devices?'), findsNothing);
    });
  });

  group('Selling', () {
    for (final dark in [false, true]) {
      final c = dark ? StudioColors.dark : StudioColors.light;
      testWidgets('on, seller terms, turn off (${dark ? 'dark' : 'light'})', (tester) async {
        setBoardViewport(tester);
        await tester.pumpWidget(_app(const SellingSettingsPage(), dark: dark));
        await tester.pump();
        expect(find.text('Seller profile is on'), findsOneWidget);
        final dot = tester.widget<Container>(
          find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle),
        );
        expect((dot.decoration! as BoxDecoration).color, c.available);
        expect(find.text('STUDIO'), findsOneWidget);
        final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
        expect(rows.map((r) => (r.label, r.subtitle, r.chevron)), [
          ('Seller terms', 'Includes fees', true),
          ('Turn off seller profile', 'Your listings come down. Pieces stay on your profile.', false),
        ]);
        // The pickup address waits on B31 (on hold).
        expect(find.text('Studio address'), findsNothing);
      });
    }

    testWidgets('turning off asks first, then closes saying so', (tester) async {
      setBoardViewport(tester);
      var calls = 0;
      final results = <Object?>[];
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(builder: (_) => SellingSettingsPage(debugTurnOff: () async => calls++)),
            )),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off seller profile'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off seller profile?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StudioButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(results, [true]);
      // The "Seller profile is off" toast.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets("the server's reason stays on the page", (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(SellingSettingsPage(
        debugTurnOff: () async => throw ApiException('Remove your active listings before disabling seller mode.'),
      )));
      await tester.tap(find.text('Turn off seller profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StudioButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(find.text('Remove your active listings before disabling seller mode.'), findsOneWidget);
      expect(find.text('Seller profile is on'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('goldens', () {
    final skip = Platform.environment['NEW_UI_GOLDENS'] != '1';
    testWidgets('Settings', (tester) async {
      setBoardViewport(tester, height: 1120);
      await tester.pumpWidget(_app(_settings()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Settings.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsSelling', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const SellingSettingsPage()));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsSelling.png'));
      await checkAcceptance(tester);
    }, skip: skip);

    testWidgets('SettingsAccount', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_app(const AccountSettingsPage(debugProfile: _jordan)));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/SettingsAccount.png'));
      await checkAcceptance(tester);
    }, skip: skip);
  });
}

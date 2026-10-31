import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/screens/address_form_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/theme/studio_type.dart';
import 'package:studio3/widgets/piece_detail/collect_shipping_sheet.dart';
import 'package:studio3/widgets/studio/studio_action_row.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_checkbox.dart';
import 'package:studio3/widgets/studio/studio_field.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';
import 'package:studio3/widgets/studio/studio_sheet.dart';

import 'golden_harness.dart';

/// `BuyAddress` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, Phase 7).
Widget _app(Widget home, {bool dark = false}) => MaterialApp(
  key: UniqueKey(),
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

StudioUnderlineField _field(WidgetTester tester, String label) =>
    tester.widget(find.byWidgetPredicate((w) => w is StudioUnderlineField && w.label == label));

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  testWidgets('form: board fields in order, Mono ZIP / phone, helper, checkbox, 54 button', (
    tester,
  ) async {
    _phone(tester, const Size(390, 1200));
    await tester.pumpWidget(_app(const AddressFormPage()));
    await tester.pump();

    expect(find.text('Delivery address'), findsOneWidget);
    final labels = tester
        .widgetList<StudioUnderlineField>(find.byType(StudioUnderlineField))
        .map((f) => f.label)
        .toList();
    expect(labels, [
      'First name',
      'Last name',
      'Street address',
      'Apt, suite, etc.',
      'City',
      'State',
      'ZIP',
      'Phone',
      'Label',
    ]);

    expect(_field(tester, 'ZIP').mono, isTrue);
    expect(_field(tester, 'ZIP').valueSize, 18);
    expect(_field(tester, 'Phone').mono, isTrue);
    expect(_field(tester, 'Phone').helper, 'The shipper uses this to schedule delivery with you.');
    expect(_field(tester, 'Apt, suite, etc.').hint, 'Optional');
    // First / last name share a row; City, State, ZIP share a row.
    final first = tester.getRect(find.text('First name'));
    final last = tester.getRect(find.text('Last name'));
    expect(first.top, last.top);
    expect(tester.getRect(find.text('City')).top, tester.getRect(find.text('ZIP')).top);
    // Required dots while empty.
    expect(find.byType(StudioRequiredDot), findsWidgets);

    expect(find.byType(StudioCheckbox), findsOneWidget);
    final button = find.widgetWithText(StudioButton, 'Save address');
    expect(tester.getSize(button).height, 54);
    expect(tester.widget<StudioButton>(button).onPressed, isNull);
  });

  testWidgets('form: filling the required fields enables the button', (tester) async {
    _phone(tester, const Size(390, 1200));
    await tester.pumpWidget(
      _app(
        const AddressFormPage(
          existing: Address(
            id: 'a1',
            firstName: 'Alex',
            lastName: 'Smith',
            phone: '2145550142',
            line1: '1234 Lovers Ln',
            city: 'Dallas',
            state: 'TX',
            zip: '75225',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Edit address'), findsOneWidget);
    expect(find.byType(StudioRequiredDot), findsNothing);
    final button = find.widgetWithText(StudioButton, 'Save address');
    expect(tester.widget<StudioButton>(button).onPressed, isNotNull);

    await tester.tap(find.byType(StudioCheckbox));
    await tester.pump();
    expect(tester.widget<StudioCheckbox>(find.byType(StudioCheckbox)).value, isTrue);

    // State opens the list of states; picking one fills the field.
    await tester.tap(find.text('TX'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(StudioSelectRow, 'AL'), findsOneWidget);
    await tester.tap(find.text('AL'));
    await tester.pumpAndSettle();
    expect(find.text('AL'), findsOneWidget);
    expect(find.text('TX'), findsNothing);
  });

  testWidgets('picker: select rows, no radios, add row, Save and continue', (tester) async {
    _phone(tester, const Size(390, 844));
    const home = Address(
      id: 'a1',
      label: 'Home',
      firstName: 'Alex',
      lastName: 'Smith',
      phone: '1',
      line1: '1234 Lovers Ln',
      city: 'Dallas',
      state: 'TX',
      zip: '75225',
    );
    const studio = Address(
      id: 'a2',
      firstName: 'Alex',
      lastName: 'Smith',
      phone: '1',
      line1: '1 Dragon St',
      city: 'Dallas',
      state: 'TX',
      zip: '75201',
    );
    Address? picked;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showStudioSheet<Address>(
                context: context,
                builder: (_) => const CollectShippingSheet(debugAddresses: [home, studio]),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNothing);
    final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).toList();
    expect(rows.map((r) => r.title), ['Home', 'Alex Smith']);
    expect(rows.first.selected, isTrue);
    expect(find.text('1234 Lovers Ln, Dallas, TX 75225'), findsOneWidget);
    expect(find.widgetWithText(StudioActionRow, 'Add a new address'), findsOneWidget);

    await tester.tap(find.text('Alex Smith'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(picked?.id, 'a2');
  });

  testWidgets('dark and the smallest phone render without overflow', (tester) async {
    _phone(tester, const Size(375, 667));
    await tester.pumpWidget(_app(const AddressFormPage(), dark: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text('Street address'));
    expect(label.style!.color, StudioColors.dark.textSecondary);
    expect(label.style!.fontSize, 13);
    expect(StudioType.label13().fontSize, 13);
  });
}

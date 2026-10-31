import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/address.dart';
import 'package:studio3/screens/address_form_page.dart';
import 'package:studio3/theme/app_theme.dart';

import 'golden_harness.dart';

/// `BuyAddress` form with the board's sample data, for the crop comparison in
/// docs/new-ui/NEW_UI_EXECUTION_PLAN.md (Phase 7). Writes where the phone helper ends: the
/// board and the app match from the top down to there.
///
///   NEW_UI_GOLDENS=1 flutter test test/new_ui/address_golden_test.dart --update-goldens
void main() {
  testWidgets('BuyAddress form', (tester) async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    setBoardViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const AddressFormPage(
                existing: Address(
                  id: 'a1',
                  firstName: 'Alex',
                  lastName: 'Smith',
                  phone: '(214) 555-0142',
                  line1: '1234 Lovers Ln',
                  city: 'Dallas',
                  state: 'TX',
                  zip: '75225',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    final helper = tester.getRect(
      find.text('The shipper uses this to schedule delivery with you.'),
    );
    File('build/new_ui/BuyAddress_positions.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'helperBottom': helper.bottom}));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/BuyAddress.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] == null);
}

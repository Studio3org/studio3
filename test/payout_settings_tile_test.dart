import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/screens/profile_settings_page.dart';
import 'package:studio3/services/payout_service.dart';

/// Guards the regression where Profile settings claimed "Payout setup —
/// Required" on every fresh login, for artists who had already completed
/// setup, until the status call came back and corrected it.
void main() {
  Future<void> pumpTile(WidgetTester tester, PayoutStatus? status) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayoutSettingsTile(
            status: status,
            onStartSetup: () {},
            onOpenDashboard: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  PayoutStatus status({required bool canListForSale}) => PayoutStatus(
        onboarded: canListForSale,
        payoutsEnabled: canListForSale,
        canListForSale: canListForSale,
      );

  testWidgets('an unknown status never claims setup is required', (
    tester,
  ) async {
    await pumpTile(tester, null);
    expect(find.text('Required'), findsNothing);
    expect(find.text('Payout setup'), findsNothing);
    expect(find.text('Payouts'), findsOneWidget);
  });

  testWidgets('an unknown status is inert — nothing to route on yet', (
    tester,
  ) async {
    await pumpTile(tester, null);
    final tile = tester.widget<InkWell>(find.byType(InkWell));
    expect(tile.onTap, isNull);
  });

  testWidgets('a completed account shows Payouts, not a warning', (
    tester,
  ) async {
    await pumpTile(tester, status(canListForSale: true));
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('an incomplete account is the only case that says Required', (
    tester,
  ) async {
    await pumpTile(tester, status(canListForSale: false));
    expect(find.text('Payout setup'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('resolving from unknown to done never shows Required', (
    tester,
  ) async {
    // The exact sequence a login used to walk through.
    await pumpTile(tester, null);
    expect(find.text('Required'), findsNothing);
    await pumpTile(tester, status(canListForSale: true));
    expect(find.text('Required'), findsNothing);
  });
}

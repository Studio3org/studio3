import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/screens/login_page.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/auth_ui.dart';

/// The first screen (`SignInFirst`): opening the keyboard shrinks the screen, which switches
/// [SignInLaunchScaffold] from its column to its scroll view. The email field must survive
/// that switch. It used to be rebuilt in the new layout, lose focus and close the keyboard
/// again straight away, so nothing could be typed.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(390, 844), const Size(360, 640)]) {
    testWidgets('the email field keeps focus and takes typing with the keyboard up (${size.width.toInt()}×${size.height.toInt()})', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = size * 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LoginPage()));
      await tester.pump();
      // Without the keyboard the screen has room for the plain column.
      expect(find.descendant(of: find.byType(SignInLaunchScaffold), matching: find.byType(SingleChildScrollView)), findsNothing);

      await tester.showKeyboard(find.byType(TextField));
      final field = find.byType(EditableText);
      final stateBefore = tester.state<EditableTextState>(field);

      // The keyboard: about 336 of the screen's height.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 2);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: find.byType(SignInLaunchScaffold), matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
        reason: 'the keyboard should switch the screen to its scroll view',
      );
      expect(tester.state<EditableTextState>(field), same(stateBefore), reason: 'the field was rebuilt');
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue, reason: 'the keyboard lost its field');

      tester.testTextInput.enterText('jordan@email.com');
      await tester.pump();
      expect(find.text('jordan@email.com'), findsOneWidget);
      final continueButton = find.byWidgetPredicate((w) => w is AuthPrimaryButton && w.label == 'Continue');
      expect(tester.widget<AuthPrimaryButton>(continueButton).enabled, isTrue);

      // And back when the keyboard goes down.
      tester.view.resetViewInsets();
      await tester.pump();
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      expect(find.text('jordan@email.com'), findsOneWidget);
    });
  }
}

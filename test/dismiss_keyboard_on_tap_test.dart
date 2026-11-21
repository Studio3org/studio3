import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/widgets/dismiss_keyboard_on_tap.dart';

void main() {
  late FocusNode first;
  late FocusNode second;
  var pressed = 0;

  Future<void> pump(WidgetTester tester) async {
    first = FocusNode();
    second = FocusNode();
    pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DismissKeyboardOnTap(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextField(key: const Key('first'), focusNode: first),
              TextField(key: const Key('second'), focusNode: second),
              TextButton(onPressed: () => pressed++, child: const Text('Button')),
              const Expanded(child: SizedBox(key: Key('blank'), width: double.infinity)),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('a tap on empty space closes the keyboard', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a tap on another field moves the cursor there', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('second')));
    await tester.pump();
    expect(second.hasFocus, isTrue);
  });

  testWidgets('buttons still get their tap', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    await tester.tap(find.text('Button'));
    await tester.pump();
    expect(pressed, 1);
  });

  Future<void> pumpList(WidgetTester tester, ScrollController controller) async {
    first = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DismissKeyboardOnTap(child: child!),
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              TextField(key: const Key('first'), focusNode: first, maxLines: 3),
              for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('Row $i')),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('scrolling the page with a finger closes the keyboard (as in Instagram)', (tester) async {
    final controller = ScrollController();
    await pumpList(tester, controller);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.drag(find.text('Row 3'), const Offset(0, -300));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(controller.offset, greaterThan(0), reason: 'the page still scrolls');
  });

  testWidgets('the app scrolling by itself leaves the keyboard open', (tester) async {
    final controller = ScrollController();
    await pumpList(tester, controller);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();

    controller.jumpTo(200);
    await tester.pump();
    expect(first.hasFocus, isTrue);
  });
}

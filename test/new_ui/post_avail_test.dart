import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:studio3/models/post_image_transform.dart';
import 'package:studio3/models/user_profile.dart';
import 'package:studio3/screens/post_create_page.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/theme/studio_colors.dart';
import 'package:studio3/widgets/create_flow/post_availability_step.dart';
import 'package:studio3/widgets/studio/studio_button.dart';
import 'package:studio3/widgets/studio/studio_field.dart';
import 'package:studio3/widgets/studio/studio_progress_segments.dart';
import 'package:studio3/widgets/studio/studio_select_row.dart';

import 'golden_harness.dart';

/// `PostAvailFixed`, `PostAvailAuction`, `PostNFSAvail` (docs/new-ui/NEW_UI_EXECUTION_PLAN.md,
/// Phase 8). The last
/// test writes the golden for the board comparison
/// (`NEW_UI_GOLDENS=1 flutter test ... --update-goldens`).
late String _photo;

/// The founding-artist quote from the board: 15 %, $3,600 → $3,060.
Future<CommissionQuote?> _founding(int cents) async => CommissionQuote(
  priceCents: cents,
  netCents: cents - (cents * 15 ~/ 100),
  commissionBps: 1500,
  reducedRate: true,
);

Future<CommissionQuote?> _standard(int cents) async => CommissionQuote(
  priceCents: cents,
  netCents: cents - (cents * 20 ~/ 100),
  commissionBps: 2000,
);

Widget _step({
  bool forSale = true,
  SaleMode? mode,
  bool dark = false,
  String price = '',
  String start = '',
  String reserve = '',
  ValueChanged<SaleMode>? onChanged,
  VoidCallback? onContinue,
  VoidCallback? onBack,
  VoidCallback? onEdit,
  Future<CommissionQuote?> Function(int)? quote,
}) => MaterialApp(
  key: UniqueKey(),
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  routes: {'/terms': (_) => const Scaffold(body: Text('terms page'))},
  home: StatefulBuilder(
    builder: (context, setState) => PostAvailabilityStep(
      cover: const ColoredBox(color: Color(0xFF6FA3B0)),
      photoCount: 4,
      mode: mode ??= forSale ? SaleMode.fixed : SaleMode.notForSale,
      onModeChanged: (v) {
        onChanged?.call(v);
        setState(() => mode = v);
      },
      priceController: TextEditingController(text: price),
      startingBidController: _startController ??= TextEditingController(text: start),
      reserveController: _reserveController ??= TextEditingController(text: reserve),
      durationDays: _days,
      onDurationChanged: (d) => setState(() => _days = d),
      now: DateTime(2026, 10, 25, 18, 40),
      onBack: onBack ?? () {},
      onEdit: onEdit ?? () {},
      onContinue: onContinue ?? () {},
      quote: quote ?? _founding,
    ),
  ),
);

TextEditingController? _startController;
TextEditingController? _reserveController;
int _days = 7;

Finder _info(String label) =>
    find.byWidgetPredicate((w) => w is StudioInfoButton && w.semanticLabel == label);

Finder _row(String title) =>
    find.byWidgetPredicate((w) => w is StudioSelectRow && w.title == title);

StudioButton _continue(WidgetTester tester) =>
    tester.widget<StudioButton>(find.widgetWithText(StudioButton, 'Continue'));

String _plain(WidgetTester tester, Finder f) =>
    tester.widget<RichText>(f).text.toPlainText();

Finder get _earnings => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().startsWith("You'll receive"),
);

void main() {
  setUp(() {
    _startController = null;
    _reserveController = null;
    _days = 7;
  });

  setUpAll(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
    final dir = Directory.systemTemp.createTempSync('post_avail');
    final photo = img.Image(width: 300, height: 400)..clear(img.ColorRgb8(0x6F, 0xA3, 0xB0));
    _photo = (File('${dir.path}/cover.png')..writeAsBytesSync(img.encodePng(photo))).path;
  });

  for (final dark in [false, true]) {
    final c = dark ? StudioColors.dark : StudioColors.light;
    final theme = dark ? 'dark' : 'light';

    testWidgets('fixed price: progress 1/3, card, heading, rows, price, earnings ($theme)', (
      tester,
    ) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_step(dark: dark, price: r'$3,600'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, c.background);
      final progress = tester.widget<StudioProgressSegments>(find.byType(StudioProgressSegments));
      expect((progress.current, progress.total), (1, 3));
      expect(find.text('Your piece'), findsOneWidget);
      expect(find.text('4 photos'), findsOneWidget);
      final heading = tester.widget<Text>(find.text('How do you want to share it?'));
      expect(heading.style!.fontSize, 30);
      expect(heading.style!.color, c.textPrimary);
      expect(find.text('This decides what details we ask for next.'), findsOneWidget);

      final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).toList();
      expect(rows.map((r) => r.title), ['Fixed price', 'Auction', 'Not for sale']);
      expect(rows.map((r) => r.selected), [true, false, false]);
      expect(rows[1].subtitle, '3 to 14 days, highest bid wins');
      expect(rows.first.titleSize, 19);
      expect(rows.first.subtitleSize, 13);
      expect(rows.last.divider, isFalse);

      final price = tester.widget<StudioUnderlineField>(find.byType(StudioUnderlineField));
      expect((price.label, price.valueSize), ('Price', 18));
      expect(
        _plain(tester, _earnings),
        "You'll receive \$3,060 after the 15% fee. See fees",
      );
      expect(_continue(tester).onPressed, isNotNull);
    });

    testWidgets('not for sale: no price and no earnings line ($theme)', (tester) async {
      setBoardViewport(tester);
      await tester.pumpWidget(_step(dark: dark, forSale: false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StudioUnderlineField), findsNothing);
      expect(_earnings, findsNothing);
      final rows = tester.widgetList<StudioSelectRow>(find.byType(StudioSelectRow)).toList();
      expect(rows.map((r) => r.selected), [false, false, true]);
      expect(_continue(tester).onPressed, isNotNull);
    });

    testWidgets('auction: starting bid, duration with the end date, private reserve ($theme)', (
      tester,
    ) async {
      setBoardViewport(tester, height: 900);
      await tester.pumpWidget(
        _step(dark: dark, mode: SaleMode.auction, start: r'$360', reserve: r'$1,200'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final fields = tester.widgetList<StudioUnderlineField>(find.byType(StudioUnderlineField));
      expect(fields.map((f) => f.label), ['Starting bid', 'Reserve price']);
      expect(find.text('7 days'), findsOneWidget);
      expect(tester.widget<Text>(find.text('7 days')).style!.fontFamily, contains('Mono'));
      expect(find.text('optional · private'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'Ends Nov 1 · 6:40 PM',
        ),
        findsOneWidget,
      );
      expect(_earnings, findsNothing);
      expect(_continue(tester).onPressed, isNotNull);
    });
  }

  testWidgets('auction duration stays within 3 to 14 days', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_step(mode: SaleMode.auction, start: r'$360'));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.bySemanticsLabel('Fewer days'));
      await tester.pump();
    }
    expect(find.text('3 days'), findsOneWidget);
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.bySemanticsLabel('More days'));
      await tester.pump();
    }
    expect(find.text('14 days'), findsOneWidget);
  });

  testWidgets('auction: Continue needs a starting bid, and a reserve no lower than it', (
    tester,
  ) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_step(mode: SaleMode.auction));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_continue(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '360');
    await tester.pump();
    expect(_continue(tester).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.pump();
    expect(_continue(tester).onPressed, isNull);
    expect(find.text('Set it at or above the starting bid.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '1200');
    await tester.pump();
    expect(_continue(tester).onPressed, isNotNull);
  });

  testWidgets('auction tooltips explain timing and the reserve', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_step(mode: SaleMode.auction, start: r'$360'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_info('What is a reserve price?'));
    await tester.pump();
    expect(find.textContaining('Bidders never see it.'), findsOneWidget);
    await tester.tap(_info('What is auction timing?'));
    await tester.pump();
    expect(find.textContaining('There are no extensions'), findsOneWidget);
  });

  testWidgets('Continue is off until a price above 0; price formats as typed', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step());
    await tester.pump(const Duration(milliseconds: 400));
    expect(_continue(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '3600');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(r'$3,600'), findsOneWidget);
    expect(_continue(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_continue(tester).onPressed, isNull);
  });

  testWidgets("the account's own rate as a fee, never 'founding'; before a price, the rate alone", (
    tester,
  ) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step(quote: _standard));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_plain(tester, _earnings), "You'll receive your price less the 20% fee. See fees");

    await tester.enterText(find.byType(TextField), '125.5');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_plain(tester, _earnings), "You'll receive \$100.40 after the 20% fee. See fees");
  });

  testWidgets('a failed quote hides the earnings line', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step(price: r'$100', quote: (_) async => throw Exception('offline')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_earnings, findsNothing);
    expect(find.byType(StudioUnderlineField), findsOneWidget);
  });

  testWidgets('rows switch availability; back, Edit and Continue call through', (tester) async {
    setBoardViewport(tester);
    final calls = <String>[];
    await tester.pumpWidget(
      _step(
        price: r'$10',
        onChanged: (v) => calls.add('mode:${v.name}'),
        onBack: () => calls.add('back'),
        onEdit: () => calls.add('edit'),
        onContinue: () => calls.add('continue'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_row('Not for sale'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StudioUnderlineField), findsNothing);
    await tester.tap(_row('Fixed price'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('Continue'));
    expect(calls, ['mode:notForSale', 'mode:fixed', 'back', 'edit', 'continue']);
  });

  testWidgets('See fees opens the seller terms (no info button)', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step(price: r'$3,600'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StudioInfoButton), findsNothing);
    expect(find.textContaining('founding', findRichText: true), findsNothing);
    final rich = tester.widget<RichText>(_earnings);
    TapGestureRecognizer? link;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'See fees') link = span.recognizer as TapGestureRecognizer?;
      return true;
    });
    expect(link, isNotNull);
    link!.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('terms page'), findsOneWidget);
  });

  testWidgets('375 wide at text scale 1.4 does not overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667), textScaler: TextScaler.linear(1.4)),
        child: _step(price: r'$3,600'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  group('in the posting flow', () {
    late bool wasSeller;
    setUp(() => wasSeller = AuthSession.instance.sellerEnabled);
    tearDown(() => AuthSession.instance.sellerEnabled = wasSeller);

    Widget page({required VoidCallback onEdit}) => MaterialApp(
      theme: AppTheme.light,
      home: PostCreatePage(
        postType: 'piece',
        imagePaths: [_photo],
        transforms: [PostImageTransform()],
        previewImageIndex: 0,
        onClose: () {},
        onEdit: onEdit,
        commissionQuote: _founding,
      ),
    );

    testWidgets('pieces start on availability; Continue → details; back steps one at a time', (
      tester,
    ) async {
      setBoardViewport(tester);
      AuthSession.instance.sellerEnabled = true;
      var edits = 0;
      await tester.pumpWidget(page(onEdit: () => edits++));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('How do you want to share it?'), findsOneWidget);
      // Sellers start on Fixed price, as the old "List for sale" switch did.
      expect(tester.widget<StudioSelectRow>(_row('Fixed price')).selected, isTrue);
      expect(_continue(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '3600');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('How do you want to share it?'), findsNothing);
      expect(find.text('Tell us about it'), findsOneWidget);
      expect(find.text('List for sale'), findsNothing); // decided on step 1 now

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('How do you want to share it?'), findsOneWidget);
      // The price survived the round trip.
      expect(find.text(r'$3,600'), findsOneWidget);
      expect(edits, 0);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(edits, 1);
    });

    testWidgets('non-sellers start on Not for sale', (tester) async {
      setBoardViewport(tester);
      AuthSession.instance.sellerEnabled = false;
      await tester.pumpWidget(page(onEdit: () {}));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<StudioSelectRow>(_row('Not for sale')).selected, isTrue);
      expect(_continue(tester).onPressed, isNotNull);
    });
  });

  testWidgets('golden: PostAvailFixed', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step(price: r'$3,600'));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostAvailFixed.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');

  testWidgets('golden: PostAvailAuction', (tester) async {
    setBoardViewport(tester, height: 900);
    await tester.pumpWidget(_step(mode: SaleMode.auction, start: r'$360', reserve: r'$1,200'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_info('What is a reserve price?'));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostAvailAuction.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');

  testWidgets('golden: PostNFSAvail', (tester) async {
    setBoardViewport(tester);
    await tester.pumpWidget(_step(forSale: false));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/PostNFSAvail.png'));
    await checkAcceptance(tester);
  }, skip: Platform.environment['NEW_UI_GOLDENS'] != '1');
}


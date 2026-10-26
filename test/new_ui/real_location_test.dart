import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio3/data/post_location_options.dart';
import 'package:studio3/models/auth_user.dart';
import 'package:studio3/models/street_address.dart';
import 'package:studio3/screens/address_form_page.dart';
import 'package:studio3/screens/edit_profile_page.dart';
import 'package:studio3/services/api_client.dart';
import 'package:studio3/services/auth_session.dart';
import 'package:studio3/services/location_search_service.dart';
import 'package:studio3/theme/app_theme.dart';
import 'package:studio3/widgets/choose_location_sheet.dart';
import 'package:studio3/widgets/studio/studio.dart';

import 'golden_harness.dart';

/// Every location field takes a real, named place — never an IP guess and never the phone's
/// bare coordinates: the city sheet (pieces, posts, scenes, the profile), an event's venue,
/// and the address form (`BuyAddress` "Search your address").

/// Nominatim results as the real service sends them (`jsonv2`, `addressdetails=1`).
const _dallas = {
  'place_id': 101,
  'lat': '32.7767',
  'lon': '-96.7970',
  'name': 'Dallas',
  'display_name': 'Dallas, Dallas County, Texas, United States',
  'address': {
    'city': 'Dallas',
    'county': 'Dallas County',
    'state': 'Texas',
    'ISO3166-2-lvl4': 'US-TX',
    'country': 'United States',
    'country_code': 'us',
  },
};
const _paris = {
  'place_id': 102,
  'lat': '48.85',
  'lon': '2.35',
  'name': 'Paris',
  'display_name': 'Paris, Île-de-France, France',
  'address': {'city': 'Paris', 'state': 'Île-de-France', 'country': 'France', 'country_code': 'fr'},
};
const _dragonSt = {
  'place_id': 201,
  'lat': '32.7942',
  'lon': '-96.8131',
  'display_name': '1414, Dragon Street, Design District, Dallas, Dallas County, Texas, 75207, United States',
  'address': {
    'house_number': '1414',
    'road': 'Dragon Street',
    'suburb': 'Design District',
    'city': 'Dallas',
    'state': 'Texas',
    'ISO3166-2-lvl4': 'US-TX',
    'postcode': '75207',
    'country': 'United States',
    'country_code': 'us',
  },
};

class _Fake implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  Iterable<Map<String, dynamic>?> bodies(String method, String path) => requests
      .where((r) => r.method == method && r.uri.path == path)
      .map((r) => r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final q = options.uri.queryParameters;
    Object? json;
    switch ('${options.method} ${options.uri.path}') {
      case 'GET /search':
        if (q.containsKey('street')) {
          // Structured lookup of a typed address.
          json = q['street'] == '500 Main St'
              ? [
                  {'lat': '32.7810', 'lon': '-96.7990'},
                ]
              : [];
        } else if (q['featureType'] == 'settlement') {
          json = [_dallas, _paris];
        } else {
          json = [_dragonSt];
        }
      case 'GET /reverse':
        json = q['zoom'] == '10' ? _dallas : _dragonSt;
      case 'GET /api/user/me':
        json = {
          'success': true,
          'data': {'username': 'sarah', 'name': 'Sarah Osmei', 'location': 'somewhere I typed'},
        };
      case 'PATCH /api/user/me':
        json = {'success': true, 'data': options.data};
      case 'POST /api/user/me/addresses':
        json = {
          'success': true,
          'data': {...(options.data as Map), 'id': 'a1'},
        };
      default:
        return ResponseBody.fromString(jsonEncode({'success': false, 'message': 'no route'}), 404, headers: _h);
    }
    return ResponseBody.fromString(jsonEncode(json), 200, headers: _h);
  }

  static final _h = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

late _Fake _server;

Finder _button(String label) => find.byWidgetPredicate((w) => w is StudioButton && w.label == label);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
  }
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// Types into a search field and lets the 400 ms debounce and the fake service run.
Future<void> _search(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 450));
  await _settle(tester);
}

/// The phone's GPS (geolocator's method channel): permission granted, at Dragon St.
void _mockGps() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => switch (call.method) {
      'checkPermission' || 'requestPermission' => 2, // whileInUse
      'isLocationServiceEnabled' => true,
      'getCurrentPosition' => {
        'latitude': 32.7942,
        'longitude': -96.8131,
        'timestamp': 0,
        'accuracy': 5.0,
        'altitude': 0.0,
        'altitude_accuracy': 0.0,
        'heading': 0.0,
        'heading_accuracy': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
      },
      _ => null,
    },
  );
}

Widget _opener(void Function(BuildContext) open) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () => open(context), child: const Text('open')),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    await loadStudioFonts();
  });

  late AuthUser? wasUser;
  late String? wasToken;
  setUp(() {
    _server = _Fake();
    ApiClient.instance.debugUseAdapter(_server);
    LocationSearchService.debugUseAdapter(_server);
    _mockGps();
    wasUser = AuthSession.instance.user;
    wasToken = AuthSession.instance.accessToken;
    AuthSession.instance.user = const AuthUser(username: 'sarah', name: 'Sarah Osmei', email: 's@example.test');
    AuthSession.instance.accessToken = 'token';
  });
  tearDown(() {
    AuthSession.instance.user = wasUser;
    AuthSession.instance.accessToken = wasToken;
  });

  group('parsing', () {
    test('a city reads "Dallas, TX" in the US and "Paris, France" elsewhere', () {
      final dallas = PostLocationOption.cityFromNominatim(_dallas)!;
      expect((dallas.name, dallas.displayName, dallas.subtitle), ('Dallas', 'Dallas, TX', 'Texas, United States'));
      expect((dallas.lat, dallas.lng), (32.7767, -96.7970));
      expect(PostLocationOption.cityFromNominatim(_paris)!.displayName, 'Paris, France');
      // Not in a city (a lake, a county): no answer rather than a made-up one.
      expect(PostLocationOption.cityFromNominatim(const {'address': {'county': 'Dallas County'}}), isNull);
    });

    test('a street address splits into the form\'s fields', () {
      final a = StreetAddress.fromNominatim(_dragonSt)!;
      expect((a.line1, a.city, a.state, a.zip), ('1414 Dragon Street', 'Dallas', 'TX', '75207'));
      expect((a.lat, a.lng), (32.7942, -96.8131));
      expect(StreetAddress.fromNominatim(_dallas), isNull); // a city, not an address
      expect(StreetAddress.fromNominatim(_paris), isNull);
    });
  });

  group('the city sheet (pieces, posts, scenes, profile)', () {
    testWidgets('search finds cities only; Done gives "Dallas, TX" with its coordinates', (tester) async {
      setBoardViewport(tester);
      PostLocationOption? picked;
      await tester.pumpWidget(_opener((context) => ChooseLocationSheet.show(context, onLocationSelected: (l) => picked = l)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _search(tester, find.byType(TextField), 'Dall');
      final search = _server.requests.lastWhere((r) => r.uri.path == '/search');
      expect(search.uri.queryParameters['featureType'], 'settlement');
      expect(find.text('Texas, United States'), findsOneWidget);
      await tester.tap(find.text('Dallas'));
      await tester.pump();
      await tester.tap(_button('Done'));
      await _settle(tester);
      expect((picked!.displayName, picked!.lat), ('Dallas, TX', 32.7767));
    });

    testWidgets('Use my current city gives the city the phone is in, not its street', (tester) async {
      setBoardViewport(tester);
      PostLocationOption? picked;
      await tester.pumpWidget(_opener((context) => ChooseLocationSheet.show(context, onLocationSelected: (l) => picked = l)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use my current city'));
      await _settle(tester);
      final reverse = _server.requests.lastWhere((r) => r.uri.path == '/reverse');
      expect(reverse.uri.queryParameters['zoom'], '10');
      await tester.tap(_button('Done'));
      await _settle(tester);
      expect(picked!.displayName, 'Dallas, TX');
      expect(picked!.displayName, isNot(contains('Dragon')));
    });

    testWidgets("an event's venue finds addresses and where the phone is, to the building", (tester) async {
      setBoardViewport(tester);
      PostLocationOption? picked;
      await tester.pumpWidget(
        _opener(
          (context) => ChooseLocationSheet.show(
            context,
            cityOnly: false,
            currentLabel: 'Use where I am now',
            onLocationSelected: (l) => picked = l,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use where I am now'));
      await _settle(tester);
      expect(_server.requests.lastWhere((r) => r.uri.path == '/reverse').uri.queryParameters['zoom'], '18');
      await tester.tap(_button('Done'));
      await _settle(tester);
      expect(picked!.displayName, contains('Dragon Street'));
    });
  });

  group('Edit profile', () {
    testWidgets('Location is picked from the city sheet, not typed; it saves the city and its coordinates', (
      tester,
    ) async {
      setBoardViewport(tester, height: 1400);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EditProfilePage()));
      await _settle(tester);
      final field = find.byWidgetPredicate((w) => w is StudioUnderlineField && w.label == 'Location');
      expect(tester.widget<StudioUnderlineField>(field).readOnly, isTrue);
      expect(find.text('Use my current location'), findsNothing); // no raw-GPS button

      await tester.tap(field);
      await tester.pumpAndSettle();
      await _search(tester, find.byType(TextField).last, 'Dall');
      await tester.tap(find.text('Dallas'));
      await tester.pump();
      await tester.tap(_button('Done'));
      await _settle(tester);
      expect(find.text('Dallas, TX'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await _settle(tester);
      final body = _server.bodies('PATCH', '/api/user/me').single!;
      expect((body['location'], body['latitude'], body['longitude']), ('Dallas, TX', 32.7767, -96.7970));
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Address form (BuyAddress)', () {
    Future<void> fillContact(WidgetTester tester) async {
      Finder f(String label) => find.byWidgetPredicate((w) => w is StudioUnderlineField && w.label == label);
      await tester.enterText(find.descendant(of: f('First name'), matching: find.byType(TextField)), 'Alex');
      await tester.enterText(find.descendant(of: f('Last name'), matching: find.byType(TextField)), 'Smith');
      await tester.enterText(find.descendant(of: f('Phone'), matching: find.byType(TextField)), '2145550142');
      await tester.pump();
    }

    testWidgets('Search your address fills the fields; the saved coordinates are that address\'s', (tester) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AddressFormPage()));
      await tester.pump();
      expect(find.text('Search your address'), findsOneWidget);
      await _search(tester, find.byType(TextField).first, '1414 Dragon');
      expect(find.text('1414 Dragon Street'), findsOneWidget);
      expect(find.text('Dallas, TX 75207'), findsOneWidget);
      await tester.tap(find.text('1414 Dragon Street'));
      await tester.pump();
      for (final value in ['1414 Dragon Street', 'Dallas', 'TX', '75207']) {
        expect(find.widgetWithText(TextField, value), findsOneWidget, reason: value);
      }
      await fillContact(tester);
      await tester.tap(_button('Save address'));
      await _settle(tester);
      final saved = _server.bodies('POST', '/api/user/me/addresses').single!;
      expect((saved['line1'], saved['city'], saved['state'], saved['zip']), ('1414 Dragon Street', 'Dallas', 'TX', '75207'));
      expect((saved['latitude'], saved['longitude']), (32.7942, -96.8131));
      // Found by search, so nothing to look up again.
      expect(_server.requests.where((r) => r.uri.queryParameters.containsKey('street')), isEmpty);
    });

    testWidgets('Use my current location fills in the street address the phone is at', (tester) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AddressFormPage()));
      await tester.pump();
      await tester.ensureVisible(_button('Use my current location'));
      await tester.tap(_button('Use my current location'));
      await _settle(tester);
      expect(find.widgetWithText(TextField, '1414 Dragon Street'), findsOneWidget);
      expect(find.widgetWithText(TextField, '75207'), findsOneWidget);
      expect(find.text('Location captured'), findsNothing);
    });

    testWidgets('a typed address is looked up on save; GPS from elsewhere is not kept', (tester) async {
      setBoardViewport(tester, height: 1200);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AddressFormPage()));
      await tester.pump();
      // Fill from where the phone is, then type a different address over it.
      await tester.ensureVisible(_button('Use my current location'));
      await tester.tap(_button('Use my current location'));
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '1414 Dragon Street'), '500 Main St');
      await tester.pump();
      await fillContact(tester);
      await tester.ensureVisible(_button('Save address'));
      await tester.tap(_button('Save address'));
      await _settle(tester);
      final lookup = _server.requests.lastWhere((r) => r.uri.queryParameters.containsKey('street'));
      expect(lookup.uri.queryParameters, containsPair('street', '500 Main St'));
      expect(lookup.uri.queryParameters, containsPair('postalcode', '75207'));
      final saved = _server.bodies('POST', '/api/user/me/addresses').single!;
      expect((saved['line1'], saved['latitude'], saved['longitude']), ('500 Main St', 32.7810, -96.7990));
    });
  });
}

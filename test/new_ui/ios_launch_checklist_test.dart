import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/utils/qr_image_share.dart';

/// iOS launch checklist (`docs/new-ui/APPLE_LAUNCH_CHECKLIST.md`). 1.1: sharing a QR code and tapping
/// the share sheet's "Save Image" crashed on iPhone (no photo-saving text in Info.plist), and
/// the sheet could not open at all on an iPad when no anchor was given. 1.2: the build answers
/// Apple's export (encryption) question itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Info.plist', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    String? text(String key) =>
        RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(plist)?.group(1)?.trim();

    test('says why the app saves to Photos (Save Image on a shared QR code)', () {
      expect(text('NSPhotoLibraryAddUsageDescription'), 'Studio3 saves the QR codes you choose to your photo library.');
    });

    // Launch checklist 1.2: answers Apple's export question in the build, so uploads stop
    // asking. True to the app: HTTPS through iOS, and Ed25519 only to check the signature on
    // ticket codes (lib/services/offline_check_in.dart), both exempt.
    test('declares no non-exempt encryption', () {
      expect(plist, matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')));
    });

    test('says why for every permission the app asks for', () {
      for (final key in [
        'NSPhotoLibraryUsageDescription', // picking photos and videos to post
        'NSPhotoLibraryAddUsageDescription', // Save Image
        'NSCameraUsageDescription', // taking a photo, scanning a code
        'NSLocationWhenInUseUsageDescription', // addresses, nearby sellers
        'NSCalendarsWriteOnlyAccessUsageDescription', // adding an event
      ]) {
        expect(text(key), isNotEmpty, reason: '$key is missing or empty: iOS stops the app when it asks');
      }
    });
  });

  // Launch checklist 1.3: the privacy manifest exists, says what the app collects (in step with
  // the App Privacy answers, checklist 4.2), and is copied into the app.
  group('privacy manifest', () {
    final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    test('no tracking, no tracking domains', () {
      expect(manifest, matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')));
      expect(manifest, matches(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>')));
    });

    test('declares what the app collects, linked, never for tracking, for its own features', () {
      const collected = [
        'Name', 'EmailAddress', 'PhoneNumber', 'UserID', 'PhysicalAddress', 'PreciseLocation',
        'PhotosorVideos', 'EmailsOrTextMessages', 'OtherUserContent', 'PurchaseHistory', 'PaymentInfo',
      ];
      final entries = RegExp(r'<dict>\s*<key>NSPrivacyCollectedDataType</key>(.*?)</dict>', dotAll: true)
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toList();
      final types = [
        for (final e in entries) RegExp(r'<string>NSPrivacyCollectedDataType(\w+)</string>').firstMatch(e)!.group(1),
      ];
      expect(types, unorderedEquals(collected));
      for (final e in entries) {
        expect(e, matches(RegExp(r'<key>NSPrivacyCollectedDataTypeLinked</key>\s*<true/>')));
        expect(e, matches(RegExp(r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<false/>')));
        expect(e, contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'));
      }
    });

    test('gives the reasons for the APIs plugins without their own manifest use', () {
      String? reasons(String category) => RegExp(
        '<string>NSPrivacyAccessedAPICategory$category</string>\\s*<key>NSPrivacyAccessedAPITypeReasons</key>\\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(manifest)?.group(1);
      expect(reasons('UserDefaults'), contains('CA92.1'), reason: 'stripe_ios uses UserDefaults');
      expect(reasons('FileTimestamp'), contains('C617.1'), reason: 'easy_video_editor reads file dates');
    });

    test('is copied into the app (Runner group and Resources phase)', () {
      final fileRef = RegExp(r'(\w{24}) /\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference;').firstMatch(pbxproj);
      expect(fileRef, isNotNull, reason: 'no file reference in project.pbxproj');
      final buildFile = RegExp('(\\w{24}) /\\* PrivacyInfo\\.xcprivacy in Resources \\*/ = \\{isa = PBXBuildFile; fileRef = ${fileRef!.group(1)}')
          .firstMatch(pbxproj);
      expect(buildFile, isNotNull, reason: 'no build file for it');
      final resources = RegExp(r'/\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;(.*?)\};', dotAll: true)
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .where((phase) => phase.contains('Assets.xcassets in Resources'));
      expect(resources.single, contains('${buildFile!.group(1)} /* PrivacyInfo.xcprivacy in Resources */'));
    });
  });

  // Launch checklist 1.5: iPhone and iPad (the user's call, 17 Nov 2026).
  group('iPhone and iPad', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('every build configuration targets iPhone and iPad', () {
      final families = RegExp(r'TARGETED_DEVICE_FAMILY = "?([\d,]+)"?;').allMatches(pbxproj).map((m) => m.group(1));
      expect(families, isNotEmpty);
      expect(families, everyElement('1,2'));
    });

    test('iPad supports every orientation (needed for iPad multitasking)', () {
      final ipad = RegExp(r'<key>UISupportedInterfaceOrientations~ipad</key>\s*<array>(.*?)</array>', dotAll: true)
          .firstMatch(plist)
          ?.group(1);
      expect(ipad, isNotNull);
      for (final o in ['Portrait', 'PortraitUpsideDown', 'LandscapeLeft', 'LandscapeRight']) {
        expect(ipad, contains('<string>UIInterfaceOrientation$o</string>'));
      }
    });
  });

  group('sharing codes as images', () {
    final calls = <Map<Object?, Object?>>[];
    late Directory tmp;

    setUp(() {
      calls.clear();
      tmp = Directory.systemTemp.createTempSync('qr_share');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
        return tmp.path;
      });
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        calls.add(call.arguments as Map<Object?, Object?>);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
    });

    tearDown(() {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
      tmp.deleteSync(recursive: true);
    });

    void expectAnchored(Map<Object?, Object?> args) {
      expect(args['originWidth'], greaterThan(0), reason: 'no anchor: the sheet cannot open on an iPad');
      expect(args['originHeight'], greaterThan(0));
    }

    testWidgets('one code: the PNG and the link go out, anchored even without a button', (tester) async {
      await tester.runAsync(() => QrImageShare.share(title: 'Bodies in Color', url: 'https://studio-3.co/p/1'));
      final args = calls.single;
      final paths = (args['paths'] as List).cast<String>();
      expect(paths.single, endsWith('bodies-in-color-code.png'));
      expect(File(paths.single).lengthSync(), greaterThan(0));
      expect((args['mimeTypes'] as List).single, 'image/png');
      expect(args['text'], 'Bodies in Color\nhttps://studio-3.co/p/1');
      expectAnchored(args);
    });

    testWidgets('a given anchor is kept', (tester) async {
      await tester.runAsync(
        () => QrImageShare.share(title: 'A', url: 'https://studio-3.co/p/2', origin: const Rect.fromLTWH(10, 20, 30, 40)),
      );
      final args = calls.single;
      expect([args['originX'], args['originY'], args['originWidth'], args['originHeight']], [10, 20, 30, 40]);
    });

    testWidgets('Download all: every code, names kept apart, anchored', (tester) async {
      await tester.runAsync(
        () => QrImageShare.shareAll([
          (title: 'Dusk', url: 'https://studio-3.co/p/1'),
          (title: 'Dusk', url: 'https://studio-3.co/p/2'),
        ]),
      );
      final args = calls.single;
      final paths = (args['paths'] as List).cast<String>();
      expect(paths.map((p) => p.split(Platform.pathSeparator).last.split('/').last), ['dusk-code.png', 'dusk-2-code.png']);
      expectAnchored(args);
    });
  });
}

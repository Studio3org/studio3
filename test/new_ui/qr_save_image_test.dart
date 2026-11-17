import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/utils/qr_image_share.dart';

/// Launch checklist 1.1 (`docs/new-ui/APPLE_LAUNCH_CHECKLIST.md`): sharing a QR code and tapping
/// the share sheet's "Save Image" crashed on iPhone (no photo-saving text in Info.plist), and
/// the sheet could not open at all on an iPad when no anchor was given.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Info.plist', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    String? text(String key) =>
        RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(plist)?.group(1)?.trim();

    test('says why the app saves to Photos (Save Image on a shared QR code)', () {
      expect(text('NSPhotoLibraryAddUsageDescription'), 'Studio3 saves the QR codes you choose to your photo library.');
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

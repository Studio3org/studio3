import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/config/api_config.dart';

void main() {
  group('release builds only ever talk to the real server', () {
    String release(String override, {String host = ''}) =>
        ApiConfig.resolve(baseUrlOverride: override, hostOverride: host, release: true);

    test('a local test address baked into a build is ignored (the 22 Nov TestFlight bug)', () {
      expect(release('http://localhost:9100'), 'https://api.studio-3.co');
      expect(release('http://10.0.2.2:9000'), 'https://api.studio-3.co');
      expect(release('http://192.168.1.20:9000'), 'https://api.studio-3.co');
      expect(release('https://127.0.0.1:9000'), 'https://api.studio-3.co');
      expect(release('', host: '10.0.2.2'), 'https://api.studio-3.co');
    });

    test('plain http is never used in a release build', () {
      expect(release('http://api.example.com'), 'https://api.studio-3.co');
    });

    test('a real https server can still be chosen deliberately', () {
      expect(release('https://staging.studio-3.co'), 'https://staging.studio-3.co');
      expect(release(''), 'https://api.studio-3.co');
    });
  });

  test('debug runs keep using whatever they were pointed at', () {
    expect(
      ApiConfig.resolve(baseUrlOverride: 'http://localhost:9100', hostOverride: '', release: false),
      'http://localhost:9100',
    );
    expect(
      ApiConfig.resolve(baseUrlOverride: '', hostOverride: '', release: false, fromEnv: 'http://10.0.2.2:9000'),
      'http://10.0.2.2:9000',
    );
  });
}

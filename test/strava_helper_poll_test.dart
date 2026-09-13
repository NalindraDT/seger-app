import 'package:flutter_test/flutter_test.dart';
import 'package:pltuapp/helpers/strava_helper.dart';

void main() {
  group('StravaHelper.pollUntilConnected', () {
    test('stops early once connected', () async {
      var calls = 0;
      final connected = await StravaHelper.pollUntilConnected(
        () async => ++calls >= 3,
        interval: const Duration(seconds: 2),
        sleep: (_) async {},
      );
      expect(connected, isTrue);
      expect(calls, 3);
    });

    test('gives up after the timeout without throwing', () async {
      var calls = 0;
      final connected = await StravaHelper.pollUntilConnected(
        () async {
          calls++;
          return false;
        },
        interval: const Duration(seconds: 1),
        timeout: const Duration(seconds: 3),
        sleep: (_) async {},
      );
      expect(connected, isFalse);
      expect(calls, 3);
    });

    test('keeps polling when a probe throws', () async {
      var calls = 0;
      final connected = await StravaHelper.pollUntilConnected(
        () async {
          calls++;
          if (calls < 2) throw Exception('sementara');
          return true;
        },
        sleep: (_) async {},
      );
      expect(connected, isTrue);
      expect(calls, 2);
    });
  });
}

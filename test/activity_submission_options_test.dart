import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pltuapp/screens/user/activity_submission_screen.dart';

/// Widget test untuk dropdown "Di catat dengan": daftar opsi harus datang dari
/// backend dan default-nya Strava.
void main() {
  const optionStrava = {
    'id': 1,
    'code': 'strava',
    'label': 'Strava',
    'icon': 'strava',
    'requires_source_link': false,
    'is_active': true,
    'sort_order': 0,
    'is_locked': true,
  };
  const optionSmartwatch = {
    'id': 2,
    'code': 'smartwatch',
    'label': 'Smartwatch',
    'icon': 'watch',
    'requires_source_link': true,
    'is_active': true,
    'sort_order': 1,
    'is_locked': false,
  };
  const activityType = {
    'id': 1,
    'code': 'running',
    'name': 'Running',
    'is_active': true,
    'input_fields': [
      {'key': 'distance_km', 'label': 'Jarak', 'type': 'number', 'unit': 'km', 'required': true},
      {'key': 'duration_minutes', 'label': 'Durasi', 'type': 'number', 'unit': 'menit', 'required': true},
      {'key': 'duration_seconds', 'label': 'Detik', 'type': 'number', 'unit': 'detik', 'required': false},
    ],
    'output_metrics': <Object>[],
  };

  http.Response ok(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );

  final client = MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/recorded-via-options')) {
      return ok({
        'success': true,
        'data': [optionStrava, optionSmartwatch],
      });
    }

    if (path.endsWith('/activities/types')) {
      return ok({
        'success': true,
        'data': [activityType],
      });
    }

    if (path.endsWith('/strava/status')) {
      return ok({
        'success': true,
        'data': {'configured': true, 'connected': false, 'athlete': null},
      });
    }

    return ok({'success': true, 'data': <Object>[]});
  });

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://backend.test/api/v1');
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ActivitySubmissionScreen()));
      await tester.pumpAndSettle();
    }, () => client);
  }

  testWidgets('daftar opsi terisi dari API dan default terpilih Strava', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Di catat dengan'), findsOneWidget);
    // Default terpilih otomatis: Strava.
    expect(find.text('Strava'), findsOneWidget);
  });

  testWidgets('opsi tambahan dari backend muncul, list hardcoded lama tidak', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Strava'));
    await tester.pumpAndSettle();

    expect(find.text('Smartwatch'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
  });

  testWidgets('opsi dengan requires_source_link menandai link sumber wajib', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Strava'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smartwatch').last);
    await tester.pumpAndSettle();

    expect(find.text('Link Sumber (Wajib)'), findsOneWidget);
    expect(find.text('Link Strava (Wajib)'), findsNothing);
  });
}

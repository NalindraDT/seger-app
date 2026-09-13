import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pltuapp/helpers/api_helper.dart';

class StravaStatus {
  final bool configured;
  final bool connected;
  final int? athleteId;
  final String? athleteName;

  const StravaStatus({
    required this.configured,
    required this.connected,
    this.athleteId,
    this.athleteName,
  });

  factory StravaStatus.fromJson(Map<String, dynamic>? data) {
    final athlete = data?['athlete'];
    final firstname = athlete is Map ? athlete['firstname']?.toString() : null;
    final lastname = athlete is Map ? athlete['lastname']?.toString() : null;
    final name = [firstname, lastname].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return StravaStatus(
      configured: data?['configured'] == true,
      connected: data?['connected'] == true,
      athleteId: athlete is Map ? int.tryParse(athlete['id']?.toString() ?? '') : null,
      athleteName: name.isEmpty ? null : name,
    );
  }
}

class StravaActivity {
  final int id;
  final String name;
  final String type;
  final String sportType;
  final String sportGroup;
  final String activityDate;
  final double distanceKm;
  final int durationMinutes;
  final int durationSeconds;
  final String sourceLink;
  final bool alreadySubmitted;
  final double? calories;
  final double? elevationM;

  const StravaActivity({
    required this.id,
    required this.name,
    required this.type,
    required this.sportType,
    required this.sportGroup,
    required this.activityDate,
    required this.distanceKm,
    required this.durationMinutes,
    required this.durationSeconds,
    required this.sourceLink,
    required this.alreadySubmitted,
    this.calories,
    this.elevationM,
  });

  factory StravaActivity.fromJson(Map<String, dynamic> json) {
    return StravaActivity(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? 'Aktivitas Strava',
      type: json['type']?.toString() ?? '-',
      sportType: json['sport_type']?.toString() ?? '-',
      sportGroup: json['sport_group']?.toString() ?? 'other',
      activityDate: json['activity_date']?.toString() ?? '',
      distanceKm: double.tryParse(json['distance_km']?.toString() ?? '0') ?? 0,
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '0') ?? 0,
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? '0') ?? 0,
      sourceLink: json['source_link']?.toString() ?? '',
      alreadySubmitted: json['already_submitted'] == true,
      calories: double.tryParse(json['calories']?.toString() ?? ''),
      elevationM: double.tryParse(json['elevation_m']?.toString() ?? ''),
    );
  }

  String get durationLabel {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      return minutes > 0 ? '$hours j $minutes mnt' : '$hours j';
    }
    if (durationSeconds > 0) {
      return '$durationMinutes mnt $durationSeconds dtk';
    }
    return '$durationMinutes mnt';
  }

  String get distanceLabel => '${distanceKm.toStringAsFixed(distanceKm.truncateToDouble() == distanceKm ? 0 : 2)} km';
}

class StravaApiException implements Exception {
  final int statusCode;
  final String message;
  const StravaApiException(this.statusCode, this.message);
}

class StravaHelper {
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      return body['error']?['message']?.toString() ?? body['message']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<StravaStatus> fetchStatus() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiHelper.baseUrl}/strava/status'),
      headers: _headers(token),
    );
    if (response.statusCode == 401) {
      throw const StravaApiException(401, 'Sesi berakhir');
    }
    if (response.statusCode != 200) {
      throw StravaApiException(response.statusCode, _errorMessage(response, 'Gagal memuat status Strava'));
    }
    final body = jsonDecode(response.body);
    return StravaStatus.fromJson(body['data'] as Map<String, dynamic>?);
  }

  static Future<void> connect() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiHelper.baseUrl}/strava/authorize'),
      headers: _headers(token),
    );
    if (response.statusCode == 401) {
      throw const StravaApiException(401, 'Sesi berakhir');
    }
    if (response.statusCode != 200) {
      throw StravaApiException(response.statusCode, _errorMessage(response, 'Gagal memulai koneksi Strava'));
    }
    final url = jsonDecode(response.body)['data']?['authorize_url']?.toString();
    if (url == null || url.isEmpty) {
      throw const StravaApiException(500, 'URL otorisasi Strava tidak tersedia');
    }
    final uri = Uri.parse(url);
    // Di web url_launcher_web hanya mendukung platformDefault (mode lain
    // diabaikan dan tetap membuka tab baru), jadi pakai platformDefault.
    final launched = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const StravaApiException(500, 'Tidak bisa membuka Strava');
    }
    // Di web tidak ada event lifecycle resume setelah user otorisasi di tab
    // Strava, jadi status dipoll sampai terhubung (atau timeout).
    if (kIsWeb) {
      await pollUntilConnected(() async => (await fetchStatus()).connected);
    }
  }

  /// Poll [probe] setiap [interval] sampai bernilai true, berhenti lebih awal
  /// saat sudah terhubung. Berhenti (tanpa throw) setelah [timeout] tercapai
  /// agar caller tetap bisa me-refresh status walau user lambat.
  @visibleForTesting
  static Future<bool> pollUntilConnected(
    Future<bool> Function() probe, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    Future<void> Function(Duration) sleep = Future<void>.delayed,
  }) async {
    final attempts = (timeout.inMilliseconds / interval.inMilliseconds).ceil();
    for (var i = 0; i < attempts; i++) {
      await sleep(interval);
      try {
        if (await probe()) return true;
      } catch (_) {
        // Abaikan error sementara selama proses otorisasi berlangsung.
      }
    }
    return false;
  }

  static Future<void> disconnect() async {
    final token = await _token();
    final response = await http.delete(
      Uri.parse('${ApiHelper.baseUrl}/strava/disconnect'),
      headers: _headers(token),
    );
    if (response.statusCode == 401) {
      throw const StravaApiException(401, 'Sesi berakhir');
    }
    if (response.statusCode != 200) {
      throw StravaApiException(response.statusCode, _errorMessage(response, 'Gagal memutuskan Strava'));
    }
  }

  static Future<List<StravaActivity>> listActivities({int page = 1, int perPage = 30}) async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiHelper.baseUrl}/strava/activities?page=$page&per_page=$perPage'),
      headers: _headers(token),
    );
    if (response.statusCode == 401) {
      throw const StravaApiException(401, 'Sesi berakhir');
    }
    if (response.statusCode != 200) {
      throw StravaApiException(response.statusCode, _errorMessage(response, 'Gagal memuat aktivitas Strava'));
    }
    final items = jsonDecode(response.body)['data']?['items'];
    if (items is! List) return [];
    return items.whereType<Map>().map((item) => StravaActivity.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static bool matchesSportGroup(String code, String name, String sportGroup) {
    final haystack = '${code.toLowerCase()} ${name.toLowerCase()}';
    switch (sportGroup) {
      case 'run':
        return haystack.contains('run') || haystack.contains('lari') || haystack.contains('jog');
      case 'ride':
        return haystack.contains('ride') ||
            haystack.contains('sepeda') ||
            haystack.contains('cycling') ||
            haystack.contains('bike');
      case 'swim':
        return haystack.contains('swim') || haystack.contains('renang');
      case 'walk':
        return haystack.contains('walk') || haystack.contains('jalan') || haystack.contains('hike');
      case 'workout':
        return haystack.contains('workout') ||
            haystack.contains('gym') ||
            haystack.contains('yoga') ||
            haystack.contains('latihan');
      default:
        return false;
    }
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pltuapp/helpers/api_helper.dart';

/// Opsi "Dicatat Dengan" dari master data backend.
/// Nilai yang dikirim ke API adalah [code] (lowercase), bukan [label].
class RecordedViaOption {
  final int id;
  final String code;
  final String label;
  final String icon;
  final bool requiresSourceLink;
  final bool isActive;
  final bool isLocked;

  const RecordedViaOption({
    required this.id,
    required this.code,
    required this.label,
    required this.icon,
    required this.requiresSourceLink,
    required this.isActive,
    required this.isLocked,
  });

  factory RecordedViaOption.fromJson(Map<String, dynamic> json) {
    return RecordedViaOption(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? RecordedViaHelper.defaultIconKey,
      requiresSourceLink: json['requires_source_link'] == true,
      isActive: json['is_active'] != false,
      isLocked: json['is_locked'] == true,
    );
  }
}

class RecordedViaApiException implements Exception {
  final int statusCode;
  final String message;
  const RecordedViaApiException(this.statusCode, this.message);
}

class RecordedViaHelper {
  /// Kode opsi Strava; percabangan UI Strava harus memakai ini, bukan label.
  static const String stravaCode = 'strava';

  static const String defaultIconKey = 'pen';

  /// Oranye khas Strava, dipakai untuk ikon opsi Strava.
  static const Color stravaColor = Color(0xFFFC4C02);

  /// Katalog ikon backend (recorded-via.catalog.ts) → Material Icons.
  static IconData iconFor(String iconKey) {
    switch (iconKey) {
      case 'strava':
        return Icons.directions_run;
      case 'watch':
        return Icons.watch;
      case 'smartphone':
        return Icons.smartphone;
      case 'footprints':
        return Icons.directions_walk;
      case 'bike':
        return Icons.directions_bike;
      case 'heart-pulse':
        return Icons.monitor_heart;
      case 'timer':
        return Icons.timer;
      case 'pen':
        return Icons.edit_note;
      default:
        return Icons.edit_note;
    }
  }

  static bool isStrava(String? code) => code == stravaCode;

  static RecordedViaOption? findByCode(List<RecordedViaOption> options, String? code) {
    if (code == null) return null;
    for (final option in options) {
      if (option.code == code) return option;
    }
    return null;
  }

  static Future<List<RecordedViaOption>> fetchOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('${ApiHelper.baseUrl}/recorded-via-options'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      throw const RecordedViaApiException(401, 'Sesi berakhir');
    }

    if (response.statusCode != 200) {
      throw RecordedViaApiException(response.statusCode, 'Gagal memuat opsi pencatatan');
    }

    final body = jsonDecode(response.body);
    final items = body is Map ? body['data'] : null;
    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((item) => RecordedViaOption.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Tambahkan nilai dari record lama yang opsinya sudah dinonaktifkan/dihapus admin,
  /// supaya user yang mengedit histori tidak dipaksa mengubah catatannya.
  static List<RecordedViaOption> withCurrentValue(List<RecordedViaOption> options, String? currentCode) {
    if (currentCode == null || currentCode.isEmpty) return options;
    if (options.any((option) => option.code == currentCode)) return options;

    return [
      ...options,
      RecordedViaOption(
        id: 0,
        code: currentCode,
        label: '${currentCode[0].toUpperCase()}${currentCode.substring(1)} (nonaktif)',
        icon: defaultIconKey,
        requiresSourceLink: false,
        isActive: false,
        isLocked: false,
      ),
    ];
  }
}

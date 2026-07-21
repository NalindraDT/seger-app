import 'package:flutter/material.dart';

class ActivityShareData {
  final String activityType;
  final String distanceKm;
  final String durationMinutes;
  final String date;
  final String status;
  final String? proofPhotoUrl;
  final String? eventName;

  const ActivityShareData({
    required this.activityType,
    required this.distanceKm,
    required this.durationMinutes,
    required this.date,
    required this.status,
    this.proofPhotoUrl,
    this.eventName,
  });

  factory ActivityShareData.fromActivity(
    dynamic item, {
    String? eventName,
  }) {
    return ActivityShareData(
      activityType: item['type']?.toString() ?? 'Aktivitas',
      distanceKm: item['distance_km']?.toString() ?? '0',
      durationMinutes: item['duration_minutes']?.toString() ?? '0',
      date: item['date']?.toString() ?? '-',
      status: item['status']?.toString() ?? 'UNKNOWN',
      proofPhotoUrl: item['proof_photo']?.toString(),
      eventName: eventName,
    );
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get statusLabel => status.toUpperCase();

  String get shareCaption {
    final buffer = StringBuffer()
      ..writeln('🏃 Aktivitas SEGER: $activityType');

    if (eventName != null && eventName!.isNotEmpty) {
      buffer.writeln('🎯 Event: $eventName');
    }

    buffer
      ..writeln('📏 $distanceKm km • ⏱ $durationMinutes menit')
      ..writeln('📅 $date')
      ..writeln('✅ Status: $statusLabel')
      ..writeln()
      ..writeln('Active Today, Stronger Tomorrow')
      ..write('#SEGER #PLTU #PLN');

    return buffer.toString();
  }
}

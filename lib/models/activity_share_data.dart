import 'package:flutter/material.dart';
import 'package:pltuapp/helpers/activity_display_metrics.dart';

class ActivityShareStat {
  final String label;
  final String value;

  const ActivityShareStat({
    required this.label,
    required this.value,
  });
}

class ActivityShareData {
  final String activityType;
  final String date;
  final String status;
  final String? proofPhotoUrl;
  final String? eventName;
  final List<ActivityShareStat> stats;

  const ActivityShareData({
    required this.activityType,
    required this.date,
    required this.status,
    required this.stats,
    this.proofPhotoUrl,
    this.eventName,
  });

  factory ActivityShareData.fromActivity(
    dynamic item, {
    String? eventName,
  }) {
    final metrics = buildActivityDisplayMetrics(item);
    var stats = metrics
        .map((metric) => ActivityShareStat(label: metric.label.toUpperCase(), value: metric.value))
        .toList();

    if (stats.isEmpty) {
      stats = [
        ActivityShareStat(label: 'JARAK', value: '${item['distance_km'] ?? 0} km'),
        ActivityShareStat(label: 'DURASI', value: formatDurationValue(item)),
      ];
    }

    return ActivityShareData(
      activityType: item['type']?.toString() ?? 'Aktivitas',
      date: item['date']?.toString() ?? '-',
      status: item['status']?.toString() ?? 'UNKNOWN',
      proofPhotoUrl: item['proof_photo']?.toString(),
      eventName: eventName ?? item['event_name']?.toString(),
      stats: stats,
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

    for (final stat in stats) {
      buffer.writeln('• ${stat.label}: ${stat.value}');
    }

    buffer
      ..writeln('📅 $date')
      ..writeln('✅ Status: $statusLabel')
      ..writeln()
      ..writeln('Active Today, Stronger Tomorrow')
      ..write('#SEGER #PLTU #PLN');

    return buffer.toString();
  }
}

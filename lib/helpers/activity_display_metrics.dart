class ActivityDisplayMetric {
  final String key;
  final String label;
  final String value;
  final bool isComputed;

  const ActivityDisplayMetric({
    required this.key,
    required this.label,
    required this.value,
    this.isComputed = false,
  });
}

const _defaultInputFields = [
  {'key': 'distance_km', 'label': 'Jarak', 'type': 'number', 'unit': 'km', 'required': true},
  {'key': 'duration_minutes', 'label': 'Durasi', 'type': 'number', 'unit': 'menit', 'required': true},
  {'key': 'duration_seconds', 'label': 'Detik', 'type': 'number', 'unit': 'detik', 'required': false},
];

const _fieldLabels = {
  'distance_km': 'Jarak',
  'duration_minutes': 'Durasi',
  'duration_seconds': 'Detik',
  'calories': 'Kalori',
  'steps': 'Langkah',
  'elevation_m': 'Elevasi',
};

const _fieldUnits = {
  'distance_km': 'km',
  'duration_minutes': 'menit',
  'duration_seconds': 'detik',
  'calories': 'kcal',
  'steps': 'langkah',
  'elevation_m': 'meter',
};

List<Map<String, dynamic>> resolveActivityInputFields(dynamic item) {
  final raw = item['input_fields'];
  if (raw is List && raw.isNotEmpty) {
    return raw
        .where((field) => field is Map && field['type'] == 'number')
        .map((field) => Map<String, dynamic>.from(field as Map))
        .toList();
  }

  final inferred = <Map<String, dynamic>>[];
  final submissionData = _submissionMap(item);

  if (_num(item['distance_km']) > 0) {
    inferred.add({'key': 'distance_km', 'label': 'Jarak', 'type': 'number', 'unit': 'km', 'required': true});
  }
  if (_num(item['duration_minutes']) > 0 || _num(item['duration_seconds']) > 0) {
    inferred.add({'key': 'duration_minutes', 'label': 'Durasi', 'type': 'number', 'unit': 'menit', 'required': true});
  }
  if (_num(item['duration_seconds']) > 0) {
    inferred.add({'key': 'duration_seconds', 'label': 'Detik', 'type': 'number', 'unit': 'detik', 'required': false});
  }
  for (final key in ['calories', 'steps', 'elevation_m']) {
    if (_num(submissionData[key]) > 0) {
      inferred.add({
        'key': key,
        'label': _fieldLabels[key] ?? key,
        'type': 'number',
        'unit': _fieldUnits[key] ?? '',
        'required': false,
      });
    }
  }

  if (inferred.isNotEmpty) return inferred;
  return _defaultInputFields.map((field) => Map<String, dynamic>.from(field)).toList();
}

Map<String, dynamic> _submissionMap(dynamic item) {
  final raw = item['submission_data'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

num _num(dynamic value) {
  if (value == null) return 0;
  return num.tryParse(value.toString()) ?? 0;
}

String formatDurationValue(dynamic item) {
  final minutes = _num(item['duration_minutes']).toInt();
  final seconds = _num(item['duration_seconds']).toInt();
  if (seconds > 0) return '${minutes}m ${seconds}s';
  return '${minutes}m';
}

String _formatFieldValue(String key, dynamic item, Map<String, dynamic> submissionData) {
  switch (key) {
    case 'distance_km':
      final value = _num(item['distance_km']);
      return value % 1 == 0 ? '${value.toInt()} km' : '$value km';
    case 'duration_minutes':
      return formatDurationValue(item);
    case 'duration_seconds':
      return '${_num(item['duration_seconds']).toInt()} detik';
    case 'calories':
      return '${_num(submissionData['calories']).toInt()} kcal';
    case 'steps':
      return '${_num(submissionData['steps']).toInt()} langkah';
    case 'elevation_m':
      return '${_num(submissionData['elevation_m']).toInt()} meter';
    default:
      final raw = submissionData[key] ?? item[key];
      if (raw == null) return '-';
      return raw.toString();
  }
}

bool _shouldShowField(String key, dynamic item, Map<String, dynamic> submissionData, {required bool required}) {
  if (required) return true;
  switch (key) {
    case 'distance_km':
      return _num(item['distance_km']) > 0;
    case 'duration_minutes':
      return _num(item['duration_minutes']) > 0 || _num(item['duration_seconds']) > 0;
    case 'duration_seconds':
      return _num(item['duration_seconds']) > 0;
    case 'calories':
    case 'steps':
    case 'elevation_m':
      return _num(submissionData[key]) > 0;
    default:
      final raw = submissionData[key];
      return raw != null && raw.toString().isNotEmpty;
  }
}

List<ActivityDisplayMetric> buildActivityInputMetrics(dynamic item) {
  final submissionData = _submissionMap(item);
  final fields = resolveActivityInputFields(item);
  final metrics = <ActivityDisplayMetric>[];

  for (final field in fields) {
    final key = field['key']?.toString() ?? '';
    if (key.isEmpty) continue;

    final required = field['required'] == true;
    if (!_shouldShowField(key, item, submissionData, required: required)) continue;

    metrics.add(ActivityDisplayMetric(
      key: key,
      label: field['label']?.toString() ?? _fieldLabels[key] ?? key,
      value: _formatFieldValue(key, item, submissionData),
    ));
  }

  return metrics;
}

List<ActivityDisplayMetric> buildActivityComputedMetrics(dynamic item) {
  final computed = item['computed_metrics'];
  if (computed is! Map || computed.isEmpty) {
    final pace = item['pace_min_per_km'];
    if (pace != null && pace.toString().isNotEmpty && _num(pace) > 0) {
      return [
        ActivityDisplayMetric(
          key: 'pace',
          label: 'Pace',
          value: '$pace min/km',
          isComputed: true,
        ),
      ];
    }
    return [];
  }

  final outputFields = item['output_metrics'];
  final labelByKey = <String, String>{};
  if (outputFields is List) {
    for (final field in outputFields) {
      if (field is Map && field['key'] != null) {
        labelByKey[field['key'].toString()] = field['label']?.toString() ?? field['key'].toString();
      }
    }
  }

  const computedLabels = {
    'pace': 'Pace',
    'speed': 'Kecepatan',
    'pace_100m': 'Pace/100m',
    'calories_per_hour': 'Kalori/jam',
    'steps_per_km': 'Langkah/km',
  };

  const computedUnits = {
    'pace': 'min/km',
    'speed': 'km/jam',
    'pace_100m': 'min/100m',
    'calories_per_hour': 'kcal/jam',
    'steps_per_km': 'langkah/km',
  };

  final metrics = <ActivityDisplayMetric>[];
  computed.forEach((key, value) {
    if (value == null) return;
    final numeric = _num(value);
    if (numeric <= 0) return;
    final label = labelByKey[key.toString()] ?? computedLabels[key.toString()] ?? key.toString();
    final unit = computedUnits[key.toString()] ?? '';
    metrics.add(ActivityDisplayMetric(
      key: key.toString(),
      label: label,
      value: unit.isEmpty ? numeric.toString() : '$numeric $unit',
      isComputed: true,
    ));
  });

  return metrics;
}

List<ActivityDisplayMetric> buildActivityDisplayMetrics(dynamic item) {
  return [
    ...buildActivityInputMetrics(item),
    ...buildActivityComputedMetrics(item),
  ];
}

String buildActivityMetricsSummary(dynamic item, {int maxItems = 3}) {
  final metrics = buildActivityDisplayMetrics(item);
  if (metrics.isEmpty) return '-';
  return metrics.take(maxItems).map((metric) => metric.value).join(' · ');
}

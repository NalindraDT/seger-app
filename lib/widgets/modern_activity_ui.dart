import 'package:flutter/material.dart';
import 'package:pltuapp/helpers/activity_display_metrics.dart';
import 'package:pltuapp/helpers/activity_share_helper.dart';
import 'package:pltuapp/models/activity_share_data.dart';

class ModernActivityStatsHeader extends StatelessWidget {
  final Color accentColor;
  final String title;
  final String subtitle;
  final int totalItems;
  final bool isLoading;
  final IconData icon;

  const ModernActivityStatsHeader({
    super.key,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.totalItems,
    this.isLoading = false,
    this.icon = Icons.directions_run_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isLoading ? '—' : '$totalItems',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  height: 1,
                ),
              ),
              Text(
                'aktivitas',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ModernFilterOption {
  final String value;
  final String label;
  final IconData icon;

  const ModernFilterOption(this.value, this.label, this.icon);
}

class ModernSegmentFilterBar extends StatelessWidget {
  final Color accentColor;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final List<ModernFilterOption> options;
  final EdgeInsetsGeometry? padding;

  const ModernSegmentFilterBar({
    super.key,
    required this.accentColor,
    required this.selectedValue,
    required this.onChanged,
    required this.options,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((option) {
            final selected = selectedValue == option.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(option.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? accentColor : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 15,
                        color: selected ? Colors.white : accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ModernActivityFilterBar extends StatelessWidget {
  final Color accentColor;
  final String selectedStatus;
  final ValueChanged<String> onChanged;

  const ModernActivityFilterBar({
    super.key,
    required this.accentColor,
    required this.selectedStatus,
    required this.onChanged,
  });

  static const _filters = [
    ModernFilterOption('Semua', 'Semua', Icons.grid_view_rounded),
    ModernFilterOption('Pending', 'Pending', Icons.hourglass_top_rounded),
    ModernFilterOption('Approved', 'Approved', Icons.verified_rounded),
    ModernFilterOption('Rejected', 'Rejected', Icons.block_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ModernSegmentFilterBar(
      accentColor: accentColor,
      selectedValue: selectedStatus,
      onChanged: onChanged,
      options: _filters,
    );
  }
}

class ModernActivityCard extends StatelessWidget {
  final dynamic item;
  final Color accentColor;
  final VoidCallback onTapDetail;
  final VoidCallback onTapImage;
  final String? eventName;

  const ModernActivityCard({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onTapDetail,
    required this.onTapImage,
    this.eventName,
  });

  static Color statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  static String formatDuration(dynamic item) {
    final minutes = item['duration_minutes'] ?? 0;
    final seconds = item['duration_seconds'];
    if (seconds != null && int.tryParse(seconds.toString()) != null && int.parse(seconds.toString()) > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'UNKNOWN').toString();
    final color = statusColor(status);
    final type = item['type']?.toString() ?? 'Aktivitas';
    final photo = item['proof_photo']?.toString() ?? '';
    final date = item['date']?.toString() ?? '-';
    final metrics = buildActivityMetricsSummary(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDetail,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: onTapImage,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: photo.isNotEmpty
                                      ? Image.network(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _photoFallback(compact: true),
                                        )
                                      : _photoFallback(compact: true),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    type,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    metrics,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Material(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () {
                                      ActivityShareHelper.showShareSheet(
                                        context,
                                        ActivityShareData.fromActivity(item, eventName: eventName),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: Icon(Icons.ios_share_rounded, size: 16, color: accentColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoFallback({bool compact = false}) {
    return Container(
      color: accentColor.withOpacity(0.08),
      alignment: Alignment.center,
      child: Icon(Icons.directions_run_rounded, color: accentColor, size: compact ? 28 : 48),
    );
  }
}

Future<void> showModernActivityDetailSheet({
  required BuildContext context,
  required dynamic item,
  required Color accentColor,
  required VoidCallback onZoomPhoto,
}) {
  final status = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
  final statusColor = ModernActivityCard.statusColor(status);
  final reviewNote = item['review_note']?.toString();

  IconData statusIcon = Icons.info_outline_rounded;
  if (status == 'APPROVED') statusIcon = Icons.check_circle_rounded;
  if (status == 'REJECTED') statusIcon = Icons.cancel_rounded;

  final inputMetrics = buildActivityInputMetrics(item);
  final computedMetrics = buildActivityComputedMetrics(item);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            (reviewNote != null && reviewNote.isNotEmpty)
                                ? reviewNote
                                : (status == 'APPROVED'
                                    ? 'Aktivitas telah divalidasi.'
                                    : status == 'REJECTED'
                                        ? 'Aktivitas ditolak. Periksa bukti Anda.'
                                        : 'Sedang dalam proses review.'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailGrid(accentColor, item, inputMetrics, computedMetrics),
                const SizedBox(height: 20),
                if (item['source_link'] != null && item['source_link'].toString().isNotEmpty) ...[
                  const Text('Strava Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['source_link'].toString(),
                            style: TextStyle(color: accentColor, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text('Bukti Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onZoomPhoto,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        item['proof_photo']?.toString() ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: Text('Gambar tidak tersedia')),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _detailGrid(
  Color accentColor,
  dynamic item,
  List<ActivityDisplayMetric> inputMetrics,
  List<ActivityDisplayMetric> computedMetrics,
) {
  final tiles = <Widget>[
    _detailTile('Tipe', item['type']?.toString() ?? '-', accentColor, fullWidth: true),
    _detailTile('Tanggal', item['date']?.toString() ?? '-', accentColor, fullWidth: true),
  ];

  for (var i = 0; i < inputMetrics.length; i += 2) {
    tiles.add(const SizedBox(height: 10));
    tiles.add(
      Row(
        children: [
          Expanded(child: _detailTile(inputMetrics[i].label, inputMetrics[i].value, accentColor)),
          if (i + 1 < inputMetrics.length) ...[
            const SizedBox(width: 10),
            Expanded(child: _detailTile(inputMetrics[i + 1].label, inputMetrics[i + 1].value, accentColor)),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  if (computedMetrics.isNotEmpty) {
    tiles.add(const SizedBox(height: 14));
    tiles.add(Text('Metrik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700)));
    tiles.add(const SizedBox(height: 8));
    for (var i = 0; i < computedMetrics.length; i += 2) {
      tiles.add(const SizedBox(height: 10));
      tiles.add(
        Row(
          children: [
            Expanded(child: _detailTile(computedMetrics[i].label, computedMetrics[i].value, accentColor)),
            if (i + 1 < computedMetrics.length) ...[
              const SizedBox(width: 10),
              Expanded(child: _detailTile(computedMetrics[i + 1].label, computedMetrics[i + 1].value, accentColor)),
            ] else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
    }
  }

  return Column(children: tiles);
}

Widget _detailTile(String label, String value, Color color, {bool fullWidth = false}) {
  return Container(
    width: fullWidth ? double.infinity : null,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    ),
  );
}

Widget modernActivityEmptyState({required String message, required Color accentColor}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.route_rounded, size: 36, color: accentColor),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
        ),
      ],
    ),
  );
}

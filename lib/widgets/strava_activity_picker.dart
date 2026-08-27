import 'package:flutter/material.dart';

import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/helpers/strava_helper.dart';
import 'package:pltuapp/widgets/strava_connect_card.dart';

Future<StravaActivity?> showStravaActivityPicker({
  required BuildContext context,
  required Color accentColor,
}) {
  return showModalBottomSheet<StravaActivity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StravaActivityPickerSheet(accentColor: accentColor),
  );
}

class _StravaActivityPickerSheet extends StatefulWidget {
  final Color accentColor;

  const _StravaActivityPickerSheet({required this.accentColor});

  @override
  State<_StravaActivityPickerSheet> createState() => _StravaActivityPickerSheetState();
}

class _StravaActivityPickerSheetState extends State<_StravaActivityPickerSheet> {
  final List<StravaActivity> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _items.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final page = reset ? 1 : _page + 1;
      final items = await StravaHelper.listActivities(page: page);
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _page = page;
        _hasMore = items.length >= 30;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on StravaApiException catch (error) {
      if (error.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
      }
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat aktivitas Strava';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Pilih Aktivitas Strava', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: widget.accentColor));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _load(reset: true), child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Belum ada aktivitas di Strava'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return TextButton(
            onPressed: _isLoadingMore ? null : () => _load(),
            child: _isLoadingMore
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Muat lebih banyak'),
          );
        }

        final item = _items[index];
        final disabled = item.alreadySubmitted;
        return Material(
          color: disabled ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: disabled ? null : () => Navigator.pop(context, item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: stravaOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route, color: stravaOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: disabled ? Colors.grey : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.sportType} · ${item.activityDate} · ${item.distanceLabel} · ${item.durationLabel}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (disabled)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Sudah disubmit', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StravaActivitySelectField extends StatelessWidget {
  final bool connected;
  final bool isBusy;
  final StravaActivity? selected;
  final VoidCallback onConnect;
  final VoidCallback onPick;

  const StravaActivitySelectField({
    Key? key,
    required this.connected,
    required this.isBusy,
    required this.selected,
    required this.onConnect,
    required this.onPick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hubungkan Strava', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : onConnect,
              icon: const Icon(Icons.link, color: Colors.white),
              label: const Text('Hubungkan dengan Strava', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: stravaOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aktivitas Strava', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: isBusy ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.fitness_center_outlined, size: 20, color: stravaOrange),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              selected == null
                  ? 'Pilih aktivitas dari Strava'
                  : '${selected!.name} · ${selected!.distanceLabel}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected == null ? Colors.grey.shade500 : const Color(0xFF2D2D2D),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

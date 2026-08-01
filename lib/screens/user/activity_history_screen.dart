import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/widgets/modern_activity_ui.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _activities = [];

  // Variabel untuk Pagination & Total Items
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  // Variabel untuk Filter
  String _selectedStatus = 'Semua';
  String _selectedTimeFilter = 'Semua';
  String? _selectedEventId;
  List<dynamic> _eventOptions = [];
  String? _customDateFrom;
  String? _customDateTo;

  final Color primaryPurple = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchHistory();
    _markActivityNotificationsRead();
  }

  Future<void> _markActivityNotificationsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      await http.post(
        Uri.parse('${ApiHelper.baseUrl}/users/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'type': 'activity_reviewed'}),
      );
    } catch (_) {}
  }

  Future<void> _fetchEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/events?page=1&limit=100'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final payload = data['data'];
          final items = payload is List ? payload : (payload['items'] ?? []);
          setState(() => _eventOptions = List<dynamic>.from(items));
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String url = '${ApiHelper.baseUrl}/activities/history?page=$_currentPage&limit=10&scope=all';

      if (_selectedStatus != 'Semua') {
        url += '&status=${_selectedStatus.toUpperCase()}';
      }

      if (_selectedEventId != null && _selectedEventId!.isNotEmpty) {
        url += '&event_id=$_selectedEventId';
      }

      final dateRange = _resolveDateRange();
      if (dateRange['from'] != null) url += '&date_from=${dateRange['from']}';
      if (dateRange['to'] != null) url += '&date_to=${dateRange['to']}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // --- 2. PASANG PENJAGA GERBANG 401 DISINI ---
      if (response.statusCode == 401) {
        // Jika token mati, fungsi ini akan langsung menampilkan modal
        // dan mengarahkan user ke halaman login secara global.
        ApiHelper.showSessionExpiredModal();
        setState(() => _isLoading = false);
        return; // Hentikan fungsi agar tidak memproses data yang error
      }
      // --------------------------------------------

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            List<dynamic> merged;
            if (data['data']['items'] != null) {
              merged = List<dynamic>.from(data['data']['items'] ?? []);
            } else {
              final annual = data['data']['activity_items'] ?? [];
              final event = data['data']['event_items'] ?? [];
              merged = [...List<dynamic>.from(annual), ...List<dynamic>.from(event)];
            }
            merged.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
            _activities = merged;
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];
            _totalItems = data['data']['pagination']['totalItems'];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal memuat data riwayat.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages && newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      _fetchHistory();
    }
  }

  Map<String, String?> _resolveDateRange() {
    if (_selectedTimeFilter == 'Custom') {
      return {'from': _customDateFrom, 'to': _customDateTo};
    }
    final now = DateTime.now();
    if (_selectedTimeFilter == '7 Hari') {
      final from = now.subtract(const Duration(days: 7));
      return {'from': _formatDateParam(from), 'to': _formatDateParam(now)};
    }
    if (_selectedTimeFilter == '30 Hari') {
      final from = now.subtract(const Duration(days: 30));
      return {'from': _formatDateParam(from), 'to': _formatDateParam(now)};
    }
    if (_selectedTimeFilter == '90 Hari') {
      final from = now.subtract(const Duration(days: 90));
      return {'from': _formatDateParam(from), 'to': _formatDateParam(now)};
    }
    return {'from': null, 'to': null};
  }

  String _formatDateParam(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickCustomDateRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (from == null) return;
    if (!mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
    );
    if (to == null) return;
    setState(() {
      _selectedTimeFilter = 'Custom';
      _customDateFrom = _formatDateParam(from);
      _customDateTo = _formatDateParam(to);
      _currentPage = 1;
    });
    _fetchHistory();
  }

  void _changeTimeFilter(String filter) {
    if (_selectedTimeFilter == filter) return;
    setState(() {
      _selectedTimeFilter = filter;
      _currentPage = 1;
    });
    _fetchHistory();
  }

  void _changeFilter(String newStatus) {
    if (_selectedStatus != newStatus) {
      setState(() {
        _selectedStatus = newStatus;
        _currentPage = 1;
      });
      _fetchHistory();
    }
  }

  void _changeEventFilter(String? eventId) {
    setState(() {
      _selectedEventId = (eventId == null || eventId.isEmpty) ? null : eventId;
      _currentPage = 1;
    });
    _fetchHistory();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ===========================================================================
  // FUNGSI UNTUK FULLSCREEN ZOOM IMAGE
  // ===========================================================================
  void _showZoomableImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  height: double.infinity,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Gagal memuat gambar', style: TextStyle(color: Colors.white)),
                    );
                  },
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // FUNGSI MEMUNCULKAN MODAL DETAIL
  // ===========================================================================
  void _showDetailModal(dynamic item) {
    final photo = item['proof_photo']?.toString() ?? '';
    showModernActivityDetailSheet(
      context: context,
      item: item,
      accentColor: primaryPurple,
      onZoomPhoto: () {
        if (photo.isNotEmpty) {
          Navigator.pop(context);
          _showZoomableImage(photo);
        }
      },
    );
  }

  Future<void> _cancelSubmission(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pengajuan'),
        content: const Text('Yakin ingin membatalkan pengajuan ini? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final id = item['id']?.toString();
      final response = await http.delete(
        Uri.parse('${ApiHelper.baseUrl}/activities/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _currentPage = 1;
        await _fetchHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengajuan berhasil dibatalkan.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membatalkan pengajuan.')),
        );
      }
    }
  }

  Future<void> _editSubmission(dynamic item) async {
    final id = item['id']?.toString();
    if (id == null) return;
    Navigator.pushNamed(context, '/edit-activity', arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
        onRefresh: () async {
          _currentPage = 1;
          await _fetchHistory();
        },
        color: primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat Aktivitas',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 6),
              Text(
                'Pantau progres, status verifikasi, dan bagikan pencapaianmu.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              ModernActivityStatsHeader(
                accentColor: primaryPurple,
                title: 'Total Aktivitas',
                subtitle: _selectedStatus == 'Semua' ? 'Semua Status' : _selectedStatus,
                totalItems: _totalItems,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
              ModernActivityFilterBar(
                accentColor: primaryPurple,
                selectedStatus: _selectedStatus,
                onChanged: _changeFilter,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _selectedEventId,
                    hint: const Text('Filter By Event: Semua Event'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Semua Event'),
                      ),
                      ..._eventOptions.map((event) {
                        final id = event['id']?.toString() ?? '';
                        final name = event['name']?.toString() ?? 'Event';
                        return DropdownMenuItem<String?>(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: _changeEventFilter,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ModernSegmentFilterBar(
                accentColor: primaryPurple,
                selectedValue: _selectedTimeFilter,
                onChanged: (filter) {
                  if (filter == 'Custom') {
                    _pickCustomDateRange();
                  } else {
                    _changeTimeFilter(filter);
                  }
                },
                options: const [
                  ModernFilterOption('Semua', 'Semua', Icons.grid_view_rounded),
                  ModernFilterOption('7 Hari', '7 Hari', Icons.today_rounded),
                  ModernFilterOption('30 Hari', '30 Hari', Icons.date_range_rounded),
                  ModernFilterOption('90 Hari', '90 Hari', Icons.calendar_month_rounded),
                  ModernFilterOption('Custom', 'Custom', Icons.edit_calendar_rounded),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _activities.isEmpty
                      ? modernActivityEmptyState(
                          message: 'Belum ada aktivitas untuk filter ini.\nCatat aktivitas pertamamu dari Beranda.',
                          accentColor: primaryPurple,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _activities.length,
                          itemBuilder: (context, index) {
                            final item = _activities[index];
                            final photo = item['proof_photo']?.toString() ?? '';
                            return ModernActivityCard(
                              item: item,
                              accentColor: primaryPurple,
                              eventName: item['event_name']?.toString(),
                              onTapDetail: () => _showDetailModal(item),
                              onTapImage: () {
                                if (photo.isNotEmpty) {
                                  _showZoomableImage(photo);
                                } else {
                                  _showDetailModal(item);
                                }
                              },
                              onCancel: () => _cancelSubmission(item),
                              onEdit: () => _editSubmission(item),
                            );
                          },
                        ),
              const SizedBox(height: 30),
              if (!_isLoading && _totalPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildPaginationWidgets(),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // --- legacy helpers removed; pagination below ---
  List<Widget> _buildPaginationWidgets() {
    List<Widget> widgets = [];

    widgets.add(
      IconButton(
        iconSize: 28,
        icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black : Colors.grey),
        onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
      ),
    );

    int startPage = _currentPage > 2 ? _currentPage - 1 : 1;
    int endPage = startPage + 2 > _totalPages ? _totalPages : startPage + 2;
    if (endPage - startPage < 2 && _totalPages >= 3) {
      startPage = endPage - 2;
    }

    if (startPage > 1) {
      widgets.add(_buildClickablePageNumber(1));
      if (startPage > 2) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
    }

    for (int i = startPage; i <= endPage; i++) {
      widgets.add(_buildClickablePageNumber(i));
    }

    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      widgets.add(_buildClickablePageNumber(_totalPages));
    }

    widgets.add(
      IconButton(
        iconSize: 28,
        icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey),
        onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
      ),
    );

    return widgets;
  }

  Widget _buildClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: _buildPaginationNumber(page.toString(), isActive: page == _currentPage),
    );
  }

  Widget _buildPaginationNumber(String number, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? primaryPurple : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
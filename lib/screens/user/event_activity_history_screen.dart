import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/widgets/modern_activity_ui.dart';

class EventActivityHistoryScreen extends StatefulWidget {
  final String eventId;
  final Color themeColor;
  final String eventName;
  final bool isFromSubmission;

  const EventActivityHistoryScreen({
    super.key,
    required this.eventId,
    required this.themeColor,
    required this.eventName,
    this.isFromSubmission = false,
  });

  @override
  State<EventActivityHistoryScreen> createState() => _EventActivityHistoryScreenState();
}

class _EventActivityHistoryScreenState extends State<EventActivityHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _activities = [];

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String _selectedStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    _fetchHistory();

    if (widget.isFromSubmission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Aktivitas event berhasil dicatat!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          ),
        );
      });
    }
  }

  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false;
    }
    return true;
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String url = '${ApiHelper.baseUrl}/activities/history?page=$_currentPage&limit=10&event=${widget.eventId}';

      if (_selectedStatus != 'Semua') {
        url += '&status=${_selectedStatus.toUpperCase()}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!_checkAuth(response.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _activities = data['data']['items'] ?? data['data']['activity_items'] ?? [];
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];
            _totalItems = data['data']['pagination']['totalItems'];
            _isLoading = false;
          });
          return;
        }
      }

      setState(() => _isLoading = false);
      _showError('Gagal memuat data riwayat event.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages && newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _fetchHistory();
    }
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

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
                child: Image.network(imageUrl, fit: BoxFit.contain, height: double.infinity, width: double.infinity),
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

  void _showDetailModal(dynamic item) {
    final photo = item['proof_photo']?.toString() ?? '';
    showModernActivityDetailSheet(
      context: context,
      item: item,
      accentColor: widget.themeColor,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: Text(
          widget.eventName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _currentPage = 1;
            await _fetchHistory();
          },
          color: widget.themeColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat Aktivitas Event',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aktivitas yang kamu catat untuk event ini.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 20),
                ModernActivityStatsHeader(
                  accentColor: widget.themeColor,
                  title: widget.eventName,
                  subtitle: _selectedStatus == 'Semua' ? 'Semua Status' : _selectedStatus,
                  totalItems: _totalItems,
                  isLoading: _isLoading,
                  icon: Icons.emoji_events_rounded,
                ),
                const SizedBox(height: 20),
                ModernActivityFilterBar(
                  accentColor: widget.themeColor,
                  selectedStatus: _selectedStatus,
                  onChanged: _changeFilter,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: CircularProgressIndicator(color: widget.themeColor),
                        ),
                      )
                    : _activities.isEmpty
                        ? modernActivityEmptyState(
                            message: 'Belum ada aktivitas di event ini.\nCatat aktivitasmu saat event berlangsung.',
                            accentColor: widget.themeColor,
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
                                accentColor: widget.themeColor,
                                eventName: widget.eventName,
                                onTapDetail: () => _showDetailModal(item),
                                onTapImage: () {
                                  if (photo.isNotEmpty) {
                                    _showZoomableImage(photo);
                                  } else {
                                    _showDetailModal(item);
                                  }
                                },
                                onCancel: () => _cancelSubmission(item),
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

  List<Widget> _buildPaginationWidgets() {
    List<Widget> widgets = [];
    widgets.add(IconButton(
      iconSize: 28,
      icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black : Colors.grey),
      onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
    ));
    int startPage = _currentPage > 2 ? _currentPage - 1 : 1;
    int endPage = startPage + 2 > _totalPages ? _totalPages : startPage + 2;
    if (endPage - startPage < 2 && _totalPages >= 3) startPage = endPage - 2;
    if (startPage > 1) {
      widgets.add(_buildClickablePageNumber(1));
      if (startPage > 2) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
    }
    for (int i = startPage; i <= endPage; i++) widgets.add(_buildClickablePageNumber(i));
    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      widgets.add(_buildClickablePageNumber(_totalPages));
    }
    widgets.add(IconButton(
      iconSize: 28,
      icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey),
      onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
    ));
    return widgets;
  }

  Widget _buildClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: page == _currentPage ? widget.themeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: page == _currentPage ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            page.toString(),
            style: TextStyle(
              color: page == _currentPage ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

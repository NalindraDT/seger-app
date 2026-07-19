import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class EventActivityHistoryScreen extends StatefulWidget {
  final String eventId;
  final Color themeColor;
  final String eventName;
  final bool isFromSubmission;

  const EventActivityHistoryScreen({
    Key? key,
    required this.eventId,
    required this.themeColor,
    required this.eventName,
    this.isFromSubmission = false,
  }) : super(key: key);

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

  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchHistory();

    // --- TAMBAHAN KODE ---
    // Jika halaman ini dibuka sesaat setelah submit berhasil, munculkan notif
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

  // --- HELPER PENGECEKAN SESI ---
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false; // Token mati
    }
    return true; // Token aman
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // --- URL API dengan Event ID ---
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

      // --- CEK SESI 401 ---
      if (!_checkAuth(response.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _activities = data['data']['items'] ?? [];
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];
            _totalItems = data['data']['pagination']['totalItems'];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal memuat data riwayat event.');
      }
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.orange;
    }
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
                panEnabled: true, minScale: 0.5, maxScale: 4.0,
                child: Image.network(imageUrl, fit: BoxFit.contain, height: double.infinity, width: double.infinity),
              ),
              Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(context))),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Riwayat Event', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                // --- KOTAK TOTAL AKTIVITAS EVENT ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.themeColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.eventName, style: TextStyle(color: Colors.grey.shade700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              _selectedStatus == 'Semua' ? 'Semua Aktivitas' : _selectedStatus,
                              style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _isLoading ? '-' : '$_totalItems',
                        style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w900, fontSize: 32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- FILTER CHIPS ---
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- LIST AKTIVITAS ---
                _isLoading
                    ? Center(child: Padding(padding: const EdgeInsets.only(top: 50.0), child: CircularProgressIndicator(color: widget.themeColor)))
                    : _activities.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.only(top: 50.0), child: Text('Belum ada aktivitas di event ini.', style: TextStyle(color: Colors.grey))))
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) => _buildActivityCard(_activities[index]),
                ),

                const SizedBox(height: 30),

                if (!_isLoading && _totalPages > 1)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _buildPaginationWidgets()),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET CARD AKTIVITAS ---
  Widget _buildActivityCard(dynamic item) {
    Color statusColor = _getStatusColor(item['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (item['proof_photo'] != null) _showZoomableImage(item['proof_photo']);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60, height: 60, color: Colors.grey.shade100,
                child: Image.network(item['proof_photo'] ?? '', fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.directions_run, color: widget.themeColor, size: 30)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['type'] ?? 'Aktivitas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 4),
                Text('${item['distance_km']} km • Durasi ${item['duration_minutes']}m', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(item['date'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text((item['status'] ?? 'UNKNOWN').toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }

  // --- WIDGET FILTER CHIP INTERAKTIF ---
  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedStatus == label;
    return GestureDetector(
      onTap: () => _changeFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.themeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? widget.themeColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        ),
      ),
    );
  }

  // --- WIDGET PAGINATION ---
  List<Widget> _buildPaginationWidgets() {
    List<Widget> widgets = [];
    widgets.add(IconButton(iconSize: 28, icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black : Colors.grey), onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null));
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
    widgets.add(IconButton(iconSize: 28, icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey), onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null));
    return widgets;
  }

  Widget _buildClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4), width: 40, height: 40,
        decoration: BoxDecoration(color: page == _currentPage ? widget.themeColor : Colors.white, borderRadius: BorderRadius.circular(10), border: page == _currentPage ? null : Border.all(color: Colors.grey.shade300)),
        child: Center(child: Text(page.toString(), style: TextStyle(color: page == _currentPage ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16))),
      ),
    );
  }
}
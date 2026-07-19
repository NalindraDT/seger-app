import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';

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

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String url = '${ApiHelper.baseUrl}/activities/history?page=$_currentPage&limit=10';

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
            _activities = data['data']['activity_items'] ?? [];
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
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
    Color statusColor = _getStatusColor(item['status'] ?? '');
    String statusText = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();

    // --- MENGAMBIL REVIEW NOTE DARI API ---
    String? reviewNote = item['review_note'];

    IconData statusIcon = Icons.info_outline;
    if (statusText == 'APPROVED') statusIcon = Icons.check_circle;
    if (statusText == 'REJECTED') statusIcon = Icons.cancel;

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFF8F9FA),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- BANNER STATUS DENGAN REVIEW NOTE ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'STATUS: $statusText',
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (reviewNote != null && reviewNote.isNotEmpty)
                                      ? 'Catatan: $reviewNote'
                                      : (statusText == 'APPROVED'
                                      ? 'Aktivitas ini telah divalidasi dan disetujui oleh sistem.'
                                      : statusText == 'REJECTED'
                                      ? 'Aktivitas ini ditolak. Pastikan bukti valid.'
                                      : 'Aktivitas ini sedang dalam proses review.'),
                                  style: TextStyle(color: statusColor, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildModalInfoCard('ACTIVITY TYPE', item['type'] ?? '-', icon: Icons.directions_run),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildModalInfoCard('DISTANCE', '${item['distance_km'] ?? 0} KM', isLargeValue: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildModalInfoCard('DURATION', '${item['duration_minutes'] ?? 0} Min', isLargeValue: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildModalInfoCard('DATE', item['date'] ?? '-'),
                    const SizedBox(height: 24),

                    const Text('Verification Evidence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                    const SizedBox(height: 12),

                    if (item['source_link'] != null && item['source_link'].toString().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STRAVA LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16, color: primaryPurple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['source_link'],
                                      style: TextStyle(color: primaryPurple, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.open_in_new, size: 16, color: primaryPurple),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BUKTI FOTO (Ketuk untuk memperbesar)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              if (item['proof_photo'] != null && item['proof_photo'].toString().isNotEmpty) {
                                _showZoomableImage(item['proof_photo']);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['proof_photo'] ?? '',
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey.shade100,
                                    child: const Center(child: Text('Gambar tidak tersedia', style: TextStyle(color: Colors.grey))),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildModalInfoCard(String title, String value, {IconData? icon, bool isLargeValue = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: primaryPurple),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isLargeValue ? 18 : 14,
                    fontWeight: FontWeight.bold,
                    color: isLargeValue ? primaryPurple : const Color(0xFF2D2D2D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktifitas',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                  ),
                  Stack(
                    // children: [
                    //   Container(
                    //     padding: const EdgeInsets.all(8),
                    //     decoration: BoxDecoration(
                    //       shape: BoxShape.circle,
                    //       border: Border.all(color: Colors.grey.shade300),
                    //     ),
                    //     child: const Icon(Icons.notifications_none, color: Colors.black87),
                    //   ),
                    //   Positioned(
                    //     right: 6,
                    //     top: 6,
                    //     child: Container(
                    //       padding: const EdgeInsets.all(4),
                    //       decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    //     ),
                    //   )
                    // ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- KOTAK TOTAL AKTIVITAS ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryPurple.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Aktivitas (Tahunan)',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedStatus == 'Semua' ? 'Keseluruhan' : _selectedStatus,
                          style: TextStyle(
                              color: primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _isLoading ? '-' : '$_totalItems',
                      style: TextStyle(
                        color: primaryPurple,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
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
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : _activities.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text('Tidak ada aktivitas ditemukan.', style: TextStyle(color: Colors.grey)),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final item = _activities[index];
                  return _buildActivityCard(item);
                },
              ),

              const SizedBox(height: 30),

              // --- PAGINATION ---
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
    );
  }

  // --- WIDGET CARD AKTIVITAS ---
  Widget _buildActivityCard(dynamic item) {
    Color statusColor = _getStatusColor(item['status']);

    return GestureDetector(
      onTap: () => _showDetailModal(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade100,
                child: Image.network(
                  item['proof_photo'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.directions_run, color: primaryPurple, size: 30);
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['type'] ?? 'Aktivitas',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['distance_km']} km • Duration ${item['duration_minutes']}m',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        item['date'] ?? '-',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (item['status'] ?? 'UNKNOWN').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
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
          color: isSelected ? primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryPurple : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- WIDGET PAGINATION ---
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
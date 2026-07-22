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

  final Color primaryPurple = const Color(0xFF5D44F8);

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
                title: 'Total Aktivitas (Tahunan)',
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
                              onTapDetail: () => _showDetailModal(item),
                              onTapImage: () {
                                if (photo.isNotEmpty) {
                                  _showZoomableImage(photo);
                                } else {
                                  _showDetailModal(item);
                                }
                              },
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
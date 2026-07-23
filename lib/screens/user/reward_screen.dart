import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({Key? key}) : super(key: key);

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Variabel untuk Daftar Hadiah
  bool _isLoadingRewards = true;
  List<dynamic> _rewards = [];
  int _currentPoints = 0;

  // Variabel untuk Riwayat Penukaran
  bool _isLoadingHistory = true;
  List<dynamic> _historyItems = [];
  int _historyCurrentPage = 1;
  int _historyTotalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRewards();
    _fetchHistory();
  }

  // ===========================================================================
  // HELPER UNTUK PENGECEKAN SESI
  // ===========================================================================
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false; // Token mati
    }
    return true; // Token aman
  }

  // ===========================================================================
  // API CALLS
  // ===========================================================================

  Future<void> _fetchRewards() async {
    setState(() => _isLoadingRewards = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      _currentPoints = prefs.getInt('points') ?? 0;

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/rewards'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // --- CEK SESI 401 ---
      if (!_checkAuth(response.statusCode)) {
        setState(() => _isLoadingRewards = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _rewards = data['data'];
            _isLoadingRewards = false;
          });
        }
      } else {
        setState(() => _isLoadingRewards = false);
        _showError('Gagal memuat daftar hadiah.');
      }
    } catch (e) {
      setState(() => _isLoadingRewards = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/rewards/redemptions?page=$_historyCurrentPage&limit=10'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // --- CEK SESI 401 ---
      if (!_checkAuth(response.statusCode)) {
        setState(() => _isLoadingHistory = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _historyItems = data['data']['items'];
            _historyCurrentPage = data['data']['pagination']['page'];
            _historyTotalPages = data['data']['pagination']['totalPages'];
            _isLoadingHistory = false;
          });
        }
      } else {
        setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _redeemReward(int rewardId, String rewardName, int cost, String imageUrl) async {
    // Tutup modal konfirmasi
    Navigator.pop(context);

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiHelper.baseUrl}/rewards/redeem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "reward_id": rewardId,
          "quantity": 1
        }),
      );

      // Tutup loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // --- CEK SESI 401 SETELAH LOADING DITUTUP ---
      if (!_checkAuth(response.statusCode)) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          int remainingBalance = data['data']['remaining_balance'];
          int pointsSpent = data['data']['points_spent'];

          // Update sisa poin di SharedPreferences agar Dashboard juga ter-update
          await prefs.setInt('points', remainingBalance);

          setState(() {
            _currentPoints = remainingBalance;
          });

          // Refresh data
          _fetchRewards();
          _fetchHistory();

          // Tampilkan Modal Sukses
          _showSuccessModal(rewardName, pointsSpent, remainingBalance, imageUrl);
        }
      } else {
        _showError('Gagal menukar poin. Silakan coba lagi.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup loading dialog
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  void _changeHistoryPage(int newPage) {
    if (newPage >= 1 && newPage <= _historyTotalPages && newPage != _historyCurrentPage) {
      setState(() {
        _historyCurrentPage = newPage;
      });
      _fetchHistory();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _receiveRedemption(String redemptionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiHelper.baseUrl}/rewards/redemptions/$redemptionId/receive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (!_checkAuth(response.statusCode)) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hadiah berhasil diterima!'), backgroundColor: Colors.green),
          );
        }
      } else {
        _showError('Gagal menerima hadiah.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Terjadi kesalahan jaringan.');
      }
    }
  }

  String _formatDateTime(String? dateRaw) {
    if (dateRaw == null || dateRaw.isEmpty) return '-';
    try {
      DateTime parsed = DateTime.parse(dateRaw);
      return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateRaw.split('T')[0];
    }
  }

  void _showReceiveConfirmationModal(dynamic item) {
    final redemptionId = item['id']?.toString();
    final rewardName = item['reward_name'] ?? 'Hadiah';
    if (redemptionId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Penerimaan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah Anda yakin sudah menerima hadiah "$rewardName"?',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _receiveRedemption(redemptionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Terima', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHistoryDetailModal(dynamic item) {
    final status = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
    final adminNote = item['admin_note']?.toString();
    final processedAt = item['processed_at']?.toString();
    final requestedAt = item['requested_at']?.toString();
    final receivedAt = item['received_at']?.toString();

    Color statusColor = Colors.orange;
    if (status == 'PROCESSED' || status == 'RECEIVED') {
      statusColor = Colors.green;
    } else if (status == 'REJECTED') {
      statusColor = Colors.red;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['reward_name'] ?? 'Detail Penukaran',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 20),
              _buildRedemptionTimeline(
                status: status,
                requestedAt: requestedAt,
                processedAt: processedAt,
                receivedAt: receivedAt,
                adminNote: adminNote,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedemptionTimeline({
    required String status,
    String? requestedAt,
    String? processedAt,
    String? receivedAt,
    String? adminNote,
  }) {
    final isRejected = status == 'REJECTED';
    final isReceived = status == 'RECEIVED';
    final isProcessed = status == 'PROCESSED' || isReceived;
    final isPending = status == 'PENDING';

    Widget step({
      required String title,
      required String subtitle,
      required bool done,
      required bool active,
      required bool failed,
      required IconData icon,
    }) {
      final color = failed
          ? Colors.red
          : done
              ? Colors.green
              : active
                  ? primaryPurple
                  : Colors.grey.shade400;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  failed ? Icons.close : (done ? Icons.check : icon),
                  size: 16,
                  color: color,
                ),
              ),
              Container(width: 2, height: 36, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: active || done || failed ? Colors.black87 : Colors.grey)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        step(
          title: 'Permintaan Diajukan',
          subtitle: _formatDateTime(requestedAt),
          done: true,
          active: isPending,
          failed: false,
          icon: Icons.send,
        ),
        step(
          title: isRejected ? 'Ditolak Admin' : 'Diproses Admin',
          subtitle: isRejected
              ? '${_formatDateTime(processedAt)}${adminNote != null && adminNote.isNotEmpty ? '\nCatatan: $adminNote' : ''}'
              : (isProcessed ? _formatDateTime(processedAt) : 'Menunggu verifikasi admin'),
          done: isProcessed || isRejected,
          active: isPending,
          failed: isRejected,
          icon: Icons.admin_panel_settings,
        ),
        if (!isRejected)
          step(
            title: 'Hadiah Diterima',
            subtitle: isReceived ? _formatDateTime(receivedAt) : (isProcessed ? 'Konfirmasi penerimaan hadiah' : 'Menunggu tahap sebelumnya'),
            done: isReceived,
            active: isProcessed && !isReceived,
            failed: false,
            icon: Icons.card_giftcard,
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ===========================================================================
  // MODALS (KONFIRMASI & SUKSES)
  // ===========================================================================

  void _showConfirmationModal(dynamic item) {
    int cost = item['points_cost'] ?? 0;
    int sisa = _currentPoints - cost;

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Kotak Putih Utama
                Container(
                  margin: const EdgeInsets.only(top: 40),
                  padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Konfirmasi Penukaran', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF1E1E9A), fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Apakah Anda yakin ingin menukar poin ini?', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontSize: 13 )),
                      const SizedBox(height: 20),

                      // Kotak Info Item
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['image'] ?? '',
                                width: 50, height: 50, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Hadiah', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('$cost Poin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Rincian Saldo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Poin Saat Ini', style: TextStyle(color: Colors.black87, fontSize: 13)),
                          Text('$_currentPoints Poin', style: const TextStyle(color: Color(0xFF1E1E9A), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Biaya Penukaran', style: TextStyle(color: Colors.black87, fontSize: 13)),
                          Text('- $cost Poin', style: const TextStyle(color: Color(0xFFE9005C), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.grey, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Poin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('$sisa Poin', style: const TextStyle(color: Color(0xFF1E1E9A), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tombol Aksi
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _redeemReward(item['id'], item['name'], cost, item['image']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryPink,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Redeem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                // Icon Melayang
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: primaryPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))]
                  ),
                  child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 40, weight: 800),
                ),
              ],
            ),
          );
        }
    );
  }

  void _showSuccessModal(String rewardName, int pointsSpent, int remainingBalance, String imageUrl) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 40),
                  padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Penukaran Berhasil!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF1E1E9A), fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Selamat! Kamu berhasil menukarkan\n$pointsSpent Poin untuk $rewardName.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, height: 1.4)),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 50, height: 50, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rewardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Text('Voucher Fisik / Digital', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Poin Digunakan', style: TextStyle(color: Colors.black87, fontSize: 13)),
                          Text('- $pointsSpent Poin', style: const TextStyle(color: Color(0xFFE9005C), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Saldo Poin', style: TextStyle(color: Colors.black87, fontSize: 13)),
                          Text('$remainingBalance Poin', style: const TextStyle(color: Color(0xFF1E1E9A), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Tutup modal
                            Navigator.pop(context); // Kembali ke Dashboard
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context); // Tutup modal
                            _tabController.animateTo(1); // Pindah ke Tab Riwayat Penukaran
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Lihat Riwayat', style: TextStyle(color: Color(0xFF1E1E9A), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: primaryPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))]
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 40, weight: 800),
                ),
              ],
            ),
          );
        }
    );
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Redeem Poin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // BANNER POIN
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                  color: primaryPurple,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Poin Kamu', style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$_currentPoints', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1)),
                          const SizedBox(width: 8),
                          const Text('Poin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                  Image.asset(
                    'assets/images/koin.png',
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.monetization_on, color: Colors.amber, size: 70),
                  ),
                ],
              ),
            ),
          ),

          // TAB BAR
          TabBar(
            controller: _tabController,
            labelColor: primaryPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryPurple,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [
              Tab(text: 'Daftar hadiah'),
              Tab(text: 'Riwayat penukaran'),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // TAB VIEWS
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Daftar Hadiah
                _isLoadingRewards
                    ? const Center(child: CircularProgressIndicator())
                    : _rewards.isEmpty
                    ? const Center(child: Text('Belum ada hadiah tersedia.', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                  onRefresh: _fetchRewards,
                  color: primaryPurple,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _rewards.length,
                    itemBuilder: (context, index) {
                      return _buildRewardCard(_rewards[index]);
                    },
                  ),
                ),

                // TAB 2: Riwayat Penukaran
                _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _historyItems.isEmpty
                    ? const Center(child: Text('Belum ada riwayat penukaran.', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  color: primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ..._historyItems.map((item) => _buildHistoryCard(item)).toList(),
                        if (_historyTotalPages > 1) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildHistoryPaginationWidgets(),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CARD DAFTAR HADIAH ---
  Widget _buildRewardCard(dynamic item) {
    String name = item['name'] ?? 'Hadiah';
    int cost = item['points_cost'] ?? 0;
    int stock = item['stock_qty'] ?? 0;
    String imageUrl = item['image'] ?? '';
    bool isOutOfStock = stock <= 0;
    bool isPointsEnough = _currentPoints >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70, height: 70, color: Colors.grey.shade100,
              child: Image.network(
                imageUrl, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.blueAccent, child: Center(child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)))),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('$cost Poin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryPurple)),
                const SizedBox(height: 4),
                Text('Stock: $stock', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (isOutOfStock || !isPointsEnough) ? null : () => _showConfirmationModal(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              disabledBackgroundColor: primaryPink.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(80, 36),
            ),
            child: Text('Redeem', style: TextStyle(color: isOutOfStock || !isPointsEnough ? Colors.white70 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CARD RIWAYAT PENUKARAN ---
  // --- WIDGET CARD RIWAYAT PENUKARAN ---
  Widget _buildHistoryCard(dynamic item) {
    String name = item['reward_name'] ?? 'Hadiah';
    int spent = item['points_spent'] ?? 0;
    String status = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
    String dateRaw = item['requested_at'] ?? '';
    String? adminNote = item['admin_note'];

    // --- MENYIAPKAN VARIABEL GAMBAR DARI BACKEND ---
    // Mengantisipasi backend mengirim nama field 'image' atau 'reward_image'
    String imageUrl = item['image'] ?? item['reward_image'] ?? '';

    String formattedDate = '';
    if (dateRaw.isNotEmpty) {
      try {
        DateTime parsed = DateTime.parse(dateRaw);
        formattedDate = "${parsed.day}-${parsed.month}-${parsed.year}";
      } catch (e) {
        formattedDate = dateRaw.split('T')[0];
      }
    }

    // Warna status
    Color statusColor = Colors.orange;
    if (status == 'PROCESSED' || status == 'RECEIVED') {
      statusColor = Colors.green;
    } else if (status == 'REJECTED') {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _showHistoryDetailModal(item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                imageUrl.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade100,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: primaryPurple.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.card_giftcard, color: primaryPurple, size: 24),
                        );
                      },
                    ),
                  ),
                )
                    : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primaryPurple.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.card_giftcard, color: primaryPurple, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      if (adminNote != null && adminNote.isNotEmpty && (status == 'REJECTED' || status == 'PROCESSED')) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Catatan: $adminNote',
                          style: TextStyle(fontSize: 11, color: status == 'REJECTED' ? Colors.red.shade700 : Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('- $spent Poin', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE9005C))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'PROCESSED') ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _showReceiveConfirmationModal(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Terima Hadiah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET PAGINATION RIWAYAT ---
  List<Widget> _buildHistoryPaginationWidgets() {
    List<Widget> widgets = [];
    widgets.add(IconButton(iconSize: 24, icon: Icon(Icons.chevron_left, color: _historyCurrentPage > 1 ? Colors.black : Colors.grey), onPressed: _historyCurrentPage > 1 ? () => _changeHistoryPage(_historyCurrentPage - 1) : null));
    int startPage = _historyCurrentPage > 2 ? _historyCurrentPage - 1 : 1;
    int endPage = startPage + 2 > _historyTotalPages ? _historyTotalPages : startPage + 2;
    if (endPage - startPage < 2 && _historyTotalPages >= 3) startPage = endPage - 2;
    if (startPage > 1) {
      widgets.add(_buildHistoryClickablePageNumber(1));
      if (startPage > 2) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
    }
    for (int i = startPage; i <= endPage; i++) widgets.add(_buildHistoryClickablePageNumber(i));
    if (endPage < _historyTotalPages) {
      if (endPage < _historyTotalPages - 1) widgets.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      widgets.add(_buildHistoryClickablePageNumber(_historyTotalPages));
    }
    widgets.add(IconButton(iconSize: 24, icon: Icon(Icons.chevron_right, color: _historyCurrentPage < _historyTotalPages ? Colors.black : Colors.grey), onPressed: _historyCurrentPage < _historyTotalPages ? () => _changeHistoryPage(_historyCurrentPage + 1) : null));
    return widgets;
  }

  Widget _buildHistoryClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changeHistoryPage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4), width: 36, height: 36,
        decoration: BoxDecoration(color: page == _historyCurrentPage ? primaryPurple : Colors.white, borderRadius: BorderRadius.circular(10), border: page == _historyCurrentPage ? null : Border.all(color: Colors.grey.shade300)),
        child: Center(child: Text(page.toString(), style: TextStyle(color: page == _historyCurrentPage ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14))),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
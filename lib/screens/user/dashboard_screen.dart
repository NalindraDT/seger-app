import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/screens/user/activity_submission_screen.dart';
import 'package:pltuapp/screens/user/activity_history_screen.dart';
import 'package:pltuapp/screens/user/leaderboard_screen.dart';
import 'package:pltuapp/screens/user/reward_screen.dart';
import 'package:pltuapp/screens/user/event_detail_screen.dart';
import 'package:pltuapp/screens/user/profile_screen.dart';
import 'package:pltuapp/helpers/api_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  // --- VARIABEL DATA DINAMIS ---
  int _points = 0;
  int _exp = 0;
  int _streakDays = 0;

  double _todayDistance = 0.0;
  int _todayDuration = 0;
  int _todayActivities = 0;

  List<dynamic> _activeEvents = [];
  final PageController _eventPageController = PageController(viewportFraction: 0.88);
  int _currentEventPage = 0;

  // --- VARIABEL BADGE ---
  Map<String, dynamic>? _activeBadge;
  Map<String, dynamic>? _streakBadge;
  List<dynamic> _earnedBadges = [];

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);
  final Color bgColor = const Color(0xFFF8F9FA);

  bool _checkAuth(http.Response response) {
    if (response.statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      setState(() => _isLoading = false);
      return false; // Berhenti memproses data
    }
    return true; // Lanjut
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _eventPageController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return primaryPurple;
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      DateTime date = DateTime.parse(isoDate);
      return "${date.day}-${date.month}-${date.year}";
    } catch (e) {
      return isoDate.split('T')[0];
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 1. Fetch Data Profile
      final profileResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/users/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(profileResponse)) return;

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        if (profileData['success'] == true) {
          _points = profileData['data']['pointsBalance'] ?? 0;
          _exp = profileData['data']['xpBalance'] ?? 0;
          await prefs.setInt('points', _points);
          await prefs.setInt('exp', _exp);
        }
      } else {
        _points = prefs.getInt('points') ?? 0;
        _exp = prefs.getInt('exp') ?? 0;
      }

      // 2. Fetch Data Events
      final eventResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/events'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(eventResponse)) return;

      if (eventResponse.statusCode == 200) {
        final eventData = jsonDecode(eventResponse.body);
        if (eventData['success'] == true) {
          _activeEvents = eventData['data'];
        }
      }

      // 3. Fetch Data Badges (Hanya untuk Level Badge)
      final badgeResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/badges/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(badgeResponse)) return;

      if (badgeResponse.statusCode == 200) {
        final badgeData = jsonDecode(badgeResponse.body);
        if (badgeData['success'] == true && badgeData['data'] != null) {
          _activeBadge = badgeData['data']['active_badge'];
          _earnedBadges = badgeData['data']['earned_badges'] ?? [];
        }
      }

      // 4. Fetch Data History untuk HARI INI
      final historyResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/activities/history?page=1&limit=50'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(historyResponse)) return;

      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        if (historyData['success'] == true) {
          List<dynamic> items = historyData['data']['activity_items'] ?? [];
          String todayStr = DateTime.now().toString().split(' ')[0];

          double tempDistance = 0.0;
          int tempDuration = 0;
          int tempCount = 0;

          for (var item in items) {
            if (item['date'] == todayStr && item['status'] != 'REJECTED') {
              tempDistance += double.tryParse(item['distance_km'].toString()) ?? 0.0;
              tempDuration += double.tryParse(item['duration_minutes'].toString())?.toInt() ?? 0;
              tempCount += 1;
            }
          }

          _todayDistance = tempDistance;
          _todayDuration = tempDuration;
          _todayActivities = tempCount;
        }
      }

      // 5. Fetch Data Streak (Termasuk Lencana Streak)
      final streakResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/streak/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(streakResponse)) return;

      if (streakResponse.statusCode == 200) {
        final streakData = jsonDecode(streakResponse.body);
        if (streakData['success'] == true && streakData['data'] != null) {
          _streakDays = streakData['data']['current_streak_days'] ?? 0;

          // --- PERBAIKAN: Selalu ikuti API, walau null akan mereset data lama ---
          _streakBadge = streakData['data']['badge'];
        }
      }

    } catch (e) {
      debugPrint("Error fetching dashboard: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Hapus semua data

              if (!mounted) return;
              // PENTING: Gunakan pushNamedAndRemoveUntil agar semua tumpukan layar terhapus
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Tunggu sampai form ditutup, lalu tangkap nilainya
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ActivitySubmissionScreen()),
          );

          _fetchDashboardData();

          // Jika form mengirim nilai "true" (sukses submit)
          if (result == true) {
            setState(() {
              _selectedIndex = 1; // Pindah otomatis ke Tab Riwayat (Index 1)
            });

            // Munculkan notifikasi sukses bergaya modern
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Aktivitas berhasil dicatat!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              ),
            );
          }
        },
        backgroundColor: Colors.orange,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(icon: Icons.home_filled, label: 'Beranda', index: 0),
                  _buildNavItem(icon: Icons.assignment_outlined, label: 'Aktivitas', index: 1),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  SizedBox(height: 32),
                  Text('Catat', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(icon: Icons.insert_chart_outlined, label: 'Leaderboard', index: 2),
                  _buildNavItem(icon: Icons.person_outline, label: 'Profil', index: 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildBeranda();
      case 1:
        return const ActivityHistoryScreen();
      case 2:
        return const LeaderboardScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildBeranda();
    }
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isSelected = _selectedIndex == index;
    return MaterialButton(
      minWidth: 70,
      padding: EdgeInsets.zero,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? primaryPurple : Colors.grey, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: isSelected ? primaryPurple : Colors.grey, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET HALAMAN BERANDA
  // ===========================================================================
  Widget _buildBeranda() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- LOGIKA BADGE LEVEL ---
    double xpProgress = 0.0;
    String xpText = '';
    Color badgeColor = primaryPurple;
    String badgeName = 'Level 1';
    String badgeTier = '1';
    String? badgeImageUrl;

    if (_activeBadge != null) {
      badgeName = _activeBadge!['name'] ?? 'Level 1';
      badgeTier = (_activeBadge!['tier'] ?? 1).toString();
      badgeColor = _hexToColor(_activeBadge!['color'] ?? '#5D44F8');
      badgeImageUrl = _activeBadge!['image_url'];

      int minXp = _activeBadge!['min_xp'] ?? 0;
      int? maxXp = _activeBadge!['max_xp'];

      if (maxXp == null) {
        xpProgress = 1.0;
        xpText = '$_exp XP (Max Level)';
      } else {
        int xpInCurrentTier = _exp - minXp;
        int tierTotalXp = maxXp - minXp;

        if (xpInCurrentTier < 0) xpInCurrentTier = 0;

        xpProgress = (tierTotalXp > 0) ? (xpInCurrentTier / tierTotalXp) : 0.0;
        xpText = '$_exp / $maxXp XP ke lencana berikutnya';
      }
    }

    // --- LOGIKA BADGE STREAK (Sama dengan Profil) ---
    String? streakImageUrl;
    if (_streakBadge != null) {
      streakImageUrl = _streakBadge!['image'] ?? _streakBadge!['image_url'];
    }
    bool hasStreakBadge = streakImageUrl != null && streakImageUrl.isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchDashboardData,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      // const SizedBox(height: 4),
                      // Text('Siap beraktivitas hari ini?', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    // children: [
                    //   // --- TAMBAHAN: AVATAR KECIL SEBAGAI PENGGANTI TOMBOL LOGOUT ---
                    //   GestureDetector(
                    //     onTap: () {
                    //       // Jika diklik, pindah ke Tab Profil (Index 3)
                    //       setState(() {
                    //         _selectedIndex = 3;
                    //       });
                    //     },
                    //     child: Container(
                    //       width: 40,
                    //       height: 40,
                    //       decoration: BoxDecoration(
                    //         shape: BoxShape.circle,
                    //         color: primaryPurple.withOpacity(0.1),
                    //         border: Border.all(color: primaryPurple, width: 1.5),
                    //       ),
                    //       child: Icon(Icons.person, color: primaryPurple, size: 24),
                    //     ),
                    //   ),
                    //   // ---------------------------------------------------------------
                    //   // const SizedBox(width: 12),
                    //   // Stack(
                    //   //   children: [
                    //   //     Container(
                    //   //       padding: const EdgeInsets.all(8),
                    //   //       decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                    //   //       child: const Icon(Icons.notifications_none, color: Colors.black87),
                    //   //     ),
                    //   //     Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                    //   //   ],
                    //   // ),
                    // ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- CARD 1: RINGKASAN HARI INI DENGAN STREAK ---
              Container(
                width: double.infinity,
                height: 200, // Diperbesar sedikit agar pas dengan judul baru
                decoration: BoxDecoration(color: primaryPurple, borderRadius: BorderRadius.circular(20)),
                child: Stack(
                  children: [
                    // Gambar orang di kanan bawah
                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: Image.asset('assets/images/orang.png', height: 160, fit: BoxFit.contain)
                    ),

                    // --- JUDUL DI POJOK KIRI ATAS ---
                    const Positioned(
                      top: 16,
                      left: 20,
                      child: Text(
                        'Statistik Hari Ini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // --------------------------------

                    Padding(
                      // Top padding diubah jadi 40 agar tidak menabrak judul
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 40.0),
                      child: Row(
                        children: [
                          // AREA STREAK KIRI
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Badge kecil di atas streak
                              if (_streakBadge != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _streakBadge!['color'] != null ? _hexToColor(_streakBadge!['color']) : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: Text(
                                      _streakBadge!['name'] ?? 'STREAK',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],

                              // Bunderan Transparan + Hexagon Badge
                              Container(
                                width: 75, height: 75,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 55, height: 55,
                                    child: hasStreakBadge
                                        ? Image.network(
                                      streakImageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => Image.asset('assets/images/dotted_hexagon.png', fit: BoxFit.contain),
                                    )
                                        : Image.asset('assets/images/dotted_hexagon.png', fit: BoxFit.contain),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              Text('$_streakDays', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1)),
                              const Text('DAY STREAK', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // AREA STATISTIK HARI INI
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatItem(Icons.location_on, '$_todayDistance KM', 'JARAK', Colors.amber),
                                const SizedBox(height: 8),
                                _buildStatItem(Icons.access_time_filled, '$_todayDuration Menit', 'DURASI', Colors.orange),
                                const SizedBox(height: 8),
                                _buildStatItem(Icons.assignment, '$_todayActivities', 'AKTIFITAS', Colors.teal),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- BAGIAN EVENTS DINAMIS ---
              const Text('Event Yang Berlangsung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              if (_activeEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text("Tidak ada event aktif saat ini", style: TextStyle(color: Colors.grey))),
                )
              else ...[
                SizedBox(
                  height: 190,
                  child: PageView.builder(
                    controller: _eventPageController,
                    itemCount: _activeEvents.length,
                    onPageChanged: (index) => setState(() => _currentEventPage = index),
                    itemBuilder: (context, index) => _buildEventCard(_activeEvents[index]),
                  ),
                ),
                if (_activeEvents.length > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_activeEvents.length, (index) {
                      bool isActive = index == _currentEventPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? primaryPurple : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // --- CARD 3: TOTAL POIN ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Poin', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$_points Poin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryPurple)),
                        const SizedBox(height: 8),
                        const Text('Terus bergerak, kumpulkan poin dan tukarkan hadiah!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RewardScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: primaryPink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('Tukar Hadiah', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    Positioned(right: 0, top: 0, child: Image.asset('assets/images/koin.png', height: 60, fit: BoxFit.contain)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- CARD 4: MILESTONE LENCANA DENGAN TIER ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: badgeColor.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: badgeColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Row(
                  children: [
                    // --- KOTAK GAMBAR LENCANA & LABEL TIER ---
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: 65, height: 65,
                          child: (badgeImageUrl != null && badgeImageUrl.isNotEmpty)
                              ? Image.network(
                            badgeImageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Container(
                              decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5)
                              ),
                              child: Icon(Icons.shield, color: badgeColor, size: 36),
                            ),
                          )
                              : Container(
                            decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5)
                            ),
                            child: Icon(Icons.shield, color: badgeColor, size: 36),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Text(
                              'T$badgeTier',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  badgeName,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: badgeColor)
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Total Exp', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text('$_exp', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                                value: xpProgress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                                minHeight: 8
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(xpText, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET CARD EVENT (BANNER + SWIPE, KLIK LANGSUNG MASUK EVENT)
  // ===========================================================================
  Widget _buildEventCard(dynamic event) {
    Color eventColor = _hexToColor(event['color_theme'] ?? '#5D44F8');
    String imageUrl = event['banner_image_url'] ?? '';
    String status = (event['status'] ?? '').toString().toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event['id'])),
          );
          _fetchDashboardData();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            color: eventColor.withOpacity(0.15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: eventColor.withOpacity(0.2),
                          child: Icon(Icons.emoji_events, size: 48, color: eventColor),
                        ),
                      )
                    : Container(
                        color: eventColor.withOpacity(0.2),
                        child: Icon(Icons.emoji_events, size: 48, color: eventColor),
                      ),

                // Gradient agar teks tetap terbaca di atas gambar
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),

                if (status.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'ACTIVE' ? Colors.greenAccent.shade400 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 6, color: Colors.black87),
                          const SizedBox(width: 4),
                          Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['name'] ?? 'Event',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDate(event['start_at'])} - ${_formatDate(event['end_at'])}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PERBAIKAN WIDGET STATISTIK ---
  Widget _buildStatItem(IconData icon, String value, String label, Color iconColor) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2), // Background bulat menyesuaikan warna icon
                shape: BoxShape.circle
            ),
            child: Icon(icon, color: iconColor, size: 16)
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
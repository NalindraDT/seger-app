import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/screens/user/participant_profile_screen.dart';
import 'package:pltuapp/screens/user/department_members_leaderboard_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _leaderboardItems = [];
  List<dynamic> _departmentItems = [];
  Map<String, dynamic>? _currentDepartmentStat;
  String _departmentPeriod = 'annual';

  Map<String, dynamic>? _currentUserStat;

  int _currentPage = 1;
  int _totalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  bool get _isDepartmentTab => _tabController.index == 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 0) {
          _fetchLeaderboard();
        } else {
          _fetchDepartmentLeaderboard();
        }
      }
    });
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openParticipantProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipantProfileScreen(userId: userId),
      ),
    );
  }

  void _openDepartmentMembers(dynamic item) {
    final departmentId = item['department_id']?.toString();
    if (departmentId == null || departmentId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartmentMembersLeaderboardScreen(
          departmentId: departmentId,
          departmentName: item['department_name']?.toString() ?? 'Departemen',
          period: _departmentPeriod,
        ),
      ),
    );
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('userId');

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/leaderboard/annual?page=$_currentPage&limit=10'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
        setState(() => _isLoading = false);
        return; // Hentikan proses
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _leaderboardItems = data['data']['items'];
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];

            // Mencari user yang login di list halaman ini
            var findMe = _leaderboardItems.firstWhere(
                  (item) => item['user_id'] == myUserId,
              orElse: () => null,
            );

            // Jika ketemu di halaman ini, pakai data tersebut.
            // Jika tidak, pakai data current_user dari backend.
            if (findMe != null) {
              _currentUserStat = findMe;
            } else if (data['data']['current_user'] != null) {
              _currentUserStat = data['data']['current_user'];
            } else {
              _currentUserStat = null;
            }

            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal memuat data leaderboard.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  Future<void> _fetchDepartmentLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/leaderboard/departments/$_departmentPeriod?page=$_currentPage&limit=10'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
        setState(() => _isLoading = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _departmentItems = data['data']['items'] ?? [];
            _currentDepartmentStat = data['data']['current_department'];
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal memuat leaderboard departemen.');
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
      if (_isDepartmentTab) {
        _fetchDepartmentLeaderboard();
      } else {
        _fetchLeaderboard();
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int _getDepartmentXp(dynamic item) {
    if (item == null) return 0;
    final value = item['total_xp'] ?? item['xp'] ?? 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _getDepartmentMemberCount(dynamic item) {
    if (item == null) return 0;
    final value = item['member_count'] ?? 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _getDepartmentActiveCount(dynamic item) {
    if (item == null) return 0;
    final value = item['active_member_count'] ?? 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _changeDepartmentPeriod(String period) {
    if (_departmentPeriod == period) return;
    setState(() {
      _departmentPeriod = period;
      _currentPage = 1;
    });
    _fetchDepartmentLeaderboard();
  }

  String _departmentPeriodLabel() {
    switch (_departmentPeriod) {
      case 'daily':
        return 'Harian';
      case 'weekly':
        return 'Mingguan';
      case 'monthly':
        return 'Bulanan';
      default:
        return 'Tahunan';
    }
  }

  String _formatNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  String _getDepartmentName(dynamic item) {
    if (item == null) return '';
    return item['department_name'] ?? item['departmentName'] ?? '';
  }

  // --- HELPER UNTUK URL FOTO PROFIL (JAGA-JAGA VARIASI KEY DARI API) ---
  String _getPhotoUrl(dynamic item) {
    if (item == null) return '';
    return item['profile_photo_url'] ??
        item['profilePhotoUrl'] ??
        item['avatar_url'] ??
        item['avatarUrl'] ??
        '';
  }

  String _resolveAvatarUrl(dynamic item, String name) {
    String photoUrl = _getPhotoUrl(item);
    return photoUrl.isNotEmpty
        ? photoUrl
        : 'https://ui-avatars.com/api/?name=$name&background=random&color=fff';
  }

  // --- WIDGET AVATAR DENGAN FALLBACK IKON JIKA GAMBAR GAGAL DIMUAT ---
  Widget _buildAvatarImage(String avatarUrl, double radius) {
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: radius * 2,
          height: radius * 2,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: Icon(Icons.person, color: Colors.grey.shade400, size: radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _isDepartmentTab ? _departmentItems : _leaderboardItems;
    final topThree = items.where((e) => (e['rank'] ?? 99) <= 3).toList();
    final others = items.where((e) => (e['rank'] ?? 0) > 3).toList();
    final topDepartmentActive = items.isEmpty
        ? 1
        : items.map(_getDepartmentActiveCount).fold<int>(1, (prev, count) => count > prev ? count : prev);

    // --- SETUP VARIABEL KOTAK FLOATING CURRENT USER ---
    String myRank = _currentUserStat?['rank']?.toString() ?? '#';
    String myName = _currentUserStat != null ? _currentUserStat!['full_name'] : 'Kamu';
    String myXp = _currentUserStat != null ? _currentUserStat!['xp'].toString() : '0';
    String myDepartment = _getDepartmentName(_currentUserStat);

    // Logika Avatar User Login (Gunakan foto dari API, fallback ke UI Avatars)
    String myAvatarUrl = _resolveAvatarUrl(_currentUserStat, myName);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                _currentPage = 1;
                if (_isDepartmentTab) {
                  await _fetchDepartmentLeaderboard();
                } else {
                  await _fetchLeaderboard();
                }
              },
              color: primaryPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isDepartmentTab ? 'Departemen Paling Aktif' : 'Leaderboard Tahunan',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D)
                            ),
                          ),
                          if (_isDepartmentTab)
                            Text(
                              'Periode ${_departmentPeriodLabel()}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          Stack(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: primaryPurple,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: primaryPurple,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(text: 'Individual'),
                          Tab(text: 'Departemen'),
                        ],
                      ),
                    ),
                    if (_isDepartmentTab) _buildDepartmentPeriodFilter(),
                    const SizedBox(height: 12),
                    if (!_isDepartmentTab) _buildPodium(topThree) else _buildDepartmentPodium(topThree),
                    const SizedBox(height: 20),

                    // --- LIST RANK 4+ ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 100),
                      child: Column(
                        children: [
                          if (others.isEmpty && topThree.length < 4)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('Belum ada data peringkat lainnya.', style: TextStyle(color: Colors.grey)),
                            ),
                          if (_isDepartmentTab)
                            ...others.map((item) => _buildDepartmentListItem(item, topDepartmentActive)).toList()
                          else
                            ...others.map((item) => _buildListItem(item)).toList(),

                          if (_totalPages > 1) ...[
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildPaginationWidgets(),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- KOTAK FLOATING CURRENT USER / DEPARTEMEN ---
            if (!_isDepartmentTab)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: primaryPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPurple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(myRank, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: _buildAvatarImage(myAvatarUrl, 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            myName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (myDepartment.isNotEmpty)
                            Text(
                              myDepartment,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(myXp, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text(' Exp', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (_isDepartmentTab && _currentDepartmentStat != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () => _openDepartmentMembers(_currentDepartmentStat),
                  child: _buildCurrentDepartmentBar(_currentDepartmentStat!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentPeriodFilter() {
    const periods = [
      {'id': 'daily', 'label': 'Harian'},
      {'id': 'weekly', 'label': 'Mingguan'},
      {'id': 'monthly', 'label': 'Bulanan'},
      {'id': 'annual', 'label': 'Tahunan'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((period) {
            final selected = _departmentPeriod == period['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period['label']!),
                selected: selected,
                onSelected: (_) => _changeDepartmentPeriod(period['id']!),
                selectedColor: primaryPurple.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selected ? primaryPurple : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                side: BorderSide(color: selected ? primaryPurple : Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCurrentDepartmentBar(Map<String, dynamic> dept) {
    final rank = dept['rank'];
    final name = dept['department_name'] ?? 'Departemen';
    final activeMembers = _getDepartmentActiveCount(dept);
    final members = _getDepartmentMemberCount(dept);
    final xp = _getDepartmentXp(dept);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryPurple, primaryPurple.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Departemen Kamu',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                ),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$activeMembers/$members anggota aktif · ${_formatNumber(xp)} XP',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank != null ? '#$rank' : '-',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_formatNumber(xp)} XP',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET PODIUM
  // ===========================================================================
  Widget _buildPodium(List<dynamic> topThree) {
    if (topThree.isEmpty) {
      return const Center(child: Text('Belum ada data', style: TextStyle(color: Colors.grey)));
    }

    final rank1 = topThree.firstWhere((e) => e['rank'] == 1, orElse: () => null);
    final rank2 = topThree.firstWhere((e) => e['rank'] == 2, orElse: () => null);
    final rank3 = topThree.firstWhere((e) => e['rank'] == 3, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: rank2 != null
                ? _buildPodiumItem(rank2, 2, 110, Colors.blue, const Color(0xFFEAF4FF))
                : const SizedBox(height: 110),
          ),
          Expanded(
            child: rank1 != null
                ? _buildPodiumItem(rank1, 1, 150, Colors.amber, const Color(0xFFFFFBE6), hasCrown: true)
                : const SizedBox(height: 150),
          ),
          Expanded(
            child: rank3 != null
                ? _buildPodiumItem(rank3, 3, 90, Colors.redAccent, const Color(0xFFFCEAEA))
                : const SizedBox(height: 90),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(dynamic item, int rank, double height, Color themeColor, Color podiumColor, {bool hasCrown = false}) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = item['xp'].toString();
    String department = _getDepartmentName(item);

    // Logika Avatar untuk Podium
    String avatarUrl = _resolveAvatarUrl(item, name);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasCrown)
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 36),

        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Container(
                width: hasCrown ? 72 : 56,
                height: hasCrown ? 72 : 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 3),
                ),
                child: _buildAvatarImage(avatarUrl, hasCrown ? 33 : 25),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                  '$rank',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        if (department.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              department,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(xp, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const Text(' Exp', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET LIST ITEM
  // ===========================================================================
  Widget _buildListItem(dynamic item) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = item['xp'].toString();
    String department = _getDepartmentName(item);

    // Logika Avatar untuk List
    String avatarUrl = _resolveAvatarUrl(item, name);

    return GestureDetector(
      onTap: () => _openParticipantProfile(item['user_id']?.toString()),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              item['rank'].toString(),
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 40, height: 40, child: _buildAvatarImage(avatarUrl, 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (department.isNotEmpty)
                  Text(
                    department,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(xp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Text(' Exp', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    ),
    );
  }

  Widget _buildDepartmentPodium(List<dynamic> topThree) {
    if (topThree.isEmpty) {
      return const Center(child: Text('Belum ada data departemen', style: TextStyle(color: Colors.grey)));
    }

    dynamic rank1;
    dynamic rank2;
    dynamic rank3;
    for (final item in topThree) {
      if (item['rank'] == 1) rank1 = item;
      if (item['rank'] == 2) rank2 = item;
      if (item['rank'] == 3) rank3 = item;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: rank2 != null
                ? _buildDepartmentPodiumItem(rank2, 2, 110, Colors.blue, const Color(0xFFEAF4FF))
                : const SizedBox(height: 110),
          ),
          Expanded(
            child: rank1 != null
                ? _buildDepartmentPodiumItem(rank1, 1, 150, Colors.amber, const Color(0xFFFFFBE6), hasCrown: true)
                : const SizedBox(height: 150),
          ),
          Expanded(
            child: rank3 != null
                ? _buildDepartmentPodiumItem(rank3, 3, 90, Colors.deepOrange, const Color(0xFFFFF3E0))
                : const SizedBox(height: 90),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentPodiumItem(
    dynamic item,
    int rank,
    double height,
    Color themeColor,
    Color podiumColor, {
    bool hasCrown = false,
  }) {
    final name = item['department_name'] ?? 'Departemen';
    final activeMembers = _getDepartmentActiveCount(item);
    final members = _getDepartmentMemberCount(item);
    final xp = _getDepartmentXp(item);

    return GestureDetector(
      onTap: () => _openDepartmentMembers(item),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasCrown)
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 34),
        Container(
          width: hasCrown ? 68 : 56,
          height: hasCrown ? 68 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [themeColor.withOpacity(0.15), themeColor.withOpacity(0.35)],
            ),
            border: Border.all(color: themeColor, width: 3),
          ),
          child: Icon(Icons.business, color: themeColor, size: hasCrown ? 30 : 24),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$activeMembers aktif',
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          '$activeMembers/$members · ${_formatNumber(xp)} XP',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            border: Border.all(color: themeColor.withOpacity(0.15)),
          ),
          child: Text('$rank', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    ),
    );
  }

  Widget _buildDepartmentListItem(dynamic item, int topDepartmentActive) {
    final name = item['department_name'] ?? 'Departemen';
    final activeMembers = _getDepartmentActiveCount(item);
    final rank = item['rank']?.toString() ?? '-';
    final members = _getDepartmentMemberCount(item);
    final xp = _getDepartmentXp(item);
    final progress = topDepartmentActive > 0 ? (activeMembers / topDepartmentActive).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => _openDepartmentMembers(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(rank, style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business, color: primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('$activeMembers/$members anggota aktif · ${_formatNumber(xp)} XP total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$activeMembers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple)),
                  const Text('aktif', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primaryPurple.withOpacity(0.85)),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ===========================================================================
  // WIDGET PAGINATION
  // ===========================================================================
  List<Widget> _buildPaginationWidgets() {
    List<Widget> widgets = [];

    widgets.add(
      IconButton(
        iconSize: 24,
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
        iconSize: 24,
        icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey),
        onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
      ),
    );

    return widgets;
  }

  Widget _buildClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: page == _currentPage ? primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: page == _currentPage ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            page.toString(),
            style: TextStyle(
              color: page == _currentPage ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
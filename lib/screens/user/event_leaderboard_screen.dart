import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class EventLeaderboardScreen extends StatefulWidget {
  final String eventId;
  final Color themeColor;
  final String eventName;

  const EventLeaderboardScreen({
    Key? key,
    required this.eventId,
    required this.themeColor,
    required this.eventName,
  }) : super(key: key);

  @override
  State<EventLeaderboardScreen> createState() => _EventLeaderboardScreenState();
}

class _EventLeaderboardScreenState extends State<EventLeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _leaderboardItems = [];
  Map<String, dynamic>? _currentUserStat;

  int _currentPage = 1;
  int _totalPages = 1;

  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  // --- HELPER UNTUK PENGECEKAN SESI ---
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false;
    }
    return true;
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('userId');

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/leaderboard/events/${widget.eventId}?page=$_currentPage&limit=15'), // Limit sedikit dibesarkan
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
            _leaderboardItems = data['data']['items'] ?? [];
            _currentPage = data['data']['pagination']['page'] ?? 1;
            _totalPages = data['data']['pagination']['totalPages'] ?? 1;

            // Mencari user yang login
            var findMe = _leaderboardItems.firstWhere(
                  (item) => item['user_id'] == myUserId,
              orElse: () => null,
            );

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
        _showError('Gagal memuat data leaderboard event.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages && newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _fetchLeaderboard();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // --- HELPER UNTUK NAMA BIDANG/DEPARTEMEN ---
  String _getDepartmentName(dynamic item) {
    if (item == null) return '';
    return item['department_name'] ?? item['departmentName'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    // Memisahkan Top 3 dan peringkat di bawahnya
    final topThree = _leaderboardItems.where((e) => (e['rank'] ?? 99) <= 3).toList();
    final others = _leaderboardItems.where((e) => (e['rank'] ?? 0) > 3).toList();

    // Setup User Aktif
    String myRank = _currentUserStat?['rank']?.toString() ?? '#';
    String myName = _currentUserStat != null ? _currentUserStat!['full_name'] : 'Kamu';
    String myXp = _currentUserStat != null ? _currentUserStat!['xp'].toString() : '0';
    String myDepartment = _getDepartmentName(_currentUserStat);
    String? myProfilePhoto = _currentUserStat != null ? _currentUserStat!['profile_photo_url'] : null;
    String myAvatarUrl = (myProfilePhoto != null && myProfilePhoto.isNotEmpty)
        ? myProfilePhoto
        : 'https://ui-avatars.com/api/?name=$myName&background=ffffff&color=${widget.themeColor.value.toRadixString(16).substring(2, 8)}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.eventName,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : SafeArea(
        top: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                _currentPage = 1;
                await _fetchLeaderboard();
              },
              color: widget.themeColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Hanya tampilkan podium di halaman 1
                    if (_currentPage == 1) ...[
                      _buildPodium(topThree),
                      const SizedBox(height: 20),
                    ],

                    // LIST RANK
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 120), // Bottom padding untuk area kotak floating
                      child: Column(
                        children: [
                          if (_leaderboardItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 40, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text('Belum ada partisipan.', style: TextStyle(color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          // Jika halaman 1, tampilkan others (rank 4+). Jika halaman > 1, tampilkan semua items di halaman itu.
                          ...(_currentPage == 1 ? others : _leaderboardItems)
                              .map((item) => _buildListItem(item))
                              .toList(),

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

            // KOTAK FLOATING CURRENT USER
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.themeColor, widget.themeColor.withOpacity(0.85)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: Text(myRank, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(myAvatarUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Peringkat Kamu', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                          Text(myName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (myDepartment.isNotEmpty)
                            Text(myDepartment, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Text(myXp, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const Text(' XP', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- PODIUM ---
  Widget _buildPodium(List<dynamic> topThree) {
    if (topThree.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Belum ada data peringkat.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
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
                ? _buildPodiumItem(rank2, 2, 110, widget.themeColor, widget.themeColor.withOpacity(0.1))
                : const SizedBox(height: 110),
          ),
          Expanded(
            child: rank1 != null
                ? _buildPodiumItem(rank1, 1, 150, Colors.amber, const Color(0xFFFFFBE6), hasCrown: true)
                : const SizedBox(height: 150),
          ),
          Expanded(
            child: rank3 != null
                ? _buildPodiumItem(rank3, 3, 90, widget.themeColor, widget.themeColor.withOpacity(0.1))
                : const SizedBox(height: 90),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(dynamic item, int rank, double height, Color borderColor, Color podiumColor, {bool hasCrown = false}) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = (item['xp'] ?? 0).toString();
    String department = _getDepartmentName(item);
    String? profilePhoto = item['profile_photo_url'];
    String avatarUrl = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : 'https://ui-avatars.com/api/?name=$name&background=random&color=fff';

    final medalColor = rank == 1
        ? const Color(0xFFFFC107)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : const Color(0xFFCD7F32);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasCrown)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.workspace_premium, color: Colors.amber, size: 32),
          ),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [borderColor, borderColor.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: borderColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: CircleAvatar(
                  radius: hasCrown ? 34 : 26,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: hasCrown ? 66 : 50,
                      height: hasCrown ? 66 : 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: borderColor),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.military_tech, size: 12, color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: borderColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('$xp XP', style: TextStyle(color: borderColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(height: 10),
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [podiumColor, podiumColor.withOpacity(0.35)]),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Text('$rank', style: TextStyle(color: borderColor, fontWeight: FontWeight.w900, fontSize: 22)),
        ),
      ],
    );
  }

  // --- LIST ITEM ---
  Widget _buildListItem(dynamic item) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = (item['xp'] ?? 0).toString();
    String rank = (item['rank'] ?? 0).toString();
    String department = _getDepartmentName(item);
    String? profilePhoto = item['profile_photo_url'];
    String avatarUrl = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : 'https://ui-avatars.com/api/?name=$name&background=random&color=fff';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFF1F2F6), shape: BoxShape.circle),
            child: Text(rank, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade200, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('$xp XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.themeColor)),
          ),
        ],
      ),
    );
  }

  // --- PAGINATION ---
  List<Widget> _buildPaginationWidgets() {
    List<Widget> widgets = [];
    widgets.add(IconButton(iconSize: 24, icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black : Colors.grey), onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null));

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

    widgets.add(IconButton(iconSize: 24, icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey), onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null));
    return widgets;
  }

  Widget _buildClickablePageNumber(int page) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4), width: 36, height: 36,
        decoration: BoxDecoration(color: page == _currentPage ? widget.themeColor : Colors.white, borderRadius: BorderRadius.circular(10), border: page == _currentPage ? null : Border.all(color: Colors.grey.shade300)),
        child: Center(child: Text(page.toString(), style: TextStyle(color: page == _currentPage ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14))),
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _leaderboardItems = [];

  Map<String, dynamic>? _currentUserStat;

  int _currentPage = 1;
  int _totalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('userId');

      final response = await http.get(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/leaderboard/annual?page=$_currentPage&limit=10'),
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

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages && newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      _fetchLeaderboard();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topThree = _leaderboardItems.where((e) => e['rank'] <= 3).toList();
    final others = _leaderboardItems.where((e) => e['rank'] > 3).toList();

    // --- SETUP VARIABEL KOTAK FLOATING CURRENT USER ---
    String myRank = _currentUserStat?['rank']?.toString() ?? '#';
    String myName = _currentUserStat != null ? _currentUserStat!['full_name'] : 'Kamu';
    String myXp = _currentUserStat != null ? _currentUserStat!['xp'].toString() : '0';

    // Logika Avatar User Login (Gunakan foto dari API, fallback ke UI Avatars)
    String? myProfilePhoto = _currentUserStat != null ? _currentUserStat!['profile_photo_url'] : null;
    String myAvatarUrl = (myProfilePhoto != null && myProfilePhoto.isNotEmpty)
        ? myProfilePhoto
        : 'https://ui-avatars.com/api/?name=$myName&background=ffffff&color=5D44F8';

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
                await _fetchLeaderboard();
              },
              color: primaryPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Leaderboard Tahunan',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D)
                            ),
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
                            //       decoration: const BoxDecoration(
                            //         color: Colors.red,
                            //         shape: BoxShape.circle,
                            //       ),
                            //     ),
                            //   )
                            // ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    _buildPodium(topThree),
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

            // --- KOTAK FLOATING CURRENT USER ---
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: NetworkImage(myAvatarUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(myName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(myXp, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text(' Exp', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            )
          ],
        ),
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

    // Logika Avatar untuk Podium
    String? profilePhoto = item['profile_photo_url'];
    String avatarUrl = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : 'https://ui-avatars.com/api/?name=$name&background=random&color=fff';

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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 3),
                ),
                child: CircleAvatar(
                  radius: hasCrown ? 36 : 28,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
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

    // Logika Avatar untuk List
    String? profilePhoto = item['profile_photo_url'];
    String avatarUrl = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : 'https://ui-avatars.com/api/?name=$name&background=random&color=fff';

    return Container(
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
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Text(xp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Text(' Exp', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
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
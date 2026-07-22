import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/screens/user/participant_profile_screen.dart';

class DepartmentMembersLeaderboardScreen extends StatefulWidget {
  final String departmentId;
  final String departmentName;
  final String period;

  const DepartmentMembersLeaderboardScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.period,
  });

  @override
  State<DepartmentMembersLeaderboardScreen> createState() =>
      _DepartmentMembersLeaderboardScreenState();
}

class _DepartmentMembersLeaderboardScreenState extends State<DepartmentMembersLeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  Map<String, dynamic>? _currentUserStat;
  int _currentPage = 1;
  int _totalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  String _periodLabel() {
    switch (widget.period) {
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

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('userId');

      final response = await http.get(
        Uri.parse(
          '${ApiHelper.baseUrl}/leaderboard/departments/${widget.departmentId}/${widget.period}?page=$_currentPage&limit=10',
        ),
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
          final items = data['data']['items'] as List<dynamic>? ?? [];
          Map<String, dynamic>? findMe;
          for (final item in items) {
            if (item is Map && item['user_id']?.toString() == myUserId) {
              findMe = Map<String, dynamic>.from(item);
              break;
            }
          }

          setState(() {
            _items = items;
            _currentPage = data['data']['pagination']['page'];
            _totalPages = data['data']['pagination']['totalPages'];
            if (findMe != null) {
              _currentUserStat = findMe;
            } else if (data['data']['current_user'] != null) {
              _currentUserStat = Map<String, dynamic>.from(data['data']['current_user'] as Map);
            } else {
              _currentUserStat = null;
            }
            _isLoading = false;
          });
          return;
        }
      }

      setState(() => _isLoading = false);
      _showError('Gagal memuat anggota departemen.');
    } catch (_) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
    }
  }

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages && newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _fetchMembers();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _openParticipantProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ParticipantProfileScreen(userId: userId)),
    );
  }

  String _resolveAvatarUrl(dynamic item, String name) {
    if (item == null) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff';
    }

    final photoUrl = item['profile_photo_url']?.toString() ??
        item['profilePhotoUrl']?.toString() ??
        '';
    return photoUrl.isNotEmpty
        ? photoUrl
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff';
  }

  Widget _buildAvatarImage(String avatarUrl, double radius) {
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: radius * 2,
          height: radius * 2,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: Icon(Icons.person, color: Colors.grey.shade400, size: radius),
        ),
      ),
    );
  }

  Widget _buildListItem(dynamic item) {
    final name = item['full_name']?.toString() ?? 'Unknown';
    final xp = item['xp']?.toString() ?? '0';
    final avatarUrl = _resolveAvatarUrl(item, name);

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
              child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text(xp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Text(' Exp', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topThree = _items.where((e) => (e['rank'] ?? 99) <= 3).toList();
    final others = _items.where((e) => (e['rank'] ?? 0) > 3).toList();

    final myRank = _currentUserStat?['rank']?.toString() ?? '-';
    final myName = _currentUserStat?['full_name']?.toString() ?? 'Kamu';
    final myXp = _currentUserStat?['xp']?.toString() ?? '0';
    final myAvatarUrl = _currentUserStat != null ? _resolveAvatarUrl(_currentUserStat, myName) : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.departmentName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'XP Tertinggi · Periode ${_periodLabel()}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    _currentPage = 1;
                    await _fetchMembers();
                  },
                  color: primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      children: [
                        if (_items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'Belum ada anggota aktif di departemen ini.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else ...[
                          if (topThree.isNotEmpty) _buildPodium(topThree),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
                            child: Column(
                              children: [
                                ...others.map(_buildListItem),
                                if (_totalPages > 1) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: _buildPaginationWidgets(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_currentUserStat != null)
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
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              myRank,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
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
                            child: Text(
                              myName,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(myXp, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const Text(' Exp', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPodium(List<dynamic> topThree) {
    dynamic rank1;
    dynamic rank2;
    dynamic rank3;
    for (final item in topThree) {
      if (item['rank'] == 1) rank1 = item;
      if (item['rank'] == 2) rank2 = item;
      if (item['rank'] == 3) rank3 = item;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: rank2 != null ? _buildPodiumItem(rank2, 2, 100, Colors.blue) : const SizedBox(height: 100)),
          Expanded(child: rank1 != null ? _buildPodiumItem(rank1, 1, 130, Colors.amber, hasCrown: true) : const SizedBox(height: 130)),
          Expanded(child: rank3 != null ? _buildPodiumItem(rank3, 3, 85, Colors.deepOrange) : const SizedBox(height: 85)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(dynamic item, int rank, double height, Color themeColor, {bool hasCrown = false}) {
    final name = item['full_name']?.toString() ?? 'Unknown';
    final xp = item['xp']?.toString() ?? '0';
    final avatarUrl = _resolveAvatarUrl(item, name);

    return GestureDetector(
      onTap: () => _openParticipantProfile(item['user_id']?.toString()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasCrown) const Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: hasCrown ? 64 : 52,
                  height: hasCrown ? 64 : 52,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor, width: 3),
                  ),
                  child: _buildAvatarImage(avatarUrl, hasCrown ? 29 : 23),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text('$xp Exp', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.12),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaginationWidgets() {
    return [
      IconButton(
        icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black : Colors.grey),
        onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
      ),
      Text('$_currentPage / $_totalPages', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
      IconButton(
        icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black : Colors.grey),
        onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
      ),
    ];
  }
}

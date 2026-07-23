import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/screens/user/event_activity_submission_screen.dart';
import 'package:pltuapp/screens/user/event_activity_history_screen.dart';
import 'package:pltuapp/screens/user/event_leaderboard_screen.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _eventDetail;
  List<dynamic> _leaderboardItems = [];
  Map<String, dynamic>? _currentUserStat;

  // Default color jika API gagal memuat warna
  Color _themeColor = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  // --- HELPER UNTUK KONVERSI HEX KE COLOR FLUTTER ---
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFF5D44F8);
    }
  }

  // --- HELPER FORMAT TANGGAL ---
  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      DateTime date = DateTime.parse(isoDate);
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (e) {
      return isoDate.split('T')[0];
    }
  }

  // --- HELPER UNTUK PENGECEKAN SESI (401) ---
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false; // Token kedaluwarsa, hentikan proses
    }
    return true; // Token aman
  }

  Future<void> _fetchEventData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('userId');

      // 1. Fetch Event Detail
      final eventResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/events/${widget.eventId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Cek sesi
      if (!_checkAuth(eventResponse.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (eventResponse.statusCode == 200) {
        final data = jsonDecode(eventResponse.body);
        if (data['success'] == true) {
          _eventDetail = data['data'];
          if (_eventDetail!['color_theme'] != null) {
            _themeColor = _hexToColor(_eventDetail!['color_theme']);
          }
        }
      }

      // 2. Fetch Event Leaderboard
      final leadResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/leaderboard/events/${widget.eventId}?page=1&limit=10'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Cek sesi
      if (!_checkAuth(leadResponse.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (leadResponse.statusCode == 200) {
        final leadData = jsonDecode(leadResponse.body);
        if (leadData['success'] == true && leadData['data']['items'] != null) {
          _leaderboardItems = leadData['data']['items'];

          // Mencari posisi user yang sedang login di event ini
          var findMe = _leaderboardItems.firstWhere(
                (item) => item['user_id'] == myUserId,
            orElse: () => null,
          );

          if (findMe != null) {
            _currentUserStat = findMe;
          } else if (leadData['data']['current_user'] != null) {
            _currentUserStat = leadData['data']['current_user'];
          } else {
            _currentUserStat = null;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan jaringan.');
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
    if (item == null) {
      return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff';
    }
    String photoUrl = _getPhotoUrl(item);
    return photoUrl.isNotEmpty
        ? photoUrl
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff';
  }

  double get _eventProgress {
    final startAt = _parseEventDate(_eventDetail?['start_at']?.toString());
    final endAt = _parseEventDate(_eventDetail?['end_at']?.toString());
    if (startAt == null || endAt == null || !endAt.isAfter(startAt)) return 0;
    final now = DateTime.now();
    if (now.isBefore(startAt)) return 0;
    if (now.isAfter(endAt)) return 1;
    return (now.difference(startAt).inMilliseconds / endAt.difference(startAt).inMilliseconds).clamp(0.0, 1.0);
  }

  String get _eventPhaseLabel {
    if (_isComingSoon) return 'Segera Dimulai';
    if (_canSubmitActivity) return 'Sedang Berlangsung';
    return 'Event Berakhir';
  }

  DateTime? _parseEventDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    try {
      return DateTime.parse(isoDate);
    } catch (_) {
      return null;
    }
  }

  bool get _isComingSoon {
    final startAt = _parseEventDate(_eventDetail?['start_at']?.toString());
    if (startAt == null) return false;
    return DateTime.now().isBefore(startAt);
  }

  bool get _canSubmitActivity {
    final startAt = _parseEventDate(_eventDetail?['start_at']?.toString());
    final endAt = _parseEventDate(_eventDetail?['end_at']?.toString());
    if (startAt == null || endAt == null) return false;
    final now = DateTime.now();
    return !now.isBefore(startAt) && !now.isAfter(endAt);
  }

  Widget _buildEventInfoSection() {
    final description = _eventDetail?['description']?.toString().trim() ?? '';
    final rules = _eventDetail?['rules']?.toString().trim() ?? '';

    if (description.isEmpty && rules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.info_outline_rounded, color: _themeColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Informasi Event',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            if (description.isNotEmpty)
              _buildInfoBlock(
                title: 'Deskripsi',
                content: description,
                icon: Icons.description_outlined,
              ),
            if (description.isNotEmpty && rules.isNotEmpty)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 18, endIndent: 18),
            if (rules.isNotEmpty)
              _buildInfoBlock(
                title: 'Aturan',
                content: rules,
                icon: Icons.rule_rounded,
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required String title,
    required String content,
    required IconData icon,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, isLast ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _themeColor.withOpacity(0.85)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _themeColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventProgressCard() {
    final start = _formatDate(_eventDetail?['start_at']?.toString() ?? '');
    final end = _formatDate(_eventDetail?['end_at']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_themeColor.withOpacity(0.08), _themeColor.withOpacity(0.02)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _themeColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _themeColor, borderRadius: BorderRadius.circular(999)),
                  child: Text(_eventPhaseLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(Icons.calendar_month_rounded, size: 16, color: _themeColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('$start – $end', style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _eventProgress > 0 ? _eventProgress : null,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_themeColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isComingSoon
                  ? 'Event belum dimulai — persiapkan diri kamu!'
                  : (_canSubmitActivity ? 'Event aktif — catat aktivitasmu sekarang.' : 'Event telah selesai.'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _actionTile(
              icon: Icons.history_rounded,
              label: 'Riwayat',
              subtitle: 'Aktivitas event',
              filled: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventActivityHistoryScreen(
                      eventId: widget.eventId,
                      themeColor: _themeColor,
                      eventName: _eventDetail?['name'] ?? 'Event',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionTile(
              icon: Icons.add_circle_rounded,
              label: _isComingSoon ? 'Belum Mulai' : (_canSubmitActivity ? 'Catat' : 'Selesai'),
              subtitle: 'Aktivitas baru',
              filled: true,
              enabled: _canSubmitActivity,
              onTap: _canSubmitActivity
                  ? () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventActivitySubmissionScreen(
                            eventId: widget.eventId,
                            themeColor: _themeColor,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventActivityHistoryScreen(
                              eventId: widget.eventId,
                              themeColor: _themeColor,
                              eventName: _eventDetail?['name'] ?? 'Event',
                              isFromSubmission: true,
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool filled,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: filled ? _themeColor : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: filled ? 2 : 0,
      shadowColor: _themeColor.withOpacity(0.3),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: _themeColor.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: filled ? Colors.white : _themeColor, size: 22),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : _themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: filled ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final topThree = _leaderboardItems.where((e) => (e['rank'] ?? 99) <= 3).toList();
    final others = _leaderboardItems.where((e) => (e['rank'] ?? 0) > 3).toList();

    // --- SETUP VARIABEL KOTAK FLOATING CURRENT USER ---
    String myRank = _currentUserStat?['rank']?.toString() ?? '#';
    String myName = _currentUserStat != null ? _currentUserStat!['full_name'] : 'Kamu';
    String myXp = _currentUserStat != null ? _currentUserStat!['xp'].toString() : '0';
    String myDepartment = _getDepartmentName(_currentUserStat);

    final myAvatarUrl = _currentUserStat != null ? _resolveAvatarUrl(_currentUserStat, myName) : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _fetchEventData,
                  color: _themeColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 300,
                        pinned: true,
                        backgroundColor: _themeColor,
                        foregroundColor: Colors.white,
                        flexibleSpace: FlexibleSpaceBar(
                          background: _buildHeroBanner(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEventProgressCard(),
                            _buildQuickActions(),
                            _buildEventInfoSection(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Leaderboard Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EventLeaderboardScreen(
                                            eventId: widget.eventId,
                                            themeColor: _themeColor,
                                            eventName: _eventDetail?['name'] ?? 'Leaderboard Event',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.leaderboard_rounded, size: 18, color: _themeColor),
                                    label: Text('Lihat Semua', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            _buildPodium(topThree),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                              child: Column(
                                children: [
                                  if (others.isEmpty && topThree.length < 4)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.leaderboard_outlined, size: 40, color: Colors.grey.shade300),
                                          const SizedBox(height: 8),
                                          Text('Belum ada peserta di leaderboard.', style: TextStyle(color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                  ...others.map((item) => _buildListItem(item)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentUserStat != null)
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
                          colors: [_themeColor, _themeColor.withOpacity(0.85)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: _themeColor.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6)),
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
                          SizedBox(width: 36, height: 36, child: _buildAvatarImage(myAvatarUrl, 16)),
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
                  ),
              ],
            ),
    );
  }

  Widget _buildHeroBanner() {
    if (_eventDetail == null) return Container(color: _themeColor);

    String name = _eventDetail!['name'] ?? '';
    String imageUrl = _eventDetail!['banner_image_url'] ?? '';
    String start = _formatDate(_eventDetail!['start_at'] ?? '');
    String end = _formatDate(_eventDetail!['end_at'] ?? '');
    String status = (_eventDetail!['status'] ?? '').toString().toUpperCase();
    Color statusBadgeColor = status == 'ACTIVE' ? Colors.greenAccent.shade400 : Colors.grey.shade400;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _themeColor))
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_themeColor, _themeColor.withOpacity(0.6)]),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.75)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isComingSoon)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(999)),
                        child: const Text('Coming Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: statusBadgeColor, borderRadius: BorderRadius.circular(999)),
                      child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text('$start – $end', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET PODIUM LEADERBOARD
  // ===========================================================================
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
            Text('Belum ada data peringkat untuk event ini.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
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
                ? _buildPodiumItem(rank2, 2, 110, _themeColor, _themeColor.withOpacity(0.1))
                : const SizedBox(height: 110),
          ),
          Expanded(
            child: rank1 != null
                ? _buildPodiumItem(rank1, 1, 150, Colors.amber, const Color(0xFFFFFBE6), hasCrown: true)
                : const SizedBox(height: 150),
          ),
          Expanded(
            child: rank3 != null
                ? _buildPodiumItem(rank3, 3, 90, _themeColor, _themeColor.withOpacity(0.1))
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

    // Logika Avatar untuk Podium
    String avatarUrl = _resolveAvatarUrl(item, name);

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
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.military_tech, size: 12, color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Text('$rank', style: TextStyle(color: borderColor, fontWeight: FontWeight.w900, fontSize: 22)),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET LIST ITEM RANK 4+
  // ===========================================================================
  Widget _buildListItem(dynamic item) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = (item['xp'] ?? 0).toString();
    String rank = (item['rank'] ?? 0).toString();
    String department = _getDepartmentName(item);

    // Logika Avatar untuk List
    String avatarUrl = _resolveAvatarUrl(item, name);

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
          SizedBox(width: 40, height: 40, child: _buildAvatarImage(avatarUrl, 20)),
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
            decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('$xp XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _themeColor)),
          ),
        ],
      ),
    );
  }
}
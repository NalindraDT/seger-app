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

  @override
  Widget build(BuildContext context) {
    final topThree = _leaderboardItems.where((e) => (e['rank'] ?? 99) <= 3).toList();
    final others = _leaderboardItems.where((e) => (e['rank'] ?? 0) > 3).toList();

    // --- SETUP VARIABEL KOTAK FLOATING CURRENT USER ---
    String myRank = _currentUserStat?['rank']?.toString() ?? '#';
    String myName = _currentUserStat != null ? _currentUserStat!['full_name'] : 'Kamu';
    String myXp = _currentUserStat != null ? _currentUserStat!['xp'].toString() : '0';

    // Logika Avatar User Login
    String? myProfilePhoto = _currentUserStat != null ? _currentUserStat!['profile_photo_url'] : null;
    String myAvatarUrl = (myProfilePhoto != null && myProfilePhoto.isNotEmpty)
        ? myProfilePhoto
        : 'https://ui-avatars.com/api/?name=$myName&background=ffffff&color=${_themeColor.value.toRadixString(16).substring(2, 8)}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            _eventDetail?['name'] ?? 'Detail Event',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchEventData,
            color: _themeColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: BANNER EVENT ---
                  _buildEventBanner(),

                  // --- SECTION 2: TOMBOL CATAT AKTIVITAS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        // Tombol Lihat Riwayat (Outlined)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
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
                              icon: Icon(Icons.history, color: _themeColor, size: 20),
                              label: Text('Riwayat', style: TextStyle(color: _themeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _themeColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol Catat Aktivitas (Solid)
                        Expanded(
                          flex: 1, // Atur flex kalau mau salah satu lebih lebar
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventActivitySubmissionScreen(
                                      eventId: widget.eventId,
                                      themeColor: _themeColor,
                                    ),
                                  ),
                                );

                                // Jika sukses submit
                                if (result == true) {
                                  if (!mounted) return;

                                  // Lempar user ke halaman Riwayat Event dengan membawa "pesan rahasia"
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EventActivityHistoryScreen(
                                        eventId: widget.eventId,
                                        themeColor: _themeColor,
                                        eventName: _eventDetail?['name'] ?? 'Event',
                                        isFromSubmission: true, // <-- FLAG INI SANGAT PENTING
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
                              label: const Text('Catat', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _themeColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- SECTION 3: LEADERBOARD HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Leaderboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                        TextButton(
                          onPressed: () {
                            // --- TAMBAHKAN NAVIGASI KE LEADERBOARD EVENT ---
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
                          child: Text('View All >', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 4: PODIUM TOP 3 ---
                  _buildPodium(topThree),
                  const SizedBox(height: 20),

                  // --- SECTION 5: LIST LEADERBOARD RANK 4+ ---
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 120),
                    child: Column(
                      children: [
                        if (others.isEmpty && topThree.length < 4)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('Belum ada data peringkat lainnya.', style: TextStyle(color: Colors.grey)),
                          ),
                        ...others.map((item) => _buildListItem(item)).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- KOTAK FLOATING CURRENT USER (Sesuai warna tema event) ---
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _themeColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _themeColor.withOpacity(0.4),
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
    );
  }

  // ===========================================================================
  // WIDGET BANNER
  // ===========================================================================
  Widget _buildEventBanner() {
    if (_eventDetail == null) return const SizedBox();

    String name = _eventDetail!['name'] ?? '';
    String imageUrl = _eventDetail!['banner_image_url'] ?? '';
    String start = _formatDate(_eventDetail!['start_at'] ?? '');
    String end = _formatDate(_eventDetail!['end_at'] ?? '');
    String status = (_eventDetail!['status'] ?? '').toString().toUpperCase();

    Color statusBadgeColor = status == 'ACTIVE' ? Colors.greenAccent.shade400 : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 220,
          color: Colors.grey.shade200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Gagal memuat gambar event: $error');
                  return Icon(Icons.image, size: 50, color: Colors.white54);
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _themeColor.withOpacity(0.8),
                      _themeColor,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBadgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$start - $end',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET PODIUM LEADERBOARD
  // ===========================================================================
  Widget _buildPodium(List<dynamic> topThree) {
    if (topThree.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text('Belum ada data peringkat untuk event ini.', style: TextStyle(color: Colors.grey.shade600)),
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
                  border: Border.all(color: borderColor, width: 3),
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
                color: borderColor,
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
            Text(xp, style: TextStyle(color: borderColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
  // WIDGET LIST ITEM RANK 4+
  // ===========================================================================
  Widget _buildListItem(dynamic item) {
    String name = item['full_name'] ?? 'Unknown';
    String xp = (item['xp'] ?? 0).toString();

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
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/widgets/badge_network_image.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({Key? key}) : super(key: key);

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  bool _isLoading = true;
  int _currentStreak = 0;
  int _longestStreak = 0;
  String? _lastActivityDate;
  Map<String, dynamic>? _streakBadge;
  List<dynamic> _history = [];
  int _currentPage = 1;
  int _totalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final meRes = await http.get(Uri.parse('${ApiHelper.baseUrl}/streak/me'), headers: headers);
      if (meRes.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
        return;
      }
      if (meRes.statusCode == 200) {
        final data = jsonDecode(meRes.body)['data'];
        if (data != null) {
          _currentStreak = data['current_streak_days'] ?? 0;
          _longestStreak = data['longest_streak_days'] ?? 0;
          _lastActivityDate = data['last_activity_date'];
          _streakBadge = data['badge'];
        }
      }

      final histRes = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/streak/history?page=$_currentPage&limit=10'),
        headers: headers,
      );
      if (histRes.statusCode == 200) {
        final data = jsonDecode(histRes.body)['data'];
        if (data != null) {
          _history = data['items'] ?? [];
          _currentPage = data['pagination']?['page'] ?? 1;
          _totalPages = data['pagination']?['totalPages'] ?? 1;
        }
      }
    } catch (e) {
      debugPrint('Error streak: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeName = _streakBadge?['name']?.toString();
    final badgeImage = _streakBadge?['image'] ?? _streakBadge?['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Streak', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryPurple))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: primaryPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryPurple, primaryPurple.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          BadgeNetworkImage(
                            imageUrl: badgeImage?.toString(),
                            kind: BadgeImageKind.streak,
                            width: 72,
                            height: 72,
                            labelText: badgeName,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_currentStreak Hari',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Streak Aktif',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          if (badgeName != null) ...[
                            const SizedBox(height: 8),
                            Text(badgeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _statTile('Terpanjang', '$_longestStreak hari', Icons.emoji_events)),
                        const SizedBox(width: 12),
                        Expanded(child: _statTile('Terakhir Aktif', _formatDate(_lastActivityDate), Icons.calendar_today)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Riwayat Milestone',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_history.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('Belum ada milestone streak.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ..._history.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_fire_department, color: Colors.orange),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['milestone_days']} Hari Streak',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '+${item['xp_reward'] ?? 0} XP • ${_formatDate(item['awarded_on_date']?.toString())}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryPurple, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/widgets/badge_network_image.dart';
import 'package:pltuapp/widgets/modern_activity_ui.dart';

class ParticipantProfileScreen extends StatefulWidget {
  final String userId;

  const ParticipantProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<dynamic> _badges = [];
  List<dynamic> _activities = [];
  int _activityPage = 1;
  int _activityTotalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false;
    }
    return true;
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

      final profileRes = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/users/${widget.userId}/public'),
        headers: headers,
      );
      if (!_checkAuth(profileRes.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      final badgesRes = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/users/${widget.userId}/badges'),
        headers: headers,
      );
      if (!_checkAuth(badgesRes.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      final activitiesRes = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/users/${widget.userId}/activities?page=$_activityPage&limit=10'),
        headers: headers,
      );
      if (!_checkAuth(activitiesRes.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        if (data['success'] == true) {
          _profile = data['data'];
        }
      }

      if (badgesRes.statusCode == 200) {
        final data = jsonDecode(badgesRes.body);
        if (data['success'] == true) {
          _badges = data['data'] is List ? data['data'] : (data['data']['items'] ?? []);
        }
      }

      if (activitiesRes.statusCode == 200) {
        final data = jsonDecode(activitiesRes.body);
        if (data['success'] == true) {
          final payload = data['data'];
          if (payload['items'] != null) {
            _activities = payload['items'] ?? [];
          } else {
            final annual = payload['activity_items'] ?? [];
            final event = payload['event_items'] ?? [];
            final merged = [...List<dynamic>.from(annual), ...List<dynamic>.from(event)];
            merged.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
            _activities = merged;
          }
          _activityPage = payload['pagination']?['page'] ?? 1;
          _activityTotalPages = payload['pagination']?['totalPages'] ?? 1;
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat profil peserta.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _readField(Map<String, dynamic>? map, List<String> keys, {String fallback = '-'}) {
    if (map == null) return fallback;
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return primaryPurple;
    }
  }

  void _showZoomableImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
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
      ),
    );
  }

  void _showActivityDetail(dynamic item) {
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

  void _changeActivityPage(int page) {
    if (page < 1 || page > _activityTotalPages || page == _activityPage) return;
    setState(() => _activityPage = page);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _readField(_profile, ['full_name', 'fullName'], fallback: 'Peserta');
    final department = _readField(_profile, ['department_name', 'departmentName']);
    final company = _readField(_profile, ['company_name', 'companyName']);
    final xp = _readField(_profile, ['xp_balance', 'xpBalance', 'xp'], fallback: '0');
    final tierName = _readField(
      _profile,
      ['tier_name', 'tierName', 'badge_name', 'badgeName'],
      fallback: 'Level 1',
    );
    final tierLevel = _readField(_profile, ['tier', 'tier_level', 'tierLevel'], fallback: '1');
    final photoUrl = _readField(_profile, ['profile_photo_url', 'profilePhotoUrl'], fallback: '');
    final avatarUrl = photoUrl.isNotEmpty
        ? photoUrl
        : 'https://ui-avatars.com/api/?name=$fullName&background=5D44F8&color=fff';

    final tierColorHex = _profile?['tier_color'] ?? _profile?['badge_color'] ?? '#5D44F8';
    final tierColor = _hexToColor(tierColorHex.toString());

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profil Peserta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryPurple,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(avatarUrl),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.business_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        department,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.apartment_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        company,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Tier', tierName, subtitle: 'Level $tierLevel', color: tierColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('XP', xp, subtitle: 'Total poin', color: primaryPurple),
                        ),
                      ],
                    ),
                    if (_badges.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Lencana',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _badges.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final badge = _badges[index];
                            final name = badge['name']?.toString() ?? 'Badge';
                            final imageUrl = badge['image_url'] ?? badge['image'];
                            return Container(
                              width: 80,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  BadgeNetworkImage(
                                    imageUrl: imageUrl?.toString(),
                                    kind: BadgeImageKind.tier,
                                    width: 36,
                                    height: 36,
                                    fallbackIcon: Icons.military_tech,
                                    fallbackIconColor: primaryPurple,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Riwayat Aktivitas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                    ),
                    const SizedBox(height: 12),
                    if (_activities.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text('Belum ada aktivitas.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else ...[
                      ..._activities.map((item) {
                        final photo = item['proof_photo']?.toString() ?? '';
                        return ModernActivityCard(
                          item: item,
                          accentColor: primaryPurple,
                          eventName: item['event_name']?.toString(),
                          onTapDetail: () => _showActivityDetail(item),
                          onTapImage: () {
                            if (photo.isNotEmpty) {
                              _showZoomableImage(photo);
                            } else {
                              _showActivityDetail(item);
                            }
                          },
                        );
                      }),
                      if (_activityTotalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _activityPage > 1 ? () => _changeActivityPage(_activityPage - 1) : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text('$_activityPage / $_activityTotalPages'),
                              IconButton(
                                onPressed: _activityPage < _activityTotalPages ? () => _changeActivityPage(_activityPage + 1) : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, {required String subtitle, required Color color}) {
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
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

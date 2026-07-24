import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/screens/user/activity_history_screen.dart';
import 'package:pltuapp/screens/user/reward_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/users/notifications?page=1&limit=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _notifications = data['data']['items'] ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markNotificationRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      await http.post(
        Uri.parse('${ApiHelper.baseUrl}/users/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notification_ids': [notificationId]}),
      );
      await _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      await http.post(
        Uri.parse('${ApiHelper.baseUrl}/users/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );
      await _fetchNotifications();
    } catch (_) {}
  }

  String _formatNotificationTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final date = DateTime.parse(iso).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  IconData _notificationIcon(String? type) {
    if (type == 'reward_redemption') return Icons.card_giftcard_rounded;
    return Icons.directions_run_rounded;
  }

  Color _notificationColor(String? type, String title) {
    if (type == 'reward_redemption') return primaryPink;
    if (title.toLowerCase().contains('ditolak')) return Colors.red;
    if (title.toLowerCase().contains('disetujui')) return Colors.green;
    return primaryPurple;
  }

  void _handleNotificationTap(dynamic notification) {
    final type = notification['type']?.toString();
    final isRead = notification['is_read'] == true;

    if (!isRead && notification['id'] != null) {
      _markNotificationRead(notification['id'].toString());
    }

    if (type == 'activity_reviewed') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
      );
      return;
    }

    if (type == 'reward_redemption') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RewardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D2D2D),
        elevation: 0.5,
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Tandai dibaca',
                style: TextStyle(color: primaryPurple, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Belum ada notifikasi',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final type = notification['type']?.toString();
                        final title = notification['title']?.toString() ?? 'Notifikasi';
                        final message = notification['message']?.toString() ?? '';
                        final isRead = notification['is_read'] == true;
                        final color = _notificationColor(type, title);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isRead ? Colors.grey.shade200 : color.withOpacity(0.35)),
                          ),
                          child: ListTile(
                            onTap: () => _handleNotificationTap(notification),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_notificationIcon(type), color: color, size: 22),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isRead ? Colors.grey.shade700 : const Color(0xFF1F2937),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(message, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatNotificationTime(notification['created_at']?.toString()),
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            trailing: isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

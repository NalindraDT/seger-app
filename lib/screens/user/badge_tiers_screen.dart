import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/widgets/badge_network_image.dart';

class BadgeTiersScreen extends StatefulWidget {
  const BadgeTiersScreen({super.key});

  @override
  State<BadgeTiersScreen> createState() => _BadgeTiersScreenState();
}

class _BadgeTiersScreenState extends State<BadgeTiersScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _refreshTimer;
  int _currentXp = 0;
  List<dynamic> _tiers = [];
  Map<String, dynamic>? _activeBadge;
  Map<String, dynamic>? _nextTier;
  double _progressInCurrentTier = 0;

  final Color primaryPurple = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchTierProgress(showLoading: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchTierProgress(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchTierProgress(showLoading: false);
    }
  }

  Future<void> _fetchTierProgress({bool showLoading = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/badges/tiers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        ApiHelper.showSessionExpiredModal();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = data['data'];
          if (mounted) {
            setState(() {
              _currentXp = payload['current_xp'] ?? 0;
              _tiers = payload['tiers'] ?? [];
              _activeBadge = payload['active_badge'];
              _nextTier = payload['next_tier'];
              _progressInCurrentTier = (payload['progress_in_current_tier'] ?? 0).toDouble();
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return primaryPurple;
  }

  int _currentTierIndex() {
    for (var i = 0; i < _tiers.length; i++) {
      if (_tiers[i]['is_current'] == true) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final activeName = _activeBadge?['name'] ?? 'Belum ada tier';
    final activeColor = _hexToColor(_activeBadge?['color']?.toString() ?? '#5D44F8');
    final currentIndex = _currentTierIndex();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tier Badge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSummaryCard(activeName, activeColor),
                const SizedBox(height: 24),
                _buildTimeline(currentIndex, activeColor),
                const SizedBox(height: 24),
                const Text('Semua Tier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._tiers.map((tier) => _buildTierCard(tier)),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String activeName, Color activeColor) {
    final nextName = _nextTier?['name'];
    final nextMinXp = _nextTier?['min_xp'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [activeColor, activeColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tier Saat Ini', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(activeName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_currentXp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              if (nextName != null && nextMinXp != null)
                Flexible(
                  child: Text(
                    'Menuju $nextName · $nextMinXp XP',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progressInCurrentTier.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(int currentIndex, Color activeColor) {
    if (_tiers.isEmpty) {
      return const Center(child: Text('Belum ada tier badge yang dikonfigurasi.', style: TextStyle(color: Colors.grey)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 20),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tiers.length,
              itemBuilder: (context, index) {
                final tier = _tiers[index];
                final isUnlocked = tier['is_unlocked'] == true;
                final isCurrent = tier['is_current'] == true;
                final color = _hexToColor(tier['color']?.toString() ?? '#5D44F8');
                final isLast = index == _tiers.length - 1;

                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: isCurrent ? 52 : 42,
                          height: isCurrent ? 52 : 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked ? color.withOpacity(0.15) : Colors.grey.shade100,
                            border: Border.all(
                              color: isCurrent ? color : (isUnlocked ? color.withOpacity(0.6) : Colors.grey.shade300),
                              width: isCurrent ? 3 : 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'T${tier['tier']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isCurrent ? 13 : 11,
                                color: isUnlocked ? color : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            tier['name'] ?? 'Tier',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? color : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: index < currentIndex
                              ? activeColor.withOpacity(0.7)
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(dynamic tier) {
    final isUnlocked = tier['is_unlocked'] == true;
    final isCurrent = tier['is_current'] == true;
    final color = _hexToColor(tier['color']?.toString() ?? '#5D44F8');
    final imageUrl = tier['image_url']?.toString();
    final minXp = tier['min_xp'] ?? 0;
    final maxXp = tier['max_xp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? color : Colors.grey.shade200, width: isCurrent ? 2 : 1),
        boxShadow: isCurrent ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: BadgeNetworkImage(
              imageUrl: imageUrl,
              kind: BadgeImageKind.tier,
              width: 56,
              height: 56,
              opacity: isUnlocked ? 1 : 0.35,
              fallbackIcon: Icons.shield,
              fallbackIconColor: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Tier ${tier['tier']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text('Saat ini', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                      ),
                    ],
                  ],
                ),
                Text(tier['name'] ?? 'Badge', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  maxXp == null ? '$minXp+ XP' : '$minXp - $maxXp XP',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(
            isUnlocked ? Icons.check_circle : Icons.lock_outline,
            color: isUnlocked ? Colors.green : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

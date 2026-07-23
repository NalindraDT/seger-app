import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/helpers/api_helper.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;

  final Color primaryPurple = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/points/history?page=$_currentPage&limit=15'),
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
          setState(() {
            _items = data['data']['items'] ?? [];
            _currentPage = data['data']['pagination']?['page'] ?? 1;
            _totalPages = data['data']['pagination']?['totalPages'] ?? 1;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error points history: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Riwayat Poin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryPurple))
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              color: primaryPurple,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Belum ada riwayat poin.', style: TextStyle(color: Colors.grey))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length + (_totalPages > 1 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _currentPage > 1
                                      ? () {
                                          setState(() => _currentPage--);
                                          _fetchHistory();
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('$_currentPage / $_totalPages'),
                                IconButton(
                                  onPressed: _currentPage < _totalPages
                                      ? () {
                                          setState(() => _currentPage++);
                                          _fetchHistory();
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          );
                        }

                        final item = _items[index];
                        final type = (item['type'] ?? '').toString().toUpperCase();
                        final isEarn = type == 'EARN';
                        final points = item['points'] ?? 0;

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
                                  color: (isEarn ? Colors.green : Colors.red).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                  color: isEarn ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['source']?.toString() ?? (isEarn ? 'Dapat Poin' : 'Tukar Poin'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _formatDate(item['date']?.toString()),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      'Saldo: ${item['balance_after'] ?? '-'}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isEarn ? '+' : '-'}$points',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isEarn ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

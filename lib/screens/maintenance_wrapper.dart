import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pltuapp/helpers/api_helper.dart';

class MaintenanceWrapper extends StatefulWidget {
  final Widget child;

  const MaintenanceWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<MaintenanceWrapper> createState() => _MaintenanceWrapperState();
}

class _MaintenanceWrapperState extends State<MaintenanceWrapper> with WidgetsBindingObserver {
  bool _isMaintenance = false;
  bool _isChecking = true;

  final Color primaryPurple = const Color(0xFF5D44F8);

  @override
  void initState() {
    super.initState();
    print("🚀 [CCTV 1] initState JALAN! Mengaktifkan observer...");
    WidgetsBinding.instance.addObserver(this);
    _checkMaintenanceStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("🔄 [CCTV LIFECYCLE] Status aplikasi berubah menjadi: $state");
    if (state == AppLifecycleState.resumed) {
      _checkMaintenanceStatus();
    }
  }

  Future<void> _checkMaintenanceStatus() async {
    print("🌐 [CCTV 2] Memulai _checkMaintenanceStatus()...");

    try {
      print("⏳ [CCTV 3] Menembak API Maintenance...");

      // Tambahkan timeout 10 detik agar tidak nge-hang jika emulator no internet
      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/settings/maintenance'),
      ).timeout(const Duration(seconds: 10));

      print("✅ [CCTV 4] API Menjawab! Status Code: ${response.statusCode}");
      print("📄 [CCTV 5] Body Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final isMaint = data['data']['is_maintenance'] ?? false;

          print("🛑 [CCTV 6] Nilai is_maintenance dari API = $isMaint");

          if (mounted) {
            setState(() {
              _isMaintenance = isMaint;
              _isChecking = false;
            });
            print("🎨 [CCTV 7] Layar di-refresh dengan isMaintenance = $_isMaintenance");
          }
        }
      } else {
        print("⚠️ [CCTV ERROR] API Status bukan 200");
        if (mounted) setState(() => _isChecking = false);
      }
    } catch (e) {
      print("❌ [CCTV FATAL ERROR] Terjadi kesalahan: $e");
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking && _isMaintenance == false) {
      return Container(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator(color: primaryPurple)),
      );
    }

    if (_isMaintenance) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings_suggest, size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Sistem Sedang\nDalam Pemeliharaan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kami sedang melakukan peningkatan sistem untuk memberikan pengalaman terbaik. Mohon kembali beberapa saat lagi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isChecking = true);
                    _checkMaintenanceStatus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation_service.dart';

class ApiHelper {
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Tutup modal terlebih dahulu
    Navigator.pop(NavigationService.navigatorKey.currentContext!);

    // Pindah ke halaman Login dan hapus semua history
    NavigationService.pushNamedAndRemoveUntil('/');
  }

  static void showSessionExpiredModal() {
    showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sesi Berakhir'),
        content: const Text('Sesi Anda telah habis. Silakan login kembali.'),
        actions: [
          ElevatedButton(
            onPressed: () => logout(), // Panggil fungsi logout di atas
            child: const Text('Login Kembali'),
          ),
        ],
      ),
    );
  }
}
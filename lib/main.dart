import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/dashboard_screen.dart';
import 'screens/maintenance_wrapper.dart';
import 'screens/splash_screen.dart'; // --- IMPORT SPLASH SCREEN BARU ---
import 'helpers/navigation_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'SEGER App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF5D44F8),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        return MaintenanceWrapper(child: child!);
      },

      // --- MULAI APLIKASI DARI SPLASH SCREEN ---
      home: const SplashScreen(),

      // --- DAFTARKAN RUTE UNTUK NAVIGASI DARI SPLASH SCREEN ---
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
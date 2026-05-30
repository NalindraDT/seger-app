import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi Animasi Lingkaran Berdenyut (Pulsing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Durasi 1 denyutan
    );

    // Animasi skala dari 1.0 (ukuran logo) ke 2.5 kali lipat
    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Buat animasi berulang (looping)
    _pulseController.repeat(reverse: false);

    // 2. Timer untuk Menampilkan Splash Selama 3 Detik
    Timer(const Duration(seconds: 3), () {
      _checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose(); // Bersihkan controller animasi
    super.dispose();
  }

  // Fungsi untuk Mengecek Status Login User
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // User SUDAH Login -> Masuk ke Dashboard
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } else {
      // User BELUM Login -> Masuk ke Halaman Login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Warna tema logo kuning-hijau PLN (Dipakai untuk lingkaran pulsing)
    const Color logoYellowGreen = Color(0xFFCCFF00);

    return Scaffold(
      body: Container(
        // --- BACKGROUND GRADASI UNGU KE BIRU TUA ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5D44F8), // Ungu utama
              Color(0xFF3F2B9C), // Biru-ungu tua
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(), // Dorong konten tengah ke bawah

              // --- BAGIAN TENGAH: LOGO & TAKARIR ---
              Center(
                child: Column(
                  children: [
                    // --- PERBAIKAN: BUNGKUS DENGAN SIZEDBOX FIX ---
                    // Ini yang membuat animasi tidak mendorong teks di bawahnya
                    SizedBox(
                      width: 320,
                      height: 320,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Lingkaran Berdenyut (di belakang logo)
                          _buildPulsingCircles(_pulseAnimation, logoYellowGreen),

                          // MENGGUNAKAN GAMBAR logo_seger.png
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: SizedBox(
                                width: 200,
                                height: 200,
                                child: Image.asset(
                                  'assets/images/logo_seger.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white30, size: 50),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ------------------------------------------------

                    // Nama Aplikasi (Bold)
                    const Text(
                      'SEGER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Takarir (Regular)
                    const Text(
                      'Active Today, Stronger Tomorrow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(), // Dorong konten tengah ke atas

              // --- BAGIAN BAWAH: POWERED BY ---
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Text(
                      'POWERED BY KOMBALA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'PLN INDONESIA POWER UBP JAWA TENGAH 2 ADIPALA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ALPHA BUILD V1.0',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET LINGKARAN BERDENYUT (PULSING) ---
  Widget _buildPulsingCircles(Animation<double> animation, Color color) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Lingkaran Luar (Paling Besar & Pudar)
            _buildCircle(animation.value * 1.6, color.withOpacity(0.08)),

            // Lingkaran Tengah
            _buildCircle(animation.value * 1.3, color.withOpacity(0.12)),

            // Lingkaran Dalam (Paling Kecil & Terang)
            _buildCircle(animation.value, color.withOpacity(0.18)),
          ],
        );
      },
    );
  }

  // Helper untuk membuat 1 lingkaran animasi
  Widget _buildCircle(double radiusScale, Color color) {
    const double baseRadius = 100.0; // Ukuran lingkaran awal

    return Container(
      width: baseRadius * radiusScale,
      height: baseRadius * radiusScale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color.withOpacity(0.5), width: 2.0),
      ),
    );
  }
}
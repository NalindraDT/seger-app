import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pltuapp/screens/user/dashboard_screen.dart';
import 'package:pltuapp/screens/auth/forgot_password_screen.dart';
import 'package:pltuapp/screens/auth/register_screen.dart';
import 'package:pltuapp/helpers/api_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Variabel untuk menampung pesan error atau sukses
  String? _notificationMessage;
  bool _isErrorNotification = true; // true = merah (error), false = hijau (sukses)
  Timer? _notificationTimer;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);
  final Color bgColor = const Color(0xFFF8F9FA);
  final Color black = const Color(0xFF000000);

  // Fungsi khusus untuk memunculkan notifikasi di atas layar
  void _showTopNotification(String message, {bool isError = true}) {
    setState(() {
      _notificationMessage = message;
      _isErrorNotification = isError;
    });

    _notificationTimer?.cancel();

    _notificationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _notificationMessage = null;
        });
      }
    });
  }

  Future<void> _handleLogin() async {
    // 1. Sembunyikan notifikasi sebelumnya
    setState(() => _notificationMessage = null);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showTopNotification('Email dan Password tidak boleh kosong!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiHelper.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final data = responseData['data'];
        final user = data['user'];
        final String role = user['role'] ?? '';

        if (role == 'participant') {
          // 2. Simpan Data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('userId', user['id']);
          await prefs.setString('role', role);
          await prefs.setInt('points', user['pointsBalance']);
          await prefs.setInt('exp', user['xpBalance']);

          // 3. Tampilkan Notifikasi Sukses (Warna Hijau)
          _showTopNotification('Login Berhasil!', isError: false);

          // 4. Beri jeda 1 detik agar user bisa membaca tulisan "Login Berhasil"
          await Future.delayed(const Duration(seconds: 1));

          // 5. Pindah ke Halaman Dashboard
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          _showTopNotification('email/password salah', isError: true);
        }
      } else {
        _showTopNotification('email/password salah', isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 24.0, top: 16.0),
          child: Text(
            '',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
                // 1. Background Image PLTU dengan Overlay Ungu Transparan
                Container(
                  height: size.height * 0.45,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                    ),
                    image: DecorationImage(
                      image: const AssetImage('assets/images/pltu.jpeg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        black.withOpacity(0.2),
                        BlendMode.srcOver,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- BAGIAN YANG DIUBAH: Menggabungkan Teks dan Logo ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/logo_seger.png',
                                height: 50, // Sedikit diperbesar agar proporsional dengan 2 baris teks
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8), // Jarak antara logo dan teks
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end, // Membuat tulisan sejajar di sebelah kanan
                                mainAxisSize: MainAxisSize.min, // Agar tinggi column menyesuaikan isinya
                                children: [
                                  const Text(
                                    'SEGER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      height: 1.0, // Mengurangi jarak kosong (spasi) ke teks di bawahnya
                                    ),
                                  ),
                                  const Text(
                                    'by KOMBALA',
                                    style: TextStyle(
                                      color: Color(0xFFCCFF00), // Kode warna hijau muda (lime) mirip logo
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // -------------------------------------------------------
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Card Form Login
                Container(
                  margin: EdgeInsets.only(
                    top: size.height * 0.35,
                    left: 24,
                    right: 24,
                    bottom: 20,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Selamat Datang',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Masuk untuk memulai',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Email',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your credentials',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryPurple),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: '........',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryPurple),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Lupa Password?',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  final result = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                  );
                                  if (result != null && mounted) {
                                    _showTopNotification(result, isError: false);
                                  }
                                },
                          child: const Text(
                            'Belum punya akun? Daftar',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Notifikasi Mengambang di Atas (Bisa Merah/Error atau Hijau/Sukses)
          if (_notificationMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              child: AnimatedOpacity(
                opacity: _notificationMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isErrorNotification ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isErrorNotification ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isErrorNotification
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isErrorNotification ? Icons.error_outline : Icons.check_circle_outline,
                          color: _isErrorNotification ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _notificationMessage!,
                            style: TextStyle(
                              color: _isErrorNotification ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _notificationMessage = null);
                            _notificationTimer?.cancel();
                          },
                          child: Icon(
                            Icons.close,
                            color: _isErrorNotification ? Colors.red : Colors.green,
                            size: 20,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }
}
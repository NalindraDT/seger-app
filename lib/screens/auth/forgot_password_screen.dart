import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Kontrol Langkah UI (1 = Input Email, 2 = Input OTP & Password Baru)
  int _step = 1;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Notifikasi Mengambang
  String? _notificationMessage;
  bool _isErrorNotification = true;
  Timer? _notificationTimer;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);
  final Color bgColor = const Color(0xFFF8F9FA);

  void _showTopNotification(String message, {bool isError = true}) {
    setState(() {
      _notificationMessage = message;
      _isErrorNotification = isError;
    });
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notificationMessage = null);
    });
  }

  // --- API 1: MINTA OTP ---
  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      _showTopNotification('Email tidak boleh kosong!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showTopNotification('OTP berhasil dikirim ke email Anda!', isError: false);
        setState(() => _step = 2); // Pindah ke UI Langkah 2
      } else {
        _showTopNotification(responseData['message'] ?? 'Email tidak ditemukan.', isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API 2: RESET PASSWORD ---
  Future<void> _resetPassword() async {
    if (_otpController.text.isEmpty || _passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showTopNotification('Semua kolom wajib diisi!', isError: true);
      return;
    }

    // --- TAMBAHAN VALIDASI: Minimal 8 Karakter ---
    if (_passwordController.text.length < 8) {
      _showTopNotification('Password baru minimal 8 karakter!', isError: true);
      return;
    }

    // Pengecekan kecocokan password di sisi Frontend
    if (_passwordController.text != _confirmPasswordController.text) {
      _showTopNotification('Konfirmasi password tidak cocok!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text, // Tetap kirim email dari langkah 1
          'otp': _otpController.text,
          'new_password': _passwordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showTopNotification('Password berhasil direset! Silakan Login.', isError: false);

        // Beri jeda 2 detik agar user membaca pesan sukses, lalu kembali ke layar Login
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      } else {
        // --- PERBAIKAN: Tangkap pesan error spesifik dari Backend ---
        String errorMessage = 'OTP salah atau kedaluwarsa.';

        if (responseData['error'] != null && responseData['error']['message'] != null) {
          errorMessage = responseData['error']['message'];

          // Jika backend mengirimkan detail error per kolom, bisa kita tangkap juga
          if (responseData['error']['details'] != null && responseData['error']['details']['fieldErrors'] != null) {
            Map<String, dynamic> fieldErrors = responseData['error']['details']['fieldErrors'];
            if (fieldErrors.isNotEmpty) {
              // Mengambil pesan error pertama dari list pesan error
              errorMessage = fieldErrors.values.first[0].toString();
            }
          }
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }

        _showTopNotification(errorMessage, isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reset Password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Masukkan email yang terdaftar untuk menerima kode OTP.'
                      : 'Masukkan kode OTP yang dikirim ke email Anda beserta password baru.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 32),

                // =============================================================
                // UI LANGKAH 1: INPUT EMAIL
                // =============================================================
                if (_step == 1) ...[
                  const Text('Email Terdaftar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputStyle('Masukkan email Anda', Icons.email_outlined),
                  ),
                  const SizedBox(height: 32),
                  _buildPrimaryButton(
                      label: 'Kirim Kode OTP',
                      onPressed: _sendOtp,
                      isLoading: _isLoading
                  ),
                ],

                // =============================================================
                // UI LANGKAH 2: INPUT OTP & NEW PASSWORD
                // =============================================================
                if (_step == 2) ...[
                  const Text('Kode OTP (6 Digit)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _inputStyle('Contoh: 167049', Icons.password).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 20),

                  const Text('Password Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: _inputStyle('Masukkan password baru', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Konfirmasi Password Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: _inputStyle('Ketik ulang password baru', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPrimaryButton(
                      label: 'Simpan Password Baru',
                      onPressed: _resetPassword,
                      isLoading: _isLoading
                  ),
                ],
              ],
            ),
          ),

          // --- NOTIFIKASI MENGAMBANG ---
          if (_notificationMessage != null)
            Positioned(
              top: 16, left: 24, right: 24,
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
                      border: Border.all(color: _isErrorNotification ? Colors.red.shade200 : Colors.green.shade200),
                      boxShadow: [BoxShadow(color: _isErrorNotification ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Icon(_isErrorNotification ? Icons.error_outline : Icons.check_circle_outline, color: _isErrorNotification ? Colors.red : Colors.green),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_notificationMessage!, style: TextStyle(color: _isErrorNotification ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 14))),
                        GestureDetector(
                          onTap: () {
                            setState(() => _notificationMessage = null);
                            _notificationTimer?.cancel();
                          },
                          child: Icon(Icons.close, color: _isErrorNotification ? Colors.red : Colors.green, size: 20),
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

  // --- WIDGET HELPER ---
  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryPurple)),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed, required bool isLoading}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: primaryPink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
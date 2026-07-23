import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pltuapp/helpers/api_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isLoadingDepartments = true;
  bool _isLoadingCompanies = true;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _companies = [];
  String? _selectedDepartmentId;
  String? _selectedCompanyId;

  String? _notificationMessage;
  bool _isErrorNotification = true;
  Timer? _notificationTimer;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color primaryPink = const Color(0xFFE9005C);
  final Color bgColor = const Color(0xFFF8F9FA);
  final Color black = const Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _fetchDepartments() async {
    setState(() => _isLoadingDepartments = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/departments?page=1&limit=10'),
        headers: {'Content-Type': 'application/json'},
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final items = (responseData['data']['items'] as List)
            .where((item) => item['is_active'] == true)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        setState(() {
          _departments = items;
          if (items.length == 1) {
            _selectedDepartmentId = items.first['id']?.toString();
          }
        });
      } else {
        _showTopNotification('Gagal memuat data departemen.', isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoadingCompanies = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/companies?page=1&limit=100'),
        headers: {'Content-Type': 'application/json'},
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final items = (responseData['data']['items'] as List)
            .where((item) => item['is_active'] == true)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        setState(() {
          _companies = items;
          if (items.length == 1) {
            _selectedCompanyId = items.first['id']?.toString();
          }
        });
      } else {
        _showTopNotification('Gagal memuat data perusahaan.', isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingCompanies = false);
    }
  }

  String _extractErrorMessage(Map<String, dynamic> responseData) {
    if (responseData['error'] != null && responseData['error']['message'] != null) {
      return responseData['error']['message'].toString();
    }
    if (responseData['message'] != null) {
      return responseData['message'].toString();
    }
    return 'Registrasi gagal. Silakan coba lagi.';
  }

  Future<void> _handleRegister() async {
    setState(() => _notificationMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      _showTopNotification('Departemen wajib dipilih!', isError: true);
      return;
    }

    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      _showTopNotification('Perusahaan wajib dipilih!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiHelper.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _fullNameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'department_id': _selectedDepartmentId,
          'company_id': _selectedCompanyId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          if (!mounted) return;
          Navigator.pop(context, 'Registrasi berhasil! Silakan login.');
          return;
        }
      }

      _showTopNotification(_extractErrorMessage(responseData), isError: true);
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryPurple),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
                Container(
                  height: size.height * 0.32,
                  width: double.infinity,
                  decoration: BoxDecoration(
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tombol Back tetap dipertahankan
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          Image.asset(
                            'assets/images/logo_seger.png',
                            height: 45, // Diperbesar sedikit dari 36 agar proporsional dengan 2 baris teks
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end, // Rata kanan
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'SEGER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24, // Mengikuti ukuran font asli di halaman register
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1.0, // Memangkas jarak kosong vertikal
                                ),
                              ),
                              const Text(
                                'by KOMBALA',
                                style: TextStyle(
                                  color: Color(0xFFCCFF00), // Warna hijau lime/neon
                                  fontSize: 10, // Dibuat ukuran 12 agar proporsional dengan font SEGER yang berukuran 24
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  margin: EdgeInsets.only(
                    top: size.height * 0.22,
                    left: 24,
                    right: 24,
                    bottom: 32,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Daftar Akun',
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
                            'Buat akun pegawai PLN',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text('Nama Lengkap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration('Masukkan nama lengkap', prefixIcon: Icons.person_outline),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        const Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Masukkan email', prefixIcon: Icons.badge_outlined),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                            if (!v.contains('@')) return 'Format email tidak valid';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        const Text('Nomor HP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Contoh: 081234567890', prefixIcon: Icons.phone_outlined),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nomor HP wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        const Text('Departemen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _isLoadingDepartments
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(),
                              ))
                            : _departments.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('Data departemen tidak tersedia', style: TextStyle(color: Colors.grey.shade600))),
                                        TextButton(onPressed: _fetchDepartments, child: const Text('Muat ulang')),
                                      ],
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedDepartmentId,
                                    decoration: _inputDecoration('Pilih departemen', prefixIcon: Icons.business_outlined),
                                    items: _departments.map((dept) {
                                      return DropdownMenuItem<String>(
                                        value: dept['id']?.toString(),
                                        child: Text(dept['name']?.toString() ?? '-'),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _selectedDepartmentId = value),
                                    validator: (v) => v == null || v.isEmpty ? 'Departemen wajib dipilih' : null,
                                  ),
                        const SizedBox(height: 16),

                        const Text('Perusahaan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _isLoadingCompanies
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(),
                              ))
                            : _companies.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('Data perusahaan tidak tersedia', style: TextStyle(color: Colors.grey.shade600))),
                                        TextButton(onPressed: _fetchCompanies, child: const Text('Muat ulang')),
                                      ],
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedCompanyId,
                                    decoration: _inputDecoration('Pilih perusahaan', prefixIcon: Icons.apartment_outlined),
                                    items: _companies.map((company) {
                                      return DropdownMenuItem<String>(
                                        value: company['id']?.toString(),
                                        child: Text(company['name']?.toString() ?? '-'),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _selectedCompanyId = value),
                                    validator: (v) => v == null || v.isEmpty ? 'Perusahaan wajib dipilih' : null,
                                  ),
                        const SizedBox(height: 16),

                        const Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: _inputDecoration('Minimal 8 karakter', prefixIcon: Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password wajib diisi';
                            if (v.length < 8) return 'Password minimal 8 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        const Text('Konfirmasi Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: _inputDecoration('Ketik ulang password', prefixIcon: Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                            if (v != _passwordController.text) return 'Password tidak cocok';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _isLoadingDepartments || _isLoadingCompanies) ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Daftar',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Sudah punya akun? Masuk',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_notificationMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

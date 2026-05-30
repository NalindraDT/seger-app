import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  // Data User
  String _fullName = 'User PLN';
  String _email = '-';
  String _phoneNumber = '-';
  String? _profilePhotoUrl;

  // Statistik
  int _points = 0;
  int _exp = 0;
  int _totalActivities = 0;
  int _streakDays = 0;

  // Badge
  Map<String, dynamic>? _activeLevelBadge;
  Map<String, dynamic>? _streakBadge;

  // --- VARIABEL NOTIFIKASI ---
  String? _notificationMessage;
  bool _isErrorNotification = true;
  Timer? _notificationTimer;

  final Color primaryPurple = const Color(0xFF5D44F8);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return primaryPurple;
    }
  }

  // ===========================================================================
  // FUNGSI NOTIFIKASI FLOATING & PENGECEKAN SESI (401)
  // ===========================================================================

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

  // Helper untuk mengecek status 401 secara ringkas di Profile
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false; // Token kedaluwarsa, hentikan proses
    }
    return true; // Token aman, lanjut
  }

  // ===========================================================================
  // API CALLS (FETCH, UPDATE PROFILE, UPDATE PHOTO)
  // ===========================================================================

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 1. Fetch Profile Data
      final profileRes = await http.get(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/users/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(profileRes.statusCode)) {
        setState(() => _isLoading = false);
        return;
      }

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body)['data'];
        _fullName = data['fullName'] ?? 'User PLN';
        _email = data['email'] ?? '-';
        _phoneNumber = data['phoneNumber'] ?? '-';
        _profilePhotoUrl = data['profilePhotoUrl'];
        _points = data['pointsBalance'] ?? 0;
        _exp = data['xpBalance'] ?? 0;
      }

      // 2. Fetch Total Activities
      final historyRes = await http.get(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/activities/history?page=1&limit=1'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(historyRes.statusCode)) return;

      if (historyRes.statusCode == 200) {
        final data = jsonDecode(historyRes.body);
        _totalActivities = data['data']['pagination']['totalItems'] ?? 0;
      }

      // 3. Fetch Badges
      final badgesRes = await http.get(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/badges/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(badgesRes.statusCode)) return;

      if (badgesRes.statusCode == 200) {
        final data = jsonDecode(badgesRes.body);
        if (data['data'] != null) {
          _activeLevelBadge = data['data']['active_badge'];
        }
      }

      // 4. Fetch Streak Data
      final streakRes = await http.get(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/streak/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!_checkAuth(streakRes.statusCode)) return;

      if (streakRes.statusCode == 200) {
        final data = jsonDecode(streakRes.body);
        if (data['data'] != null) {
          _streakDays = data['data']['current_streak_days'] ?? 0;
          _streakBadge = data['data']['badge'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfileInfo(String name, String phone) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.patch(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "full_name": name,
          "phone_number": phone,
        }),
      );

      Navigator.pop(context); // Tutup dialog loading
      if (!_checkAuth(response.statusCode)) return; // Cek auth setelah loading ditutup

      if (response.statusCode == 200) {
        _showTopNotification('Profil berhasil diperbarui!', isError: false);
        _fetchProfileData();
      } else {
        debugPrint("Error Update Profile: ${response.body}");
        _showTopNotification('Gagal memperbarui profil.', isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    }
  }

  Future<void> _uploadProfilePhoto(File croppedFile) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var uri = Uri.parse('https://pltuapp.potydev.cloud/api/v1/users/profile/photo');
      var request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      String extension = croppedFile.path.split('.').last.toLowerCase();
      String mimeSubtype = 'jpeg';

      if (extension == 'png') {
        mimeSubtype = 'png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeSubtype = 'jpeg';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        croppedFile.path,
        contentType: MediaType('image', mimeSubtype),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Tutup loading
      if (!_checkAuth(response.statusCode)) return; // Cek auth setelah loading ditutup

      if (response.statusCode == 200) {
        _showTopNotification('Foto profil berhasil diubah!', isError: false);
        _fetchProfileData();
      } else {
        debugPrint("Error Photo: ${response.body}");
        _showTopNotification('Gagal mengunggah foto.', isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _showTopNotification('Terjadi kesalahan jaringan: $e', isError: true);
    }
  }

  // ===========================================================================
  // IMAGE PICKER & IMAGE CROPPER
  // ===========================================================================

  Future<void> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur Posisi Foto',
          toolbarColor: primaryPurple,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Atur Posisi Foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile != null) {
      _uploadProfilePhoto(File(croppedFile.path));
    }
  }

  // ===========================================================================
  // FITUR UBAH PASSWORD DARI DALAM PROFIL
  // ===========================================================================

  Future<void> _requestPasswordResetOtp() async {
    if (_email == '-' || _email.isEmpty) {
      _showTopNotification('Email tidak tersedia.', isError: true);
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await http.post(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email}),
      );

      Navigator.pop(context); // Tutup dialog loading
      if (!_checkAuth(response.statusCode)) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showTopNotification('Kode OTP dikirim ke $_email', isError: false);
        _showChangePasswordSheet();
      } else {
        _showTopNotification(data['message'] ?? 'Gagal mengirim OTP', isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    }
  }

  Future<void> _submitNewPassword(String otp, String newPassword, BuildContext sheetContext) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await http.post(
        Uri.parse('https://pltuapp.potydev.cloud/api/v1/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email,
          'otp': otp,
          'new_password': newPassword,
        }),
      );

      Navigator.pop(context); // Tutup loading
      if (!_checkAuth(response.statusCode)) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        Navigator.pop(sheetContext); // Tutup Bottom Sheet
        _showTopNotification('Password berhasil diubah!', isError: false);
      } else {
        String errorMessage = 'OTP salah atau kedaluwarsa.';
        if (responseData['error'] != null && responseData['error']['message'] != null) {
          errorMessage = responseData['error']['message'];
          if (responseData['error']['details'] != null && responseData['error']['details']['fieldErrors'] != null) {
            Map<String, dynamic> fieldErrors = responseData['error']['details']['fieldErrors'];
            if (fieldErrors.isNotEmpty) {
              errorMessage = fieldErrors.values.first[0].toString();
            }
          }
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }
        _showTopNotification(errorMessage, isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    }
  }

  void _showChangePasswordSheet() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController otpController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    bool isPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateSheet) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 24, left: 24, right: 24,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ubah Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Kode OTP telah dikirim ke $_email', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 20),

                      const Text('Kode OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: _inputDecoration('Contoh: 167049').copyWith(counterText: ''),
                        validator: (v) => v!.isEmpty ? 'OTP wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      const Text('Password Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: _inputDecoration('Masukkan password baru').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setStateSheet(() => isPasswordVisible = !isPasswordVisible),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 8) return 'Password minimal 8 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Konfirmasi Password Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !isConfirmPasswordVisible,
                        decoration: _inputDecoration('Ketik ulang password baru').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setStateSheet(() => isConfirmPasswordVisible = !isConfirmPasswordVisible),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                          if (v != passwordController.text) return 'Password tidak cocok';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              _submitNewPassword(otpController.text, passwordController.text, sheetContext);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9005C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Simpan Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  // ===========================================================================
  // MODAL EDIT DATA FORM
  // ===========================================================================

  void _showEditProfileSheet() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController(text: _fullName);
    final TextEditingController phoneController = TextEditingController(text: _phoneNumber == '-' ? '' : _phoneNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration('Masukkan nama lengkap'),
                  validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 16),

                const Text('Nomor HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Masukkan nomor HP (misal: 0812345678)'),
                  validator: (v) => v!.isEmpty ? 'Nomor HP wajib diisi' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        _updateProfileInfo(nameController.text, phoneController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryPurple)),
    );
  }

  // ===========================================================================
  // DESIGN UI RENDERING
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('User Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryPurple))
              : RefreshIndicator(
            onRefresh: _fetchProfileData,
            color: primaryPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // --- CARD 1: USER INFO ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryPurple,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _pickAndCropImage,
                              behavior: HitTestBehavior.opaque,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 75, height: 75,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: _profilePhotoUrl != null
                                          ? NetworkImage(_profilePhotoUrl!)
                                          : NetworkImage('https://ui-avatars.com/api/?name=$_fullName&background=ffffff&color=5D44F8') as ImageProvider,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 10),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(_email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(_phoneNumber, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  // --- TAMBAHAN: TOMBOL UBAH PASSWORD ---
                                  GestureDetector(
                                    onTap: _requestPasswordResetOtp,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_reset, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Ubah Password', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0, right: 0,
                          child: GestureDetector(
                            onTap: _showEditProfileSheet,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 2: STATISTIK ---
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(Icons.monetization_on, Colors.amber, '$_points', 'Total Poin'),
                        Container(width: 1, height: 40, color: Colors.grey.shade200),
                        _buildStatColumn(Icons.assignment, Colors.teal, '$_totalActivities', 'Total Aktivitas'),
                        Container(width: 1, height: 40, color: Colors.grey.shade200),
                        _buildStatColumn(Icons.local_fire_department, Colors.orange, '$_streakDays', 'Hari Streak'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 3: LEVEL KAMU ---
                  _buildLevelCard(),
                  const SizedBox(height: 20),

                  // --- CARD 4: STREAK BADGE ---
                  _buildStreakBadgeCard(),

                  const SizedBox(height: 30), // Beri jarak agak jauh

                  // --- TAMBAHAN: TOMBOL LOGOUT ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Tampilkan konfirmasi dialog sebelum logout
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('Apakah Anda yakin ingin keluar dari akun Anda saat ini?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal', style: TextStyle(color: Colors.grey))
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context); // Tutup dialog
                                  await ApiHelper.logout(); // Panggil fungsi logout dari helper
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE9005C),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout, color: Color(0xFFE9005C)),
                      label: const Text('Keluar Akun', style: TextStyle(color: Color(0xFFE9005C), fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE9005C), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80), // Jarak untuk navigasi bawah
                ],
              ),
            ),
          ),

          // --- WIDGET NOTIFIKASI MENGAMBANG ---
          if (_notificationMessage != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
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

  Widget _buildStatColumn(IconData icon, Color iconColor, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildLevelCard() {
    double xpProgress = 0.0;
    String badgeName = 'Level 1';
    String badgeTier = '1';
    Color badgeColor = primaryPurple;
    String xpText = '$_exp XP';
    String? badgeImageUrl;

    if (_activeLevelBadge != null) {
      badgeName = _activeLevelBadge!['name'] ?? 'Level 1';
      badgeTier = (_activeLevelBadge!['tier'] ?? 1).toString();
      badgeColor = _hexToColor(_activeLevelBadge!['color'] ?? '#5D44F8');
      badgeImageUrl = _activeLevelBadge!['image_url'];

      int minXp = _activeLevelBadge!['min_xp'] ?? 0;
      int? maxXp = _activeLevelBadge!['max_xp'];

      if (maxXp == null) {
        xpProgress = 1.0;
        xpText = '$_exp XP (Max Level)';
      } else {
        int xpInCurrentTier = _exp - minXp;
        int tierTotalXp = maxXp - minXp;
        if (xpInCurrentTier < 0) xpInCurrentTier = 0;
        xpProgress = (tierTotalXp > 0) ? (xpInCurrentTier / tierTotalXp) : 0.0;
        xpText = '$_exp / $maxXp XP';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LEVEL KAMU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryPurple)),
                const SizedBox(height: 4),
                Text(badgeName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level $badgeTier', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(xpText, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: xpProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                      minHeight: 8
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          SizedBox(
            width: 70, height: 70,
            child: (badgeImageUrl != null && badgeImageUrl.isNotEmpty)
                ? Image.network(
              badgeImageUrl,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Icon(Icons.shield, color: badgeColor, size: 50),
            )
                : Icon(Icons.shield, color: badgeColor, size: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadgeCard() {
    String? streakImageUrl;
    if (_streakBadge != null) {
      streakImageUrl = _streakBadge!['image'] ?? _streakBadge!['image_url'];
    }

    bool hasStreakBadge = streakImageUrl != null && streakImageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 75, height: 75,
            child: hasStreakBadge
                ? Image.network(
              streakImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Image.asset('assets/images/dotted_hexagon.png', fit: BoxFit.contain),
            )
                : Image.asset(
              'assets/images/dotted_hexagon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    hasStreakBadge ? 'Lencana Diperoleh!' : 'Kejar Streak-mu!',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: hasStreakBadge ? Colors.green : Colors.orange)
                ),
                const SizedBox(height: 4),
                Text(
                    hasStreakBadge ? (_streakBadge!['name'] ?? 'Lencana Streak') : 'Belum ada lencana',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))
                ),
                const SizedBox(height: 4),
                Text(
                    hasStreakBadge
                        ? 'Kamu berhasil mempertahankan konsistensi.'
                        : 'Pertahankan aktivitas beruntunmu untuk membuka lencana khusus!',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
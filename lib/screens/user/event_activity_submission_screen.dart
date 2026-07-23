import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Tambahan untuk Timer Notifikasi
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Tambahan untuk MediaType
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT API HELPER ---
import 'package:pltuapp/helpers/api_helper.dart';

class EventActivitySubmissionScreen extends StatefulWidget {
  final String eventId; // Menerima ID event
  final Color themeColor; // Menerima warna tema event

  const EventActivitySubmissionScreen({
    Key? key,
    required this.eventId,
    required this.themeColor
  }) : super(key: key);

  @override
  State<EventActivitySubmissionScreen> createState() => _EventActivitySubmissionScreenState();
}

class _EventActivitySubmissionScreenState extends State<EventActivitySubmissionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller input text
  final TextEditingController _linkController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  List<dynamic> _allowedActivities = [];

  static const List<Map<String, dynamic>> _defaultInputFields = [
    {'key': 'distance_km', 'label': 'Jarak', 'type': 'number', 'unit': 'km', 'required': true},
    {'key': 'duration_minutes', 'label': 'Durasi', 'type': 'number', 'unit': 'menit', 'required': true},
    {'key': 'duration_seconds', 'label': 'Detik', 'type': 'number', 'unit': 'detik', 'required': false},
  ];

  // Variabel untuk Dropdown Dinamis (Aktivitas)
  List<dynamic> _activityTypes = [];
  bool _isLoadingTypes = true;
  String? _selectedActivityTypeId;

  // Variabel untuk Dropdown (Metode Pencatatan)
  String? _selectedRecordedVia;
  final List<String> _recordedViaOptions = ['Strava', 'Smartwatch'];

  File? _imageFile;
  bool _isLoadingSubmit = false;
  DateTime _selectedActivityDate = DateTime.now();

  // --- VARIABEL NOTIFIKASI MENGAMBANG ---
  String? _notificationMessage;
  bool _isErrorNotification = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _fetchEventAndTypes();
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _linkController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedAllowedConfig {
    if (_selectedActivityTypeId == null) return null;
    for (final item in _allowedActivities) {
      if (item['activity_type_id'].toString() == _selectedActivityTypeId) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedType {
    if (_selectedActivityTypeId == null) return null;
    for (final item in _activityTypes) {
      if (item['id'].toString() == _selectedActivityTypeId) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _activeInputFields {
    final allowedFields = _selectedAllowedConfig?['input_fields'];
    if (allowedFields is List && allowedFields.isNotEmpty) {
      return allowedFields
          .where((field) => field is Map && field['type'] == 'number')
          .map((field) => Map<String, dynamic>.from(field as Map))
          .toList();
    }
    final typeFields = _selectedType?['input_fields'];
    if (typeFields is List && typeFields.isNotEmpty) {
      return typeFields
          .where((field) => field is Map && field['type'] == 'number')
          .map((field) => Map<String, dynamic>.from(field as Map))
          .toList();
    }
    return _defaultInputFields.map((field) => Map<String, dynamic>.from(field)).toList();
  }

  void _syncFieldControllers() {
    final activeKeys = _activeInputFields.map((field) => field['key'].toString()).toSet();
    for (final key in _fieldControllers.keys.toList()) {
      if (!activeKeys.contains(key)) {
        _fieldControllers.remove(key)?.dispose();
      }
    }
    for (final field in _activeInputFields) {
      final key = field['key'].toString();
      _fieldControllers.putIfAbsent(key, () => TextEditingController());
    }
  }

  String _fieldValue(String key, {String fallback = '0'}) {
    return _fieldControllers[key]?.text.trim().isNotEmpty == true
        ? _fieldControllers[key]!.text.trim()
        : fallback;
  }

  bool get _requiresSourceLink {
    return _activeInputFields.any((field) => field['key'] == 'source_link') ||
        _selectedRecordedVia?.toLowerCase() == 'strava';
  }

  Widget? _buildRestrictionHint() {
    final config = _selectedAllowedConfig;
    if (config == null) return null;
    final hints = <String>[];
    if (config['min_distance_km'] != null) hints.add('Min jarak: ${config['min_distance_km']} km');
    if (config['min_duration_minutes'] != null) hints.add('Min durasi: ${config['min_duration_minutes']} menit');
    if (config['min_calories'] != null) hints.add('Min kalori: ${config['min_calories']} kcal');
    if (config['max_submissions_per_day'] != null) hints.add('Max/hari: ${config['max_submissions_per_day']}');
    if (config['max_submissions_total'] != null) hints.add('Max total: ${config['max_submissions_total']}');
    if (hints.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(hints.join(' • '), style: TextStyle(fontSize: 12, color: widget.themeColor)),
    );
  }

  // ===========================================================================
  // FUNGSI NOTIFIKASI FLOATING & PENGECEKAN SESI
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

  // Helper untuk mengecek status 401
  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false; // Token mati
    }
    return true; // Token aman
  }

  Future<void> _fetchEventAndTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final eventResponse = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/events/${widget.eventId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!_checkAuth(eventResponse.statusCode)) {
        setState(() => _isLoadingTypes = false);
        return;
      }

      List<dynamic> allowed = [];
      if (eventResponse.statusCode == 200) {
        final eventData = jsonDecode(eventResponse.body);
        if (eventData['success'] == true) {
          allowed = eventData['data']['allowed_activities'] ?? [];
        }
      }

      final response = await http.get(
        Uri.parse('${ApiHelper.baseUrl}/activities/types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!_checkAuth(response.statusCode)) {
        setState(() => _isLoadingTypes = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final allTypes = data['data'] as List<dynamic>;
          final filtered = allowed.isEmpty
              ? allTypes
              : allTypes.where((type) {
                  return allowed.any((item) => item['activity_type_id'].toString() == type['id'].toString());
                }).toList();

          setState(() {
            _allowedActivities = allowed;
            _activityTypes = filtered;
            _isLoadingTypes = false;
          });
        }
      } else {
        setState(() => _isLoadingTypes = false);
        _showTopNotification('Gagal mengambil daftar aktivitas', isError: true);
      }
    } catch (e) {
      setState(() => _isLoadingTypes = false);
      _showTopNotification('Terjadi kesalahan jaringan: $e', isError: true);
    }
  }

  // --- Fungsi mengambil gambar dari Galeri ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _pickActivityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedActivityDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedActivityDate = picked);
    }
  }

  String _formatActivityDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- Fungsi kirim data ke API (Multipart/Form-Data) ---
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedActivityTypeId == null) {
      _showTopNotification('Pilih jenis aktivitas terlebih dahulu!', isError: true);
      return;
    }

    if (_selectedRecordedVia == null) {
      _showTopNotification('Pilih metode pencatatan terlebih dahulu!', isError: true);
      return;
    }

    if (_imageFile == null) {
      _showTopNotification('Upload bukti foto terlebih dahulu!', isError: true);
      return;
    }

    setState(() => _isLoadingSubmit = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // URL DINAMIS MENGGUNAKAN EVENT ID
      var uri = Uri.parse('${ApiHelper.baseUrl}/events/${widget.eventId}/activities/submit');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      String activityDate = _formatActivityDate(_selectedActivityDate);

      request.fields['activity_type_id'] = _selectedActivityTypeId!;
      request.fields['activity_date'] = activityDate;
      request.fields['distance_km'] = _fieldValue('distance_km', fallback: '0');
      request.fields['duration_minutes'] = _fieldValue('duration_minutes', fallback: '1');
      request.fields['duration_seconds'] = _fieldValue('duration_seconds', fallback: '0');
      for (final key in ['calories', 'steps', 'elevation_m']) {
        final value = _fieldValue(key, fallback: '');
        if (value.isNotEmpty) {
          request.fields[key] = value;
        }
      }
      request.fields['recorded_via'] = _selectedRecordedVia!; // Pakai nilai dropdown
      request.fields['source_link'] = _linkController.text;

      // File dikirim dengan MediaType JPEG agar aman
      request.files.add(await http.MultipartFile.fromPath(
        'proof_photo',
        _imageFile!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // --- CEK SESI 401 SETELAH SUBMIT ---
      if (!_checkAuth(response.statusCode)) {
        if (mounted) setState(() => _isLoadingSubmit = false);
        return;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context); // Kembali ke halaman event
      } else {
        // --- MENANGKAP PESAN ERROR BACKEND ---
        String errorMessage = 'Gagal mengirim data.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['error'] != null) {
            final errorData = responseData['error'];
            if (errorData['details'] != null && errorData['details']['fieldErrors'] != null) {
              Map<String, dynamic> fieldErrors = errorData['details']['fieldErrors'];

              if (fieldErrors.containsKey('source_link')) {
                errorMessage = "Link Strava tidak valid!";
              } else if (fieldErrors.isNotEmpty) {
                errorMessage = fieldErrors.values.first[0].toString();
              }
            } else if (errorData['message'] != null) {
              errorMessage = errorData['message'];
            }
          }
        } catch (_) {
          errorMessage = 'Terjadi kesalahan sistem (Kode: ${response.statusCode})';
        }

        _showTopNotification(errorMessage, isError: true);
      }
    } catch (e) {
      _showTopNotification('Terjadi kesalahan jaringan.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingSubmit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Catat Aktivitas Event', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      // --- BUNGKUS DENGAN STACK UNTUK NOTIFIKASI ---
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dropdown Jenis Aktivitas
                  const Text('Jenis Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _isLoadingTypes
                      ? Center(child: CircularProgressIndicator(color: widget.themeColor))
                      : DropdownButtonFormField<String>(
                    // --- STYLING DROPDOWN BARU ---
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 3,
                    style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: _inputDecoration('Pilih Aktivitas', icon: Icons.directions_run_outlined),
                    // -----------------------------
                    items: _activityTypes.map<DropdownMenuItem<String>>((item) {
                      return DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(item['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedActivityTypeId = val;
                        _syncFieldControllers();
                      });
                    },
                    validator: (value) => value == null ? 'Wajib dipilih' : null,
                  ),
                  const SizedBox(height: 20),

                  // 2. Dropdown Dicatat Dengan
                  const Text('Di catat dengan', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // --- STYLING DROPDOWN BARU ---
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 3,
                    style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: _inputDecoration('Pilih metode pencatatan', icon: Icons.watch_outlined),
                    // -----------------------------
                    items: _recordedViaOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRecordedVia = val;
                      });
                    },
                    validator: (value) => value == null ? 'Wajib dipilih' : null,
                  ),
                  const SizedBox(height: 20),

                  const Text('Tanggal Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickActivityDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _inputDecoration('Pilih tanggal', icon: Icons.calendar_today_outlined),
                      child: Text(
                        '${_selectedActivityDate.day}/${_selectedActivityDate.month}/${_selectedActivityDate.year}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_buildRestrictionHint() != null) _buildRestrictionHint()!,
                  const SizedBox(height: 20),

                  ..._buildDynamicInputFields(),

                  if (_requiresSourceLink) ...[
                    Text(
                      _selectedRecordedVia?.toLowerCase() == 'strava'
                          ? 'Link Strava (Wajib)'
                          : 'Link Sumber (Opsional)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      decoration: _inputDecoration('https://strava.app.link/xxxxxx', icon: Icons.link),
                      validator: (value) {
                        if (_selectedRecordedVia?.toLowerCase() == 'strava' &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Link Strava wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. Upload Bukti Foto
                  const Text('Upload Bukti', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageFile == null
                          ? Column(
                        children: [
                          const Icon(Icons.upload_outlined, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('Upload Foto / Screenshot', style: TextStyle(color: Colors.grey)),
                          Text('Format: JPG, PNG (Max 5MB)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      )
                          : Image.file(_imageFile!, height: 150, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 6. Tombol Submit (Warna dari Tema Event)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoadingSubmit ? null : _submitData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoadingSubmit
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Aktivitas Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
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

  // --- Fungsi Dekorasi Input ---
  List<Widget> _buildDynamicInputFields() {
    if (_selectedActivityTypeId != null && _fieldControllers.isEmpty) {
      _syncFieldControllers();
    }

    final widgets = <Widget>[];
    for (final field in _activeInputFields) {
      final key = field['key'].toString();
      final label = field['label']?.toString() ?? key;
      final unit = field['unit']?.toString();
      final required = field['required'] == true;
      final controller = _fieldControllers[key];

      widgets.add(Text(label, style: const TextStyle(fontWeight: FontWeight.bold)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(TextFormField(
        controller: controller,
        keyboardType: key == 'distance_km'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        decoration: _inputDecoration('0', suffix: unit?.toUpperCase(), icon: Icons.edit_outlined),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Wajib diisi';
          }
          if (key == 'duration_seconds' && value != null && value.isNotEmpty) {
            final parsed = int.tryParse(value);
            if (parsed == null) return 'Harus angka';
            if (parsed < 0 || parsed > 59) return 'Detik harus 0-59';
          }
          return null;
        },
      ));
      widgets.add(const SizedBox(height: 20));
    }

    return widgets;
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade600) : null, // Tambah warna ikon
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.themeColor)), // Outline pakai tema event
    );
  }
}
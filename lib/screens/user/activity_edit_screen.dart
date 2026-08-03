import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pltuapp/helpers/api_helper.dart';
import 'package:pltuapp/helpers/multipart_file_helper.dart';
import 'package:pltuapp/helpers/number_input_helper.dart';
import 'package:pltuapp/widgets/picked_image_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityEditScreen extends StatefulWidget {
  final dynamic activityItem;

  const ActivityEditScreen({super.key, required this.activityItem});

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _linkController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};

  static const List<Map<String, dynamic>> _defaultInputFields = [
    {'key': 'distance_km', 'label': 'Jarak', 'type': 'number', 'unit': 'km', 'required': true},
    {'key': 'duration_minutes', 'label': 'Durasi', 'type': 'number', 'unit': 'menit', 'required': true},
    {'key': 'duration_seconds', 'label': 'Detik', 'type': 'number', 'unit': 'detik', 'required': false},
  ];

  List<dynamic> _activityTypes = [];
  bool _isLoadingTypes = true;
  String? _selectedActivityTypeId;
  String? _selectedRecordedVia;
  final List<String> _recordedViaOptions = ['Strava', 'Smartwatch', 'Manual'];
  XFile? _imageFile;
  bool _isLoadingSubmit = false;
  late DateTime _selectedActivityDate;
  String? _existingPhotoUrl;

  String? _notificationMessage;
  bool _isErrorNotification = true;
  Timer? _notificationTimer;

  final Color primaryPink = const Color(0xFFE9005C);

  @override
  void initState() {
    super.initState();
    final item = widget.activityItem;
    _selectedActivityTypeId = item['activity_type_id']?.toString();
    final recorded = item['recorded_via']?.toString() ?? '';
    if (recorded.isNotEmpty) {
      _selectedRecordedVia = recorded[0].toUpperCase() + recorded.substring(1);
    }
    _linkController.text = item['source_link']?.toString() ?? '';
    _existingPhotoUrl = item['proof_photo']?.toString();
    final dateStr = item['date']?.toString() ?? '';
    _selectedActivityDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    _fetchActivityTypes();
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
    final fields = _selectedType?['input_fields'] ?? widget.activityItem['input_fields'];
    if (fields is List && fields.isNotEmpty) {
      return fields
          .where((field) => field is Map && field['type'] == 'number')
          .map((field) => Map<String, dynamic>.from(field as Map))
          .toList();
    }
    return _defaultInputFields.map((field) => Map<String, dynamic>.from(field)).toList();
  }

  void _syncFieldControllers({bool prefilling = false}) {
    final activeKeys = _activeInputFields.map((field) => field['key'].toString()).toSet();
    for (final key in _fieldControllers.keys.toList()) {
      if (!activeKeys.contains(key)) {
        _fieldControllers.remove(key)?.dispose();
      }
    }
    final submissionData = widget.activityItem['submission_data'];
    for (final field in _activeInputFields) {
      final key = field['key'].toString();
      final controller = _fieldControllers.putIfAbsent(key, () => TextEditingController());
      if (prefilling && controller.text.isEmpty) {
        dynamic value;
        if (submissionData is Map && submissionData[key] != null) {
          value = submissionData[key];
        } else {
          switch (key) {
            case 'distance_km':
              value = widget.activityItem['distance_km'];
              break;
            case 'duration':
            case 'duration_minutes':
              value = widget.activityItem['duration_minutes'];
              break;
            case 'duration_seconds':
              value = widget.activityItem['duration_seconds'];
              break;
          }
        }
        if (value != null) controller.text = value.toString();
      }
    }
  }

  String _fieldValue(String key, {String fallback = '0'}) {
    final raw = _fieldControllers[key]?.text.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return normalizeDecimalInput(raw);
  }

  bool get _requiresSourceLink {
    return _activeInputFields.any((field) => field['key'] == 'source_link') ||
        _selectedRecordedVia?.toLowerCase() == 'strava';
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

  bool _checkAuth(int statusCode) {
    if (statusCode == 401) {
      ApiHelper.showSessionExpiredModal();
      return false;
    }
    return true;
  }

  Future<void> _fetchActivityTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
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
          setState(() {
            _activityTypes = data['data'];
            _isLoadingTypes = false;
            if (_selectedActivityTypeId == null) {
              final typeName = widget.activityItem['type']?.toString();
              for (final item in _activityTypes) {
                if (item['name']?.toString() == typeName) {
                  _selectedActivityTypeId = item['id'].toString();
                  break;
                }
              }
            }
            _syncFieldControllers(prefilling: true);
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _pickActivityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedActivityDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedActivityDate = picked);
  }

  String _formatActivityDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryPink, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  List<Widget> _buildDynamicInputFields() {
    return _activeInputFields.map((field) {
      final key = field['key'].toString();
      final label = field['label']?.toString() ?? key;
      final unit = field['unit']?.toString();
      final required = field['required'] == true;
      _fieldControllers.putIfAbsent(key, () => TextEditingController());
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label${unit != null ? ' ($unit)' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fieldControllers[key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('Masukkan $label'),
              validator: (value) {
                if (required && (value == null || value.trim().isEmpty)) return 'Wajib diisi';
                return null;
              },
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivityTypeId == null) {
      _showTopNotification('Jenis aktivitas tidak ditemukan.', isError: true);
      return;
    }
    if (_selectedRecordedVia == null) {
      _showTopNotification('Pilih metode pencatatan terlebih dahulu!', isError: true);
      return;
    }

    setState(() => _isLoadingSubmit = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final submissionId = widget.activityItem['id']?.toString();
      final uri = Uri.parse('${ApiHelper.baseUrl}/activities/$submissionId');
      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['activity_type_id'] = _selectedActivityTypeId!;
      request.fields['activity_date'] = _formatActivityDate(_selectedActivityDate);
      request.fields['distance_km'] = _fieldValue('distance_km', fallback: '0');
      if (_fieldControllers.containsKey('duration')) {
        request.fields['duration_minutes'] = _fieldValue('duration', fallback: '1');
      } else {
        request.fields['duration_minutes'] = _fieldValue('duration_minutes', fallback: '1');
      }
      request.fields['duration_seconds'] = _fieldValue('duration_seconds', fallback: '0');

      final Map<String, dynamic> submissionData = {};
      for (final field in _activeInputFields) {
        final key = field['key'].toString();
        if (!['distance_km', 'duration_minutes', 'duration_seconds'].contains(key)) {
          final value = _fieldValue(key, fallback: '');
          if (value.isNotEmpty) submissionData[key] = parseLocalizedNumber(value);
        }
      }
      if (submissionData.isNotEmpty) {
        request.fields['submission_data'] = jsonEncode(submissionData);
      }

      request.fields['recorded_via'] = _selectedRecordedVia!.toLowerCase();
      request.fields['source_link'] = _linkController.text;
      if (_imageFile != null) {
        request.files.add(await multipartFileFromXFile('proof_photo', _imageFile!));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (!_checkAuth(response.statusCode)) {
        if (mounted) setState(() => _isLoadingSubmit = false);
        return;
      }

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        String errorMessage = 'Gagal menyimpan perubahan.';
        try {
          final responseData = jsonDecode(response.body);
          errorMessage = responseData['error']?['message']?.toString() ??
              responseData['message']?.toString() ??
              errorMessage;
        } catch (_) {}
        _showTopNotification(errorMessage, isError: true);
      }
    } catch (_) {
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
        title: const Text('Edit Aktivitas', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jenis Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _isLoadingTypes
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedActivityTypeId,
                          decoration: _inputDecoration('Pilih Aktivitas', icon: Icons.directions_run_outlined),
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
                  const Text('Di catat dengan', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedRecordedVia,
                    decoration: _inputDecoration('Pilih metode pencatatan', icon: Icons.watch_outlined),
                    items: _recordedViaOptions
                        .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRecordedVia = val),
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
                  ..._buildDynamicInputFields(),
                  if (_requiresSourceLink) ...[
                    Text(
                      _selectedRecordedVia?.toLowerCase() == 'strava' ? 'Link Strava (Wajib)' : 'Link Sumber (Opsional)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      decoration: _inputDecoration('https://strava.app.link/xxxxxx', icon: Icons.link),
                      validator: (value) {
                        if (_selectedRecordedVia?.toLowerCase() == 'strava' && (value == null || value.trim().isEmpty)) {
                          return 'Link Strava wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Bukti Foto', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: _imageFile != null
                          ? PickedImagePreview(file: _imageFile!, height: 150)
                          : (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(_existingPhotoUrl!, height: 150, fit: BoxFit.cover),
                                )
                              : Column(
                                  children: [
                                    const Icon(Icons.upload_outlined, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text('Ganti Foto / Screenshot', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoadingSubmit ? null : _saveEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoadingSubmit
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_notificationMessage != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isErrorNotification ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isErrorNotification ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Text(
                    _notificationMessage!,
                    style: TextStyle(
                      color: _isErrorNotification ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

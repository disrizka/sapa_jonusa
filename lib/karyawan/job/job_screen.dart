import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF0F4FF);
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kRed = Color(0xFFE53935);

class CsCreateJobScreen extends StatefulWidget {
  const CsCreateJobScreen({super.key});

  @override
  State<CsCreateJobScreen> createState() => _CsCreateJobScreenState();
}

class _CsCreateJobScreenState extends State<CsCreateJobScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  List<TechnicianUser> _technicians = [];
  TechnicianUser? _selectedTech;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  double? _selectedLat;
  double? _selectedLng;
  bool _showMap = false;
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _userName = '';
  String _userRole = '';
  String _userDivision = '';

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _clientCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScreen() async {
    await _loadUserInfo();
    await _loadTechnicians();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userStr = await _storage.read(key: 'user_data');
      if (userStr != null) {
        final data = jsonDecode(userStr) as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] as String? ?? '';
          _userRole = data['role'] as String? ?? '';
          final div = data['division'];
          if (div is Map) {
            _userDivision = div['name'] as String? ?? '';
          } else if (div is String) {
            _userDivision = div;
          }
        });
      }
    } catch (e) {
      debugPrint('Gagal load user info: $e');
    }
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await JobService.getTechnicians();
      setState(() {
        _technicians = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTech == null) {
      _showSnack('Pilih teknisi terlebih dahulu!', _kRed);
      return;
    }
    if (_startDateTime == null || _endDateTime == null) {
      _showSnack('Tentukan waktu mulai dan selesai!', _kRed);
      return;
    }
    if (_endDateTime!.isBefore(_startDateTime!)) {
      _showSnack('Waktu selesai harus setelah waktu mulai!', _kRed);
      return;
    }

    setState(() => _submitting = true);
    try {
      await JobService.createJob(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        technicianId: _selectedTech!.id,
        clientName: _clientCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        startTime: _startDateTime?.toIso8601String(),
        endTime: _endDateTime?.toIso8601String(),
      );
      if (!mounted) return;
      _showSnack('Tugas berhasil dikirim ke ${_selectedTech!.name}!', _kGreen);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Gagal: $e', _kRed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String get _roleLabel {
    if (_userRole == 'kepala') return 'Pimpinan';
    if (_userDivision.toLowerCase().contains('customer service')) {
      return 'Customer Service';
    }
    return _userRole;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startDateTime ?? now)
        : (_endDateTime ??
              (_startDateTime ?? now).add(const Duration(hours: 2)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kPrimary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kPrimary)),
        child: child!,
      ),
    );
    if (time == null) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDateTime = combined;
      } else {
        _endDateTime = combined;
      }
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Pilih waktu';
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String? _estimasiDurasi() {
    if (_startDateTime == null || _endDateTime == null) return null;
    final diff = _endDateTime!.difference(_startDateTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0 && m > 0) return '$h jam $m menit';
    if (h > 0) return '$h jam';
    return '$m menit';
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'SapaJonusa/1.0'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['display_name'] as String? ?? '';
        setState(() => _locationCtrl.text = address);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Buat Tugas Baru',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _error != null
          ? _buildError()
          : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: _loadTechnicians,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buat Tugas — $_roleLabel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Isi detail tugas, klien, lokasi, waktu, dan pilih teknisi.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Judul Tugas ──────────────────────────────────────────────────
            _label('Judul Tugas *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: _inputDecoration(
                hint: 'Contoh: Perbaikan AC Ruang Rapat',
                icon: Icons.work_outline,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Judul tidak boleh kosong'
                  : null,
            ),
            const SizedBox(height: 16),
            _label('Deskripsi Pekerjaan'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: _inputDecoration(
                hint: 'Jelaskan detail pekerjaan yang harus dilakukan...',
                icon: Icons.description_outlined,
              ),
            ),
            const SizedBox(height: 16),
            _sectionHeader('👤 Informasi Klien'),
            const SizedBox(height: 10),
            _label('Nama Klien *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _clientCtrl,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration: _inputDecoration(
                hint: 'Contoh: PT. Maju Bersama / Bapak Ahmad',
                icon: Icons.person_outline,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama klien tidak boleh kosong'
                  : null,
            ),

            const SizedBox(height: 24),
            _sectionHeader('📍 Lokasi Pekerjaan'),
            const SizedBox(height: 10),
            _label('Alamat'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 14, color: _kText),
              decoration:
                  _inputDecoration(
                    hint: 'Ketik alamat atau pilih lewat map...',
                    icon: Icons.location_on_outlined,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map_outlined, color: _kPrimary),
                      onPressed: () => setState(() => _showMap = !_showMap),
                      tooltip: 'Pilih lokasi di peta',
                    ),
                  ),
            ),
            if (_selectedLat != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 14, color: _kGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Lat: ${_selectedLat!.toStringAsFixed(6)}, Lng: ${_selectedLng!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (_showMap) ...[
              const SizedBox(height: 12),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kPrimary.withOpacity(0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          _selectedLat ?? -6.2088,
                          _selectedLng ?? 106.8456,
                        ),
                        initialZoom: 14,
                        onTap: (tapPosition, point) async {
                          setState(() {
                            _selectedLat = point.latitude;
                            _selectedLng = point.longitude;
                          });
                          await _reverseGeocode(
                            point.latitude,
                            point.longitude,
                          );
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.jonusa.sapa',
                        ),
                        if (_selectedLat != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_selectedLat!, _selectedLng!),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: _kRed,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Ketuk peta untuk memilih lokasi',
                          style: TextStyle(
                            fontSize: 11,
                            color: _kText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _sectionHeader('🕐 Waktu Pengerjaan'),
            const SizedBox(height: 10),
            _label('Waktu Mulai *'),
            const SizedBox(height: 6),
            _buildDateTimeButton(
              value: _startDateTime,
              hint: 'Pilih tanggal & jam mulai',
              icon: Icons.play_circle_outline,
              color: _kPrimary,
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _label('Estimasi Selesai *'),
            const SizedBox(height: 6),
            _buildDateTimeButton(
              value: _endDateTime,
              hint: 'Pilih tanggal & jam selesai',
              icon: Icons.stop_circle_outlined,
              color: _kRed,
              onTap: () => _pickDateTime(isStart: false),
            ),
            if (_estimasiDurasi() != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: _kGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Estimasi durasi: ${_estimasiDurasi()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _sectionHeader('🔧 Pilih Teknisi'),
            const SizedBox(height: 10),

            if (_technicians.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tidak ada teknisi tersedia saat ini.',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._technicians.map((tech) => _buildTechnicianTile(tech)),

            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _technicians.isEmpty)
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Kirim Tugas',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPrimary.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _kPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required DateTime? value,
    required String hint,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? color.withOpacity(0.5)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value != null ? color : _kSub, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value != null ? _formatDateTime(value) : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? _kText : _kSub,
                  fontWeight: value != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined, color: _kSub, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianTile(TechnicianUser tech) {
    final isSelected = _selectedTech?.id == tech.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTech = tech),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? _kPrimary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  tech.name.isNotEmpty ? tech.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isSelected ? Colors.white : _kSub,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tech.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? _kPrimary : _kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tech.division,
                    style: const TextStyle(fontSize: 12, color: _kSub),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: _kText,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _kSub, fontSize: 13),
      prefixIcon: Icon(icon, color: _kSub, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

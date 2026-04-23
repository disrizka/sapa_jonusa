import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Color Palette ──────────────────────────────────────────────────────────
const kPrimaryBlue = Color(0xFF1565C0);
const kAccentBlue = Color(0xFF1E88E5);
const kLightBlue = Color(0xFFE3F2FD);
const kDeepBlue = Color(0xFF0D47A1);
const kSkyBlue = Color(0xFF42A5F5);
const kSuccessGreen = Color(0xFF00897B);
const kErrorRed = Color(0xFFE53935);
const kAmber = Color(0xFFF57C00);
// ────────────────────────────────────────────────────────────────────────────

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Office Config ──────────────────────────────────────────────────────────
  double _officeLat = -6.2000;
  double _officeLng = 106.8166;
  double _officeRadius = 50.0;
  String _checkInLimit = "08:00";
  int _tolerance = 0;

  // ── Holiday ────────────────────────────────────────────────────────────────
  bool _isHoliday = false;
  String _holidayName = "";

  // ── Radius Enforcement ────────────────────────────────────────────────────
  bool _isRadiusEnforced = true;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLate = false;
  bool _isInRadius = false;

  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  double? _distanceFromOffice;
  File? _imageFile;

  // ── Computed ───────────────────────────────────────────────────────────────
  bool get _isBlockedByRadius => _isRadiusEnforced && !_isInRadius;

  bool get _willAutoApprove =>
      !_isHoliday && !_isLate && _isRadiusEnforced && _isInRadius;

  bool get _canTakePhoto =>
      !_isHoliday &&
      !_isLate &&
      !_isBlockedByRadius &&
      !_isSubmitting &&
      _currentPosition != null;

  bool get _canSubmit =>
      _imageFile != null &&
      !_isHoliday &&
      !_isLate &&
      !_isBlockedByRadius &&
      !_isSubmitting &&
      _currentPosition != null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── FIX: config & lokasi paralel, loading selesai setelah keduanya done ───
  Future<void> _init() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchOfficeConfig(), _fetchLocation()]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOfficeConfig() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/attendance/config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        if (!mounted) return;
        setState(() {
          _officeLat = double.parse(data['latitude'].toString());
          _officeLng = double.parse(data['longitude'].toString());
          _officeRadius = double.parse(data['radius'].toString());
          _checkInLimit = (data['check_in_time']?.toString() ?? '08:00')
              .split(':')
              .take(2)
              .join(':');
          _tolerance =
              int.tryParse(data['late_tolerance']?.toString() ?? '0') ?? 0;
          _isHoliday = data['is_holiday'] == true;
          _holidayName = data['holiday_name']?.toString() ?? '';
          _isRadiusEnforced = data['radius_enforced'] != false;
        });
        _validateTime();
        if (_currentPosition != null) _validateRadius(_currentPosition!);
      } else if (response.statusCode == 401) {
        await _storage.deleteAll();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
      }
    } catch (e) {
      debugPrint('Error config: $e');
    }
  }

  void _validateTime() {
    final now = DateTime.now();
    final parts = _checkInLimit.split(':');
    if (parts.length < 2) return;
    final limit = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final deadline = limit.add(Duration(minutes: _tolerance));
    if (mounted) setState(() => _isLate = now.isAfter(deadline));
  }

  // ── FIX: tidak set _isLoading sendiri, dihandle oleh _init ───────────────
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS tidak aktif. Silakan aktifkan GPS.';

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) throw 'Izin lokasi ditolak.';
      }
      if (perm == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen.';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _currentPosition = ll);
      _validateRadius(ll);
      _getAddressFromLatLng(ll); // background, tidak perlu await
    } catch (e) {
      if (mounted) _showSnackBar("Gagal mengambil lokasi: $e", isError: true);
    }
  }

  void _validateRadius(LatLng pos) {
    final d = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _officeLat,
      _officeLng,
    );
    if (mounted) {
      setState(() {
        _distanceFromOffice = d;
        _isInRadius = d <= _officeRadius;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submitCheckIn() async {
    setState(() => _isSubmitting = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      var req = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/check-in'),
      );
      req.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      req.fields['latitude'] = _currentPosition!.latitude.toString();
      req.fields['longitude'] = _currentPosition!.longitude.toString();
      req.fields['notes'] = _notesController.text.isEmpty
          ? 'Absen Masuk Mobile'
          : _notesController.text;
      req.files.add(
        await http.MultipartFile.fromPath('photo', _imageFile!.path),
      );

      final res = await req.send();
      final resp = await http.Response.fromStream(res);
      final body = json.decode(resp.body);

      if (!mounted) return;
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        _showSuccessDialog(
          autoApproved: body['auto_approved'] == true,
          message: body['message'] ?? 'Berhasil!',
          reason: body['reason'] ?? '',
        );
      } else {
        _showSnackBar(body['message'] ?? 'Gagal Absen', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Kesalahan koneksi.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  void _moveCamera(LatLng pos) async {
    if (!_controller.isCompleted) return;
    final c = await _controller.future;
    c.animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    try {
      final p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (mounted) {
        setState(
          () => _currentAddress = '${p.first.street}, ${p.first.locality}',
        );
      }
    } catch (_) {}
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? kErrorRed : kSuccessGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessDialog({
    required bool autoApproved,
    required String message,
    required String reason,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: autoApproved
                      ? kSuccessGreen.withOpacity(0.12)
                      : kAmber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  autoApproved
                      ? Icons.verified_rounded
                      : Icons.pending_actions_rounded,
                  color: autoApproved ? kSuccessGreen : kAmber,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: autoApproved
                      ? kSuccessGreen.withOpacity(0.1)
                      : kAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: autoApproved
                        ? kSuccessGreen.withOpacity(0.3)
                        : kAmber.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      autoApproved
                          ? Icons.check_circle
                          : Icons.schedule_rounded,
                      color: autoApproved ? kSuccessGreen : kAmber,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      autoApproved
                          ? 'DISETUJUI OTOMATIS ✓'
                          : 'MENUNGGU PERSETUJUAN ADMIN',
                      style: TextStyle(
                        color: autoApproved ? kSuccessGreen : kAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                ),
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78909C),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      autoApproved
                          ? Icons.info_outline
                          : Icons.admin_panel_settings_outlined,
                      color: kAccentBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        autoApproved
                            ? 'Absensi langsung tercatat disetujui. Cek di halaman Riwayat.'
                            : 'Absensi menunggu persetujuan admin. Cek status di halaman Riwayat.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF546E7A),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kDeepBlue, kAccentBlue],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'OK, Selesai',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Presensi Masuk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kDeepBlue, kAccentBlue],
            ),
          ),
        ),
      ),
      // FIX: Map selalu di background, loading overlay di atasnya
      body: Stack(
        children: [_buildMapBody(), if (_isLoading) _buildLoadingOverlay()],
      ),
    );
  }

  // ── Loading sebagai overlay, bukan replace seluruh body ──────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: kDeepBlue.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(
                  Icons.location_searching,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mendeteksi Lokasi...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mohon tunggu sebentar',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody() {
    // FIX: fallback ke koordinat kantor agar GoogleMap tidak null
    final initialTarget = _currentPosition ?? LatLng(_officeLat, _officeLng);

    return Stack(
      children: [
        GoogleMap(
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 17,
          ),
          onMapCreated: (c) {
            if (!_controller.isCompleted) _controller.complete(c);
            // Pindahkan kamera ke posisi user jika sudah tersedia
            if (_currentPosition != null) {
              c.animateCamera(
                CameraUpdate.newLatLngZoom(_currentPosition!, 17),
              );
            }
          },
          circles: {
            Circle(
              circleId: const CircleId('office'),
              center: LatLng(_officeLat, _officeLng),
              radius: _officeRadius,
              fillColor: _isRadiusEnforced
                  ? kAccentBlue.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.10),
              strokeColor: _isRadiusEnforced ? kAccentBlue : Colors.orange,
              strokeWidth: 2,
            ),
          },
        ),
        if (!_isLoading)
          Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.67,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (!_isRadiusEnforced) ...[
              _buildRadiusOffBanner(),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: kAccentBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _currentAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF546E7A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildStatusCard(),
            const SizedBox(height: 10),
            _buildApprovalBanner(),
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF263238)),
              decoration: InputDecoration(
                hintText: 'Catatan (Opsional)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: kAccentBlue,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFE),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.blue.shade100,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAccentBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildPhotoSection(),
            const SizedBox(height: 18),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusOffBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAmber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kAmber.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: kAmber,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode Bebas Radius',
                  style: TextStyle(
                    color: kAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin menonaktifkan cek radius. Absensi dari mana saja, hasilnya menunggu persetujuan admin.',
                  style: TextStyle(
                    color: kAmber.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBanner() {
    if (_isHoliday || _isLate || _isBlockedByRadius) {
      return const SizedBox.shrink();
    }

    final isAuto = _willAutoApprove;
    final color = isAuto ? kSuccessGreen : kAmber;
    final bgColor = isAuto ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isAuto
                ? Icons.verified_rounded
                : Icons.admin_panel_settings_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuto
                      ? 'Akan Disetujui Otomatis'
                      : 'Akan Masuk Antrian Approval Admin',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAuto
                      ? 'Dalam radius kantor & jam sesuai ✓'
                      : 'Radius nonaktif → absensi menunggu persetujuan admin',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color color;
    IconData icon;
    String text;
    String subtitle;

    if (_isHoliday) {
      color = kErrorRed;
      icon = Icons.event_busy_rounded;
      text = 'Hari Libur: $_holidayName';
      subtitle = 'Tidak perlu absen hari ini';
    } else if (_isLate) {
      color = kErrorRed;
      icon = Icons.timer_off_rounded;
      text = 'Waktu Absen Masuk Ditutup';
      subtitle = 'Batas: $_checkInLimit  •  Toleransi: $_tolerance menit';
    } else if (_isBlockedByRadius) {
      color = kErrorRed;
      icon = Icons.block_rounded;
      text = 'Diluar Radius — Absen Ditolak';
      subtitle =
          'Anda berada ${_distanceFromOffice?.toStringAsFixed(0) ?? '-'}m dari kantor. Batas radius: ${_officeRadius.toStringAsFixed(0)}m';
    } else if (!_isRadiusEnforced && !_isInRadius) {
      color = kAmber;
      icon = Icons.location_off_rounded;
      text = 'Di Luar Radius (Mode Bebas)';
      subtitle = 'Batas: $_checkInLimit  •  Toleransi: $_tolerance menit';
    } else if (!_isRadiusEnforced && _isInRadius) {
      color = kAmber;
      icon = Icons.location_off_rounded;
      text = 'Mode Bebas Radius Aktif';
      subtitle = 'Batas: $_checkInLimit  •  Toleransi: $_tolerance menit';
    } else {
      color = kSuccessGreen;
      icon = Icons.verified_rounded;
      text = 'Lokasi Terverifikasi ✓';
      subtitle = 'Batas: $_checkInLimit  •  Toleransi: $_tolerance menit';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              '${_distanceFromOffice?.toStringAsFixed(0) ?? '-'}m',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _canTakePhoto ? _takePhoto : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: _imageFile != null ? 190 : 64,
        decoration: BoxDecoration(
          color: _imageFile != null ? Colors.black : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null ? kAccentBlue : Colors.blue.shade200,
            width: _imageFile != null ? 2.5 : 1.5,
          ),
          boxShadow: _imageFile != null
              ? [
                  BoxShadow(
                    color: kAccentBlue.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageFile != null
            ? _buildPhotoPreview()
            : _buildPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_imageFile!, fit: BoxFit.cover),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ketuk untuk ganti foto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kSuccessGreen.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'Foto OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kAccentBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: kAccentBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Ambil Foto Selfie',
          style: TextStyle(
            color: kAccentBlue,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    List<Color> colors;
    String label;
    IconData icon;

    if (_isHoliday) {
      colors = [const Color(0xFFB71C1C), const Color(0xFFD32F2F)];
      label = 'HARI LIBUR';
      icon = Icons.event_busy_rounded;
    } else if (_isLate) {
      colors = [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      label = 'WAKTU ABSEN DITUTUP';
      icon = Icons.timer_off_rounded;
    } else if (_isBlockedByRadius) {
      colors = [kErrorRed, const Color(0xFFEF5350)];
      label = 'DILUAR RADIUS — TIDAK BISA ABSEN';
      icon = Icons.block_rounded;
    } else if (_imageFile == null) {
      colors = [const Color(0xFFB0BEC5), const Color(0xFFCFD8DC)];
      label = 'AMBIL FOTO DULU';
      icon = Icons.camera_alt_rounded;
    } else if (_willAutoApprove) {
      colors = [kSuccessGreen, const Color(0xFF00BFA5)];
      label = 'ABSEN MASUK';
      icon = Icons.verified_rounded;
    } else {
      colors = [kDeepBlue, kAccentBlue];
      label = 'KIRIM ABSENSI (PERSETUJUAN)';
      icon = Icons.admin_panel_settings_outlined;
    }

    final bool disabled =
        _isHoliday ||
        _isLate ||
        _isBlockedByRadius ||
        _isSubmitting ||
        _currentPosition == null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: (!disabled && _imageFile != null)
              ? [
                  BoxShadow(
                    color: colors.first.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: (_imageFile != null && !disabled) ? _submitCheckIn : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

const kPrimaryBlue = Color(0xFF1565C0);
const kAccentBlue = Color(0xFF1E88E5);
const kLightBlue = Color(0xFFE3F2FD);
const kDeepBlue = Color(0xFF0D47A1);
const kSkyBlue = Color(0xFF42A5F5);
const kSuccessGreen = Color(0xFF00897B);
const kErrorRed = Color(0xFFE53935);
const kAmber = Color(0xFFF57C00);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _officeLat = -6.2000;
  double _officeLng = 106.8166;
  double _officeRadius = 50.0;
  String _checkOutLimit = "17:00";
  int _tolerance = 0;

  bool _isHoliday = false;
  String _holidayName = "";

  bool _isRadiusEnforced = true;

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isTooEarly = true;
  bool _isInRadius = false;

  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  double? _distanceFromOffice;
  File? _imageFile;

  DateTime get _minAllowedTime {
    final now = DateTime.now();
    final parts = _checkOutLimit.split(':');
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts[0]) ?? 17,
      int.tryParse(parts[1]) ?? 0,
    );
    return target.subtract(Duration(minutes: _tolerance));
  }

  String get _minAllowedTimeStr => DateFormat('HH:mm').format(_minAllowedTime);

  bool get _isBlockedByRadius => _isRadiusEnforced && !_isInRadius;

  bool get _willAutoApprove =>
      !_isHoliday && !_isTooEarly && _isRadiusEnforced && _isInRadius;

  // ── FIX: getter terpisah untuk buka kamera ─────────────────────────────────
  bool get _canTakePhoto =>
      !_isHoliday &&
      !_isTooEarly &&
      !_isBlockedByRadius &&
      !_isSubmitting &&
      _currentPosition != null;

  bool get _canSubmit =>
      _imageFile != null &&
      !_isHoliday &&
      !_isTooEarly &&
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

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await _fetchOfficeConfig();
    await _fetchLocation();
  }

  Future<void> _fetchOfficeConfig() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/attendance/config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      debugPrint('Config Checkout: ${response.body}');
      if (response.statusCode == 200) {
        final data =
            (json.decode(response.body) as Map)['data'] ??
            json.decode(response.body);
        setState(() {
          _officeLat = double.parse(data['latitude'].toString());
          _officeLng = double.parse(data['longitude'].toString());
          _officeRadius = double.parse(data['radius'].toString());
          final rawOut = data['check_out_time']?.toString() ?? '17:00';
          _checkOutLimit = rawOut.split(':').take(2).join(':');
          _tolerance =
              int.tryParse(data['late_tolerance']?.toString() ?? '0') ?? 0;
          _isHoliday = data['is_holiday'] == true;
          _holidayName = data['holiday_name']?.toString() ?? '';
          _isRadiusEnforced = data['radius_enforced'] != false;
        });
        _validateCheckOutTime();
        if (_currentPosition != null) _validateRadius(_currentPosition!);
      }
    } catch (e) {
      debugPrint('Error Config Checkout: $e');
      setState(() => _isLoading = false);
    }
  }

  void _validateCheckOutTime() {
    setState(() => _isTooEarly = DateTime.now().isBefore(_minAllowedTime));
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final position = await _determinePosition();
      final ll = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = ll;
        _isLoading = false;
      });
      _validateRadius(ll);
      _moveCamera(ll);
      _getAddressFromLatLng(ll);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString(), isError: true);
      }
    }
  }

  Future<Position> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw 'GPS tidak aktif.';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw 'Izin lokasi ditolak.';
    }
    if (perm == LocationPermission.deniedForever)
      throw 'Izin lokasi ditolak permanen.';
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _validateRadius(LatLng pos) {
    final d = _haversine(pos.latitude, pos.longitude, _officeLat, _officeLng);
    setState(() {
      _distanceFromOffice = d;
      _isInRadius = d <= _officeRadius;
    });
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    final dLat = (la2 - la1) * pi / 180;
    final dLon = (lo2 - lo1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(la1 * pi / 180) *
            cos(la2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }

  Future<void> _takePhoto() async {
    final p = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    if (p != null) setState(() => _imageFile = File(p.path));
  }

  Future<void> _submitCheckOut() async {
    if (_imageFile == null || _currentPosition == null) {
      _showSnackBar('Foto dan lokasi wajib ada!', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      var req = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/checkout'),
      );
      req.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      req.fields['latitude'] = _currentPosition!.latitude.toString();
      req.fields['longitude'] = _currentPosition!.longitude.toString();
      req.fields['notes'] = _notesController.text.isEmpty
          ? 'Absen Pulang Mobile'
          : _notesController.text;
      req.files.add(
        await http.MultipartFile.fromPath('photo', _imageFile!.path),
      );

      final res = await req.send().timeout(const Duration(seconds: 15));
      final resp = await http.Response.fromStream(res);
      debugPrint('Status: ${resp.statusCode} | Body: ${resp.body}');
      final body = json.decode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted)
          _showSuccessDialog(
            autoApproved: body['auto_approved'] == true,
            message: body['message'] ?? 'Berhasil Pulang!',
            reason: body['reason'] ?? '',
          );
      } else {
        _showSnackBar(body['message'] ?? 'Gagal', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Koneksi Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    try {
      final p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (mounted)
        setState(
          () => _currentAddress = '${p.first.street}, ${p.first.locality}',
        );
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Alamat tidak terdeteksi');
    }
  }

  void _moveCamera(LatLng pos) async {
    (await _controller.future).animateCamera(
      CameraUpdate.newLatLngZoom(pos, 17),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
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
                            ? 'Absensi pulang langsung tercatat. Cek di halaman Riwayat.'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Presensi Pulang',
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
      body: _isLoading ? _buildLoadingScreen() : _buildMapBody(),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDeepBlue, kAccentBlue, kSkyBlue],
        ),
      ),
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
    if (_currentPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text('Gagal mendapatkan koordinat lokasi.'),
          ],
        ),
      );
    }
    return Stack(
      children: [
        GoogleMap(
          myLocationEnabled: true,
          initialCameraPosition: CameraPosition(
            target: _currentPosition!,
            zoom: 17,
          ),
          onMapCreated: (c) => _controller.complete(c),
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
                hintText: 'Keterangan (Opsional)',
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
    if (_isHoliday || _isTooEarly || _isBlockedByRadius)
      return const SizedBox.shrink();

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
    Color mainColor;
    IconData statusIcon;
    String statusText;
    String subtitleText;

    if (_isHoliday) {
      mainColor = kErrorRed;
      statusIcon = Icons.event_busy_rounded;
      statusText = 'Hari Libur: $_holidayName';
      subtitleText = 'Tidak perlu absen hari ini';
    } else if (_isTooEarly) {
      mainColor = kErrorRed;
      statusIcon = Icons.access_time_rounded;
      statusText = 'Belum Waktunya Pulang';
      subtitleText =
          'Jadwal Pulang: $_checkOutLimit  •  Minimal Absen: $_minAllowedTimeStr';
    } else if (_isBlockedByRadius) {
      mainColor = kErrorRed;
      statusIcon = Icons.block_rounded;
      statusText = 'Diluar Radius — Absen Ditolak';
      subtitleText =
          'Anda ${_distanceFromOffice?.toStringAsFixed(0) ?? '-'}m dari kantor. Batas: ${_officeRadius.toStringAsFixed(0)}m';
    } else if (!_isRadiusEnforced && !_isInRadius) {
      mainColor = kAmber;
      statusIcon = Icons.location_off_rounded;
      statusText = 'Di Luar Radius (Mode Bebas)';
      subtitleText =
          'Jadwal Pulang: $_checkOutLimit  •  Minimal Absen: $_minAllowedTimeStr';
    } else if (!_isRadiusEnforced && _isInRadius) {
      mainColor = kAmber;
      statusIcon = Icons.location_off_rounded;
      statusText = 'Mode Bebas Radius Aktif';
      subtitleText =
          'Jadwal Pulang: $_checkOutLimit  •  Minimal Absen: $_minAllowedTimeStr';
    } else {
      mainColor = kSuccessGreen;
      statusIcon = Icons.verified_rounded;
      statusText = 'Lokasi & Waktu Terverifikasi';
      subtitleText =
          'Jadwal Pulang: $_checkOutLimit  •  Minimal Absen: $_minAllowedTimeStr';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mainColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: mainColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: mainColor,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: mainColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${_distanceFromOffice?.toStringAsFixed(0) ?? '-'}m',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: mainColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: mainColor.withOpacity(0.2), height: 20),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: mainColor.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 11,
                    color: mainColor.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
    } else if (_isTooEarly) {
      colors = [const Color(0xFF78909C), const Color(0xFF90A4AE)];
      label = 'BELUM WAKTUNYA PULANG';
      icon = Icons.access_time_rounded;
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
      label = 'ABSEN PULANG';
      icon = Icons.logout_rounded;
    } else {
      colors = [kDeepBlue, kAccentBlue];
      label = 'KIRIM ABSENSI (PERSETUJUAN)';
      icon = Icons.admin_panel_settings_outlined;
    }

    final bool disabled =
        _isHoliday ||
        _isTooEarly ||
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
          onPressed: (_imageFile != null && !disabled) ? _submitCheckOut : null,
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

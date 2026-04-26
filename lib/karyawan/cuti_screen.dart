import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Design Tokens (sama dengan SakitScreen) ───────────────────────
const _primary = Color(0xFF1565C0);
const _primaryTint = Color(0xFFEBF3FF);
const _primaryBorder = Color(0xFFD8E8FF);
const _bg = Color(0xFFF0F5FF);
const _white = Color(0xFFFFFFFF);
const _surface = Color(0xFFF7FAFF);
const _textPrimary = Color(0xFF0D3B7A);
const _textSub = Color(0xFF4A6B9A);
const _textHint = Color(0xFFA0BCDA);
const _border = Color(0xFFD8E8FF);
// ───────────────────────────────────────────────────────────────────

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final _reasonController = TextEditingController();

  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _docFile;
  bool _loading = false;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  final List<_JenisOption> _options = [
    _JenisOption(
      label: "Izin",
      value: "izin",
      icon: Icons.timer_rounded,
      desc: "Izin tidak masuk kerja",
    ),
    _JenisOption(
      label: "Cuti",
      value: "cuti",
      icon: Icons.beach_access_rounded,
      desc: "Cuti tahunan / resmi",
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() => _docFile = File(result.files.single.path!));
    }
  }

  int _countDays() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _sendData() async {
    if (_selectedType == null ||
        _startDate == null ||
        _endDate == null ||
        _reasonController.text.trim().isEmpty) {
      _snack("Lengkapi semua field yang wajib diisi", error: true);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _snack("Tanggal selesai tidak boleh sebelum tanggal mulai", error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${Api.baseUrl}/api/presence/permissions'),
            )
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            })
            ..fields.addAll({
              'type': _selectedType!,
              'category': _selectedType!,
              'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
              'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
              'reason': _reasonController.text,
            });

      if (_docFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath('attachment_file', _docFile!.path),
        );
      }

      final res = await req.send();
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack("Pengajuan berhasil dikirim");
        if (mounted) Navigator.pop(context);
      } else {
        _snack("Gagal mengirim: ${res.statusCode}", error: true);
      }
    } catch (e) {
      _snack("Terjadi kesalahan: $e", error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: _white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: _white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: error ? const Color(0xFFB71C1C) : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        elevation: 0,
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJenisCard(),
                    const SizedBox(height: 14),
                    _buildDateCard(),
                    const SizedBox(height: 14),
                    _buildReasonCard(),
                    const SizedBox(height: 14),
                    _buildAttachmentCard(),
                    const SizedBox(height: 14),
                    _buildInfoNote(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: _white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Absensi & Kehadiran",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Izin / Cuti",
                      style: TextStyle(
                        fontSize: 20,
                        color: _white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: _white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Card Shell ────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeBg,
    Color? badgeText,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _primaryTint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 13, color: _white),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg ?? _primaryBorder,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        color: badgeText ?? _primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  // ─── Jenis Pengajuan Card ──────────────────────────────────────────
  Widget _buildJenisCard() {
    return _buildSectionCard(
      icon: Icons.category_rounded,
      title: "Jenis Pengajuan",
      badge: "Wajib",
      child: Row(
        children: _options.map((opt) {
          final bool sel = _selectedType == opt.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: opt == _options.first ? 10 : 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: sel ? _primaryTint : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? _primary : _border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: sel ? _primary : _primaryBorder,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        opt.icon,
                        size: 16,
                        color: sel ? _white : _textSub,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? _textPrimary : _textSub,
                            ),
                          ),
                          Text(
                            opt.desc,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: _textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (sel)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: _white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Date Card ─────────────────────────────────────────────────────
  Widget _buildDateCard() {
    final int days = _countDays();
    return _buildSectionCard(
      icon: Icons.date_range_rounded,
      title: "Rentang Tanggal",
      badge: days > 0 ? "$days Hari" : null,
      child: Row(
        children: [
          Expanded(
            child: _datePickerTile(
              label: "MULAI",
              date: _startDate,
              onPick: (d) => setState(() => _startDate = d),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _datePickerTile(
              label: "SELESAI",
              date: _endDate,
              onPick: (d) => setState(() => _endDate = d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime? date,
    required Function(DateTime) onPick,
  }) {
    final bool sel = date != null;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: _primary,
                onPrimary: _white,
                surface: _white,
                onSurface: _textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? _primaryTint : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? _primary : _border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: sel ? _primary : _textHint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 11,
                  color: sel ? _primary : _textHint,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    sel ? DateFormat('dd MMM yyyy').format(date!) : "Pilih",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color: sel ? _textPrimary : _textHint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reason Card ───────────────────────────────────────────────────
  Widget _buildReasonCard() {
    return _buildSectionCard(
      icon: Icons.edit_note_rounded,
      title: "Alasan Pengajuan",
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _reasonController,
          maxLines: 4,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 13.5,
            height: 1.55,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(13),
            border: InputBorder.none,
            hintText: "Tuliskan alasan pengajuan Anda...",
            hintStyle: TextStyle(color: _textHint, fontSize: 13.5),
          ),
        ),
      ),
    );
  }

  // ─── Attachment Card ───────────────────────────────────────────────
  Widget _buildAttachmentCard() {
    final bool picked = _docFile != null;
    return _buildSectionCard(
      icon: Icons.attach_file_rounded,
      title: "Lampiran Dokumen",
      badge: "Opsional",
      badgeBg: const Color(0xFFFFF3E0),
      badgeText: const Color(0xFFBF6000),
      child: GestureDetector(
        onTap: _pickDocument,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: picked ? _primaryTint : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: picked ? _primary : _border,
              width: picked ? 1.5 : 1,
            ),
          ),
          child: picked ? _docPickedRow() : _docEmptyRow(),
        ),
      ),
    );
  }

  Widget _docEmptyRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _primaryTint,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _primaryBorder),
          ),
          child: const Icon(
            Icons.upload_file_rounded,
            size: 17,
            color: _primary,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upload Lampiran",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            Text(
              "PDF / DOC / DOCX",
              style: TextStyle(fontSize: 11, color: _textHint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _docPickedRow() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.description_rounded, size: 17, color: _white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _docFile!.path.split('/').last,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                "Dokumen terpilih",
                style: TextStyle(fontSize: 10.5, color: _textSub),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _docFile = null),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8E8),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: Color(0xFFB71C1C),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Info Note ─────────────────────────────────────────────────────
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                "i",
                style: TextStyle(
                  color: _white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Pastikan rentang tanggal dan alasan pengajuan diisi dengan benar. Lampiran dokumen bersifat opsional namun disarankan.",
              style: TextStyle(fontSize: 11.5, color: _textSub, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Submit Button ─────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _sendData,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _border,
          foregroundColor: _white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: _white, strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 17),
                  SizedBox(width: 8),
                  Text(
                    "Kirim Pengajuan",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Model ─────────────────────────────────────────────────────────
class _JenisOption {
  const _JenisOption({
    required this.label,
    required this.value,
    required this.icon,
    required this.desc,
  });
  final String label;
  final String value;
  final IconData icon;
  final String desc;
}

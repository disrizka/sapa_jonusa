import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Design Tokens ─────────────────────────────────────────────────
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
const _borderMid = Color(0xFFB5D4F4);
// ───────────────────────────────────────────────────────────────────

class SakitScreen extends StatefulWidget {
  const SakitScreen({super.key});

  @override
  State<SakitScreen> createState() => _SakitScreenState();
}

class _SakitScreenState extends State<SakitScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile;
  File? _docFile;
  bool _loading = false;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

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

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
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

  Future<void> _submitSakit() async {
    if (_startDate == null ||
        _reasonController.text.trim().isEmpty ||
        (_imageFile == null && _docFile == null)) {
      _snack(
        "Lengkapi semua field & tambahkan minimal 1 lampiran",
        error: true,
      );
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
              'category': 'sakit',
              'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
              'end_date': DateFormat(
                'yyyy-MM-dd',
              ).format(_endDate ?? _startDate!),
              'reason': _reasonController.text,
            });

      if (_imageFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'attachment_photo',
            _imageFile!.path,
          ),
        );
      }
      if (_docFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath('attachment_file', _docFile!.path),
        );
      }

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _snack("Laporan berhasil dikirim");
        if (mounted) Navigator.pop(context);
      } else {
        _snack("Gagal mengirim laporan. Coba lagi.", error: true);
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

  // ─── Header (no progress bar) ──────────────────────────────────────
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
                      "Laporan Sakit",
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
                  Icons.medical_services_rounded,
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
                      color: _primaryBorder,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _primary,
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

  // ─── Date Card ─────────────────────────────────────────────────────
  Widget _buildDateCard() {
    return _buildSectionCard(
      icon: Icons.date_range_rounded,
      title: "Rentang Sakit",
      child: Row(
        children: [
          Expanded(
            child: _datePickerTile(
              label: "MULAI SAKIT",
              date: _startDate,
              onPick: (d) => setState(() => _startDate = d),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _datePickerTile(
              label: "SELESAI SAKIT",
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
          initialDate: DateTime.now(),
          firstDate: DateTime(2024),
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
      title: "Keterangan Sakit",
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _reasonController,
          maxLines: 5,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 13.5,
            height: 1.55,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(13),
            border: InputBorder.none,
            hintText: "Jelaskan keluhan atau kondisi kesehatan Anda...",
            hintStyle: TextStyle(color: _textHint, fontSize: 13.5),
          ),
        ),
      ),
    );
  }

  // ─── Attachment Card ───────────────────────────────────────────────
  Widget _buildAttachmentCard() {
    return _buildSectionCard(
      icon: Icons.attach_file_rounded,
      title: "Lampiran Pendukung",
      badge: "Wajib 1",
      child: Row(
        children: [
          Expanded(child: _attachTile(isPhoto: true)),
          const SizedBox(width: 10),
          Expanded(child: _attachTile(isPhoto: false)),
        ],
      ),
    );
  }

  Widget _attachTile({required bool isPhoto}) {
    final file = isPhoto ? _imageFile : _docFile;
    final bool picked = file != null;

    return GestureDetector(
      onTap: isPhoto ? _takePhoto : _pickDocument,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 120,
        decoration: BoxDecoration(
          color: picked ? _primaryTint : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: picked ? _primary : _borderMid,
            width: picked ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: picked
            ? (isPhoto ? _photoPickedView() : _docPickedView(file!))
            : _attachEmptyView(
                icon: isPhoto
                    ? Icons.camera_alt_rounded
                    : Icons.upload_file_rounded,
                label: isPhoto ? "Foto Surat" : "Upload Dokumen",
                sub: isPhoto ? "Buka kamera" : "PDF / Word",
              ),
      ),
    );
  }

  Widget _attachEmptyView({
    required IconData icon,
    required String label,
    required String sub,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primaryTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _primaryBorder),
          ),
          child: Icon(icon, size: 18, color: _primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 10.5, color: _textHint)),
      ],
    );
  }

  Widget _photoPickedView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_imageFile!, fit: BoxFit.cover),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: () => setState(() => _imageFile = null),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: _white),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            color: Colors.black.withOpacity(0.38),
            child: const Text(
              "Foto terpilih",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── FIX: doc view dengan overflow.ellipsis & no flexible heights ──
  Widget _docPickedView(File file) {
    final fileName = file.path.split('/').last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: _white,
              size: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _docFile = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Hapus",
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
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
              "Lampiran surat dokter atau foto surat sakit wajib disertakan sebagai bukti validasi laporan.",
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
        onPressed: _loading ? null : _submitSakit,
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
                    "Kirim Laporan",
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

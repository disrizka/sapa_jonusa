import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Palette: White-dominant, Red accent ─────────────────────────
const _bg = Color(0xFFFBF3F3);
const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFC0312B);
const _redMed = Color(0xFFD94040);
const _redTint = Color(0xFFFDEDED);
const _textPrimary = Color(0xFF2A0E0E);
const _textSub = Color(0xFF7A4545);
const _textHint = Color(0xFFB89090);
const _border = Color(0xFFEED8D8);
// ─────────────────────────────────────────────────────────────────

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
    duration: const Duration(milliseconds: 450),
  )..forward();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
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
    if (result != null)
      setState(() => _docFile = File(result.files.single.path!));
  }

  Future<void> _submitSakit() async {
    if (_startDate == null ||
        _reasonController.text.isEmpty ||
        (_imageFile == null && _docFile == null)) {
      _snack("Lengkapi form & minimal kirim 1 lampiran!", error: true);
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
      if (_imageFile != null)
        req.files.add(
          await http.MultipartFile.fromPath(
            'attachment_photo',
            _imageFile!.path,
          ),
        );
      if (_docFile != null)
        req.files.add(
          await http.MultipartFile.fromPath('attachment_file', _docFile!.path),
        );
      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 201 || response.statusCode == 200) {
        _snack("Laporan berhasil dikirim");
        if (mounted) Navigator.pop(context);
      } else {
        _snack("Gagal mengirim laporan.", error: true);
      }
    } catch (e) {
      _snack("Error: $e", error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: error ? Colors.red.shade900 : _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 175,
              pinned: true,
              backgroundColor: _white,
              elevation: 0,
              surfaceTintColor: _white,
              leading: Padding(
                padding: const EdgeInsets.all(10),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Laporan",
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSub,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                    Text(
                      "Sakit",
                      style: TextStyle(
                        fontSize: 22,
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  color: _white,
                  child: Stack(
                    children: [
                      Positioned(
                        right: 20,
                        top: 38,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _redTint,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: _red,
                            size: 44,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: _red.withOpacity(0.07),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: _border),
              ),
            ),

            // ── Form Body ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Tanggal
                  _SectionLabel(
                    text: "Rentang Sakit",
                    icon: Icons.date_range_rounded,
                    color: _red,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateCard(
                          "Mulai Sakit",
                          _startDate,
                          (d) => setState(() => _startDate = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateCard(
                          "Selesai Sakit",
                          _endDate,
                          (d) => setState(() => _endDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Keterangan
                  _SectionLabel(
                    text: "Keterangan Sakit",
                    icon: Icons.edit_note_rounded,
                    color: _red,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      style: const TextStyle(color: _textPrimary, fontSize: 14),
                      decoration: const InputDecoration.collapsed(
                        hintText: "Deskripsikan keluhan atau kondisi Anda...",
                        hintStyle: TextStyle(color: _textHint, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lampiran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionLabel(
                        text: "Lampiran",
                        icon: Icons.attach_file_rounded,
                        color: _red,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _redTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Wajib salah satu",
                          style: TextStyle(
                            fontSize: 11,
                            color: _red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Foto
                      Expanded(
                        child: GestureDetector(
                          onTap: _takePhoto,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 120,
                            decoration: BoxDecoration(
                              color: _imageFile != null ? _redTint : _white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _imageFile != null ? _redMed : _border,
                                width: _imageFile != null ? 1.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _imageFile == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _redTint,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: _red,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Foto Surat",
                                        style: TextStyle(
                                          color: _textSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        "Kamera",
                                        style: TextStyle(
                                          color: _textHint,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() => _imageFile = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 13,
                                              color: _white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Dokumen
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDocument,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 120,
                            decoration: BoxDecoration(
                              color: _docFile != null ? _redTint : _white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _docFile != null ? _redMed : _border,
                                width: _docFile != null ? 1.5 : 1,
                              ),
                            ),
                            child: _docFile == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _redTint,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.file_present_rounded,
                                          color: _red,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Upload Dokumen",
                                        style: TextStyle(
                                          color: _textSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        "PDF / Word",
                                        style: TextStyle(
                                          color: _textHint,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _red,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.description_rounded,
                                            color: _white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _docFile!.path.split('/').last,
                                          style: const TextStyle(
                                            color: _textPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _docFile = null),
                                          child: Text(
                                            "Hapus",
                                            style: TextStyle(
                                              color: Colors.red.shade400,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitSakit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        disabledBackgroundColor: _border,
                        foregroundColor: _white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: _white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 17),
                                SizedBox(width: 8),
                                Text(
                                  "Kirim Laporan",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(
    String label,
    DateTime? date,
    Function(DateTime) onPick,
  ) {
    final bool sel = date != null;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2025),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: _red,
                onPrimary: _white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? _redTint : _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? _redMed : _border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sel ? _redMed : _textHint,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: sel ? _red : _textHint,
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String text;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _textSub,
          letterSpacing: 0.2,
        ),
      ),
    ],
  );
}

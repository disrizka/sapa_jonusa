import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── Palette: White-dominant, Navy accent ────────────────────────
const _bg = Color(0xFFF2F5FB);
const _white = Color(0xFFFFFFFF);
const _navy = Color(0xFF1A3A6B);
const _navyMed = Color(0xFF2E55A0);
const _navyTint = Color(0xFFE7EDF8);
const _textPrimary = Color(0xFF111D35);
const _textSub = Color(0xFF556080);
const _textHint = Color(0xFF9CAABF);
const _border = Color(0xFFDDE3EE);
// ─────────────────────────────────────────────────────────────────

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
    duration: const Duration(milliseconds: 450),
  )..forward();

  final Map<String, String> _typeMap = {"Izin": "izin", "Cuti": "cuti"};

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

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null)
      setState(() => _docFile = File(result.files.single.path!));
  }

  Future<void> _sendData() async {
    if (_startDate == null ||
        _endDate == null ||
        _selectedType == null ||
        _reasonController.text.isEmpty) {
      _snack("Lengkapi semua form!", error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final typeValue = _typeMap[_selectedType!] ?? _selectedType!;
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
              'type': typeValue,
              'category': typeValue,
              'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
              'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
              'reason': _reasonController.text,
            });
      if (_docFile != null)
        req.files.add(
          await http.MultipartFile.fromPath('attachment_file', _docFile!.path),
        );
      final res = await req.send();
      if (res.statusCode == 201) {
        if (mounted) {
          _snack("Pengajuan berhasil dikirim!");
          Navigator.pop(context);
        }
      } else {
        debugPrint(await res.stream.bytesToString());
        if (mounted) _snack("Gagal mengirim: ${res.statusCode}", error: true);
      }
    } catch (e) {
      if (mounted) _snack("Terjadi kesalahan: $e", error: true);
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
          backgroundColor: error ? Colors.red.shade700 : _navyMed,
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
                title: const _AppBarTitle(
                  top: "Pengajuan",
                  bottom: "Izin / Cuti",
                ),
                background: Container(
                  color: _white,
                  child: Stack(
                    children: [
                      Positioned(
                        right: 20,
                        top: 40,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _navyTint,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.event_available_rounded,
                            color: _navy,
                            size: 42,
                          ),
                        ),
                      ),
                      // subtle bottom stripe
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: _navy.withOpacity(0.06),
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
                  // Jenis
                  _SectionLabel(
                    text: "Jenis Pengajuan",
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 8),
                  _FieldCard(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isExpanded: true,
                        hint: const Text(
                          "Pilih jenis pengajuan",
                          style: TextStyle(color: _textHint, fontSize: 14),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _textSub,
                        ),
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: _white,
                        items: _typeMap.keys
                            .map(
                              (label) => DropdownMenuItem(
                                value: label,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _navyTint,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        label == "Cuti"
                                            ? Icons.beach_access_rounded
                                            : Icons.timer_rounded,
                                        color: _navy,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(label),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedType = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tanggal
                  _SectionLabel(
                    text: "Rentang Tanggal",
                    icon: Icons.date_range_rounded,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateCard(
                          "Mulai",
                          _startDate,
                          (d) => setState(() => _startDate = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateCard(
                          "Selesai",
                          _endDate,
                          (d) => setState(() => _endDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Alasan
                  _SectionLabel(text: "Alasan", icon: Icons.edit_note_rounded),
                  const SizedBox(height: 8),
                  _FieldCard(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      style: const TextStyle(color: _textPrimary, fontSize: 14),
                      decoration: const InputDecoration.collapsed(
                        hintText: "Tuliskan alasan pengajuan Anda...",
                        hintStyle: TextStyle(color: _textHint, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lampiran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(
                        text: "Lampiran Dokumen",
                        icon: Icons.attach_file_rounded,
                      ),
                      _Badge(
                        "Opsional",
                        bgColor: const Color(0xFFFFF3E0),
                        textColor: const Color(0xFFBF6000),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDocument,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _docFile != null ? _navyTint : _white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _docFile != null ? _navyMed : _border,
                          width: _docFile != null ? 1.5 : 1,
                        ),
                      ),
                      child: _docFile == null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _navyTint,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.upload_file_rounded,
                                    color: _navy,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Upload PDF / Word",
                                  style: TextStyle(
                                    color: _textSub,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _navy,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.description_rounded,
                                    color: _white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _docFile!.path.split('/').last,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _docFile = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
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
                                  "Kirim Pengajuan",
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
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: _navy,
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
          color: sel ? _navyTint : _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? _navyMed : _border,
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
                color: sel ? _navyMed : _textHint,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: sel ? _navy : _textHint,
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

// ── Shared small widgets ──────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.top, required this.bottom});
  final String top, bottom;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        top,
        style: const TextStyle(
          fontSize: 12,
          color: _textSub,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
      Text(
        bottom,
        style: const TextStyle(
          fontSize: 20,
          color: _textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: _navy),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _textSub,
          letterSpacing: 0.2,
        ),
      ),
    ],
  );
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: child,
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.bgColor, required this.textColor});
  final String label;
  final Color bgColor, textColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

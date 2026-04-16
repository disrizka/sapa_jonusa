import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

class SakitScreen extends StatefulWidget {
  const SakitScreen({super.key});

  @override
  State<SakitScreen> createState() => _SakitScreenState();
}

class _SakitScreenState extends State<SakitScreen> {
  final _storage = const FlutterSecureStorage();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile; // Untuk Foto Kamera
  File? _docFile; // Untuk Dokumen PDF
  bool _loading = false;

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      _showSnackBar("Lengkapi form & Minimal kirim 1 Lampiran!", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      String? token = await _storage.read(key: 'auth_token');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/permissions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['category'] = 'sakit';
      request.fields['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_startDate!);
      request.fields['end_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_endDate ?? _startDate!);
      request.fields['reason'] = _reasonController.text;

      // Kirim Foto ke kolom attachment_photo
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment_photo',
            _imageFile!.path,
          ),
        );
      }

      // Kirim Dokumen ke kolom attachment_file
      if (_docFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment_file', _docFile!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar("Laporan berhasil dikirim", isError: false);
        Navigator.pop(context);
      } else {
        _showSnackBar("Gagal mengirim laporan.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Sakit"),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _dateTile(
            "Mulai Sakit",
            _startDate,
            (d) => setState(() => _startDate = d),
          ),
          _dateTile(
            "Selesai Sakit",
            _endDate,
            (d) => setState(() => _endDate = d),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: "Alasan",
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          const Text(
            "Lampiran (Wajib salah satu)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _takePhoto,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _imageFile == null
                        ? const Icon(Icons.camera_alt, size: 30)
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickDocument,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _docFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_present),
                              Text("Pilih PDF", style: TextStyle(fontSize: 10)),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              Text(
                                "PDF Terpilih",
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loading ? null : _submitSakit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("KIRIM LAPORAN"),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, Function(DateTime) onPick) {
    return ListTile(
      title: Text(
        date == null ? label : DateFormat('dd MMMM yyyy').format(date),
      ),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        var p = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2025),
          lastDate: DateTime(2030),
        );
        if (p != null) onPick(p);
      },
    );
  }
}

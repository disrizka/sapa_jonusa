import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen> {
  final _storage = const FlutterSecureStorage();
  final _reasonController = TextEditingController();

  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _file;
  bool _loading = false;

  // Map label tampilan → value ENUM di database
  final Map<String, String> _categoryMap = {
    "Cuti Tahunan": "cuti_tahunan",
    "Cuti Khusus": "cuti_khusus",
    "Cuti Tidak Dibayar": "cuti_tidak_dibayar",
  };

  Future<void> _sendData() async {
    if (_startDate == null ||
        _endDate == null ||
        _selectedCategory == null ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lengkapi semua form!")));
      return;
    }

    setState(() => _loading = true);
    try {
      String? token = await _storage.read(key: 'auth_token');

      // Ambil value ENUM yang sesuai DB dari map
      final String categoryValue =
          _categoryMap[_selectedCategory!] ?? _selectedCategory!;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/presence/permissions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['type'] = 'cuti';
      request.fields['category'] = categoryValue; // ✅ value sesuai ENUM DB
      request.fields['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(_startDate!);
      request.fields['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      request.fields['reason'] = _reasonController.text;

      if (_file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', _file!.path),
        );
      }

      var res = await request.send();
      if (res.statusCode == 201) {
        if (mounted) Navigator.pop(context);
      } else {
        // Tampilkan error jika status bukan 201
        final resBody = await res.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal mengirim: ${res.statusCode}")),
          );
        }
        debugPrint('Response error: $resBody');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan: $e")));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengajuan Cuti")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            items: _categoryMap.keys
                .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
            decoration: const InputDecoration(
              labelText: "Pilih Jenis Cuti",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _dateTile("Mulai", _startDate, (d) => setState(() => _startDate = d)),
          _dateTile("Selesai", _endDate, (d) => setState(() => _endDate = d)),
          const SizedBox(height: 20),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Alasan",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          // ElevatedButton.icon(
          //   onPressed: () async {
          //     var result = await FilePicker.platform.pickFiles(
          //       type: FileType.image,
          //     );
          //     if (result != null)
          //       setState(() => _file = File(result.files.single.path!));
          //   },
          //   icon: const Icon(Icons.attach_file),
          //   label: Text(_file == null ? "Upload Lampiran" : "File Terpilih"),
          // ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loading ? null : _sendData,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _loading
                ? const CircularProgressIndicator()
                : const Text("KIRIM"),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, Function(DateTime) onPick) {
    return ListTile(
      title: Text(
        date == null
            ? "Pilih Tanggal $label"
            : DateFormat('dd-MM-yyyy').format(date),
      ),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        var picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}

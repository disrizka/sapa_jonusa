// widgets/file_bubble.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart'; // tambah: open_filex: ^4.5.0
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/file_utils.dart';

// ─── File Bubble (PDF, DOC, XLS, dll) ────────────────────────────────────────
class FileBubble extends StatefulWidget {
  final String filePath;
  final String fileUrl;
  final String? token;
  final bool isMe;

  const FileBubble({
    super.key,
    required this.filePath,
    required this.fileUrl,
    required this.isMe,
    this.token,
  });

  @override
  State<FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<FileBubble> {
  bool _isBusy = false; // dipakai untuk open & download
  bool _isDownloaded = false;
  String? _localPath;

  FileKind get _kind => detectFileKind(widget.filePath);

  /// Download file ke temp dir lalu buka dengan app eksternal
  Future<void> _openFile() async {
    if (_isBusy) return;

    // Kalau sudah ada di lokal, langsung buka
    if (_localPath != null) {
      await OpenFilex.open(_localPath!);
      return;
    }

    setState(() => _isBusy = true);
    _showSnack('Mengunduh file...', color: Colors.indigo);
    try {
      final res = await http
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final dir = await getTemporaryDirectory();
      final fileName = p.basename(widget.filePath);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);

      if (mounted)
        setState(() {
          _isBusy = false;
          _localPath = file.path;
        });
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showSnack('Gagal buka file: $e', color: Colors.red.shade700);
      }
    }
  }

  /// Download ke Documents folder (permanent)
  Future<void> _downloadFile() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final res = await http
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final dir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(widget.filePath);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);

      if (mounted) {
        setState(() {
          _isBusy = false;
          _isDownloaded = true;
          _localPath = file.path;
        });
        _showSnack('Tersimpan: ${file.path}', color: Colors.green.shade700);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showSnack('Gagal download: $e', color: Colors.red.shade700);
      }
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = fileIconColor(_kind, widget.isMe);
    final bgColor = widget.isMe
        ? Colors.white.withOpacity(0.15)
        : Colors.grey.shade50;
    final borderColor = widget.isMe
        ? Colors.white.withOpacity(0.3)
        : Colors.grey.shade200;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── File info row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(fileIcon(_kind), color: color, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(widget.filePath),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isMe ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileKindLabel(_kind),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isMe
                            ? Colors.white60
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Action buttons ──
          Row(
            children: [
              // Tombol BUKA
              Expanded(
                child: GestureDetector(
                  onTap: _isBusy ? null : _openFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: _isBusy
                        ? Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Buka',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol DOWNLOAD
              GestureDetector(
                onTap: _isBusy ? null : _downloadFile,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(
                    _isDownloaded
                        ? Icons.download_done_rounded
                        : Icons.download_rounded,
                    size: 15,
                    color: _isDownloaded ? Colors.green : color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Audio Bubble ─────────────────────────────────────────────────────────────
class AudioBubble extends StatefulWidget {
  final String fileUrl;
  final String? token;
  final bool isMe;

  const AudioBubble({
    super.key,
    required this.fileUrl,
    required this.isMe,
    this.token,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  bool _isBusy = false;
  bool _isDownloaded = false;
  String? _localPath;

  Future<void> _play() async {
    if (_isBusy) return;

    if (_localPath != null) {
      await OpenFilex.open(_localPath!);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final res = await http
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final dir = await getTemporaryDirectory();
      final fileName = Uri.parse(widget.fileUrl).pathSegments.last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);

      if (mounted) {
        setState(() {
          _isBusy = false;
          _localPath = file.path;
        });
      }
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal putar audio: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _download() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final res = await http
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final dir = await getApplicationDocumentsDirectory();
      final fileName = Uri.parse(widget.fileUrl).pathSegments.last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes);

      if (mounted) {
        setState(() {
          _isBusy = false;
          _isDownloaded = true;
          _localPath = file.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tersimpan: ${file.path}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal download: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6A1B9A);
    final bgColor = widget.isMe
        ? Colors.white.withOpacity(0.15)
        : Colors.grey.shade50;
    final borderColor = widget.isMe
        ? Colors.white.withOpacity(0.3)
        : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.audiotrack_rounded,
              color: widget.isMe ? Colors.white70 : color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesan Suara',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isMe ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Ketuk ▶ untuk putar',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isMe ? Colors.white60 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Play button
          GestureDetector(
            onTap: _play,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isBusy
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe ? Colors.white : color,
                      ),
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      color: widget.isMe ? Colors.white : color,
                      size: 18,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // Download button
          GestureDetector(
            onTap: _download,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                color: _isDownloaded
                    ? Colors.green
                    : (widget.isMe ? Colors.white : color),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

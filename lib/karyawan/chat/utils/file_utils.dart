// utils/file_utils.dart

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sapa_jonusa/api/api.dart' as Api;

enum FileKind { image, video, audio, pdf, doc, spreadsheet, other }

FileKind detectFileKind(String? path) {
  if (path == null || path.isEmpty) return FileKind.other;
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext))
    return FileKind.image;
  if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext))
    return FileKind.video;
  if (['mp3', 'aac', 'wav', 'ogg', 'm4a', 'opus'].contains(ext))
    return FileKind.audio;
  if (ext == 'pdf') return FileKind.pdf;
  if (['doc', 'docx'].contains(ext)) return FileKind.doc;
  if (['xls', 'xlsx', 'csv'].contains(ext)) return FileKind.spreadsheet;
  return FileKind.other;
}

IconData fileIcon(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return Icons.picture_as_pdf_rounded;
    case FileKind.doc:
      return Icons.description_rounded;
    case FileKind.spreadsheet:
      return Icons.table_chart_rounded;
    case FileKind.audio:
      return Icons.audio_file_rounded;
    case FileKind.video:
      return Icons.video_file_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color fileIconColor(FileKind kind, bool isMe) {
  if (isMe) return Colors.white70;
  switch (kind) {
    case FileKind.pdf:
      return Colors.red.shade700;
    case FileKind.doc:
      return Colors.blue.shade700;
    case FileKind.spreadsheet:
      return Colors.green.shade700;
    case FileKind.audio:
      return const Color(0xFF6A1B9A);
    case FileKind.video:
      return Colors.orange.shade700;
    default:
      return Colors.indigo;
  }
}

String fileKindLabel(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return 'PDF';
    case FileKind.doc:
      return 'Dokumen Word';
    case FileKind.spreadsheet:
      return 'Spreadsheet';
    case FileKind.audio:
      return 'Audio';
    case FileKind.video:
      return 'Video';
    default:
      return 'File';
  }
}

/// Builds full file URL from relative path stored in DB.
/// DB stores "uploads/filename.jpg"
/// URL: http://domain/uploads/filename.jpg
String buildFileUrl(String filePath) {
  final base = Api.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
  var path = filePath.trim().replaceAll(RegExp(r'^/'), '');
  // Remove legacy "storage/" prefix if present
  path = path.replaceFirst(RegExp(r'^storage/'), '');
  return '$base/$path';
}

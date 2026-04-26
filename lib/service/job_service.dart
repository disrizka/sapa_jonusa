import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

class TechnicianUser {
  final int id;
  final String name;
  final String division;

  TechnicianUser({
    required this.id,
    required this.name,
    required this.division,
  });

  factory TechnicianUser.fromJson(Map<String, dynamic> json) {
    return TechnicianUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '-',
      division: json['division'] as String? ?? '-',
    );
  }
}

class StepRequirement {
  final int stepNumber;
  final String stepName;
  final bool reqDesc;
  final bool reqPhoto;
  final bool reqVideo;

  StepRequirement({
    required this.stepNumber,
    required this.stepName,
    required this.reqDesc,
    required this.reqPhoto,
    required this.reqVideo,
  });

  factory StepRequirement.fromJson(Map<String, dynamic> json) {
    return StepRequirement(
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 0,
      stepName: json['step_name'] as String? ?? '',
      reqDesc: json['req_desc'] == true,
      reqPhoto: json['req_photo'] == true,
      reqVideo: json['req_video'] == true,
    );
  }
}

Map<int, StepRequirement> _parseStepRequirements(dynamic raw) {
  final result = <int, StepRequirement>{};
  if (raw == null) return result;

  if (raw is Map) {
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final stepNum = int.tryParse(key.toString()) ?? 0;
        final data = Map<String, dynamic>.from(value);
        data['step_number'] ??= stepNum;
        result[stepNum] = StepRequirement.fromJson(data);
      }
    });
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final req = StepRequirement.fromJson(item);
        result[req.stepNumber] = req;
      }
    }
  }

  return result;
}

class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int? currentStep;
  final String? feedback;
  final Map<String, dynamic>? cs;
  final Map<String, dynamic>? technician;
  final int? technicianId;
  final List<JobTracker> trackers;
  final List<JobComment> comments;
  final Map<int, StepRequirement> _stepRequirementsMap;
  final String? createdAt;
  final String? clientName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? startTime;
  final String? endTime;
  final String? acceptedAt;
  final String? completedAt;
  final int? actualDuration;
  final String? completionReason;
  final bool isOverdue;

  Job({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.currentStep,
    this.feedback,
    this.cs,
    this.technician,
    this.technicianId,
    required this.trackers,
    required this.comments,
    Map<int, StepRequirement> stepRequirementsMap = const {},
    this.createdAt,
    this.clientName,
    this.location,
    this.latitude,
    this.longitude,
    this.startTime,
    this.endTime,
    this.acceptedAt,
    this.completedAt,
    this.actualDuration,
    this.completionReason,
    this.isOverdue = false,
  }) : _stepRequirementsMap = stepRequirementsMap;

  bool get isPending => status == 'pending';
  bool get isProcess => status == 'process';
  bool get isCompleted => status == 'completed';

  StepRequirement? requirementForStep(int step) => _stepRequirementsMap[step];

  String get actualDurationLabel {
    if (actualDuration == null) return '-';
    final h = actualDuration! ~/ 3600;
    final m = (actualDuration! % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}j ${m}m';
    if (h > 0) return '${h}j';
    if (m > 0) return '${m}m';
    return '< 1m';
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      currentStep: (json['current_step'] as num?)?.toInt(),
      feedback: json['feedback'] as String?,
      cs: json['cs'] as Map<String, dynamic>?,
      technician: json['technician'] as Map<String, dynamic>?,
      technicianId: (json['technician_id'] as num?)?.toInt(),
      trackers: (json['trackers'] as List<dynamic>? ?? [])
          .map((t) => JobTracker.fromJson(t as Map<String, dynamic>))
          .toList(),
      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((c) => JobComment.fromJson(c as Map<String, dynamic>))
          .toList(),
      stepRequirementsMap: _parseStepRequirements(json['step_requirements']),
      createdAt: json['created_at'] as String?,
      clientName: json['client_name'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      acceptedAt: json['accepted_at'] as String?,
      completedAt: json['completed_at'] as String?,
      actualDuration: (json['actual_duration'] as num?)?.toInt(),
      completionReason: json['completion_reason'] as String?,
      isOverdue: json['is_overdue'] == true,
    );
  }
}

class JobTracker {
  final int id;
  final int stepNumber;
  final String? descriptionValue;
  final String? photoUrl;
  final String? videoUrl;
  final String? createdAt;

  JobTracker({
    required this.id,
    required this.stepNumber,
    this.descriptionValue,
    this.photoUrl,
    this.videoUrl,
    this.createdAt,
  });

  factory JobTracker.fromJson(Map<String, dynamic> json) => JobTracker(
    id: (json['id'] as num?)?.toInt() ?? 0,
    stepNumber: (json['step_number'] as num?)?.toInt() ?? 0,
    descriptionValue: json['description_value'] as String?,
    photoUrl: json['photo_url'] as String?,
    videoUrl: json['video_url'] as String?,
    createdAt: json['created_at'] as String?,
  );
}

class JobComment {
  final int id;
  final String comment;
  final String userName;
  final int userId;
  final String? createdAt;

  JobComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.userId,
    this.createdAt,
  });

  factory JobComment.fromJson(Map<String, dynamic> json) => JobComment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    comment: json['comment'] as String? ?? '',
    userName: json['user_name'] as String? ?? '-',
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String?,
  );
}

class JobService {
  static const _storage = FlutterSecureStorage();

  static String get _base => '${Api.baseUrl}/api';

  static Future<void> debugStorage() async {
    try {
      final all = await _storage.readAll();
      debugPrint('══════════════════════════════════════════');
      debugPrint(' SECURE STORAGE — semua key yang tersimpan:');
      if (all.isEmpty) {
        debugPrint('  Storage KOSONG — token belum tersimpan!');
      } else {
        all.forEach((k, v) {
          final display = v.length > 100 ? '${v.substring(0, 100)}...' : v;
          debugPrint('  🔑 "$k" = "$display"');
        });
      }
      debugPrint('══════════════════════════════════════════');
    } catch (e) {
      debugPrint(' debugStorage error: $e');
    }
  }

  static Future<String> _getToken() async {
    final token = await _storage.read(key: 'auth_token');
    debugPrint(
      '🔐 _getToken: "${token == null
          ? "NULL - tidak ada!"
          : token.length > 20
          ? "${token.substring(0, 20)}..."
          : token}"',
    );
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static void _checkResponse(http.Response res, String ctx) {
    debugPrint('[$ctx] status=${res.statusCode}');
    if (res.statusCode == 401) {
      throw Exception('Sesi habis. Silakan login ulang.');
    }
    if (res.statusCode == 403) {
      throw Exception('Anda tidak memiliki izin untuk aksi ini.');
    }
    if (res.statusCode >= 400) {
      String msg = 'Error ${res.statusCode}';
      try {
        msg = (jsonDecode(res.body)['message'] as String?) ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<List<Job>> getActiveJobs() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/active'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getActiveJobs');
    final list = jsonDecode(res.body)['data'] as List? ?? [];
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Job>> getJobHistory() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/history'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getJobHistory');
    final list = jsonDecode(res.body)['data'] as List? ?? [];
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<TechnicianUser>> getTechnicians() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/technicians'),
      headers: _headers(token),
    );
    debugPrint('[getTechnicians] body=${res.body}');
    _checkResponse(res, 'getTechnicians');

    final body = jsonDecode(res.body);
    final List<dynamic> list = body is Map && body['data'] != null
        ? body['data'] as List
        : body is List
        ? body
        : [];

    return list
        .map((e) => TechnicianUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createJob({
    required String title,
    required String description,
    required int technicianId,
    String? clientName,
    String? location,
    double? latitude,
    double? longitude,
    String? startTime,
    String? endTime,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs'),
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'description': description,
        'technician_id': technicianId,
        if (clientName != null) 'client_name': clientName,
        if (location != null) 'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
      }),
    );
    _checkResponse(res, 'createJob');
  }

  static Future<void> acceptJob(int jobId) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs/$jobId/accept'),
      headers: _headers(token),
    );
    _checkResponse(res, 'acceptJob');
  }

  static Future<Map<String, dynamic>> updateProgress({
    required int jobId,
    required String description,
    File? photoFile,
    File? videoFile,
    String? completionReason,
  }) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/jobs/$jobId/progress'),
    );

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['description_value'] = description;
    if (completionReason != null && completionReason.isNotEmpty) {
      request.fields['completion_reason'] = completionReason;
    }
    if (photoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoFile.path),
      );
    }
    if (videoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkResponse(res, 'updateProgress');

    final data = jsonDecode(res.body);
    return {'job': Job.fromJson(data['job'] as Map<String, dynamic>)};
  }

  static Future<JobComment> addComment({
    required int jobId,
    required String comment,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_base/jobs/$jobId/comments'),
      headers: _headers(token),
      body: jsonEncode({'comment': comment}),
    );
    debugPrint('[addComment] status=${res.statusCode} body=${res.body}');
    _checkResponse(res, 'addComment');
    return JobComment.fromJson(
      jsonDecode(res.body)['comment'] as Map<String, dynamic>,
    );
  }

  static Future<Job> getJobDetail(int jobId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_base/jobs/$jobId'),
      headers: _headers(token),
    );
    _checkResponse(res, 'getJobDetail');
    final body = jsonDecode(res.body);
    return Job.fromJson(body['job'] as Map<String, dynamic>);
  }
}

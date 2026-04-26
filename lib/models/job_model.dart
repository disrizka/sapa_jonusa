class StepRequirement {
  final String stepName;
  final bool reqDesc;
  final bool reqPhoto;
  final bool reqVideo;

  StepRequirement({
    required this.stepName,
    required this.reqDesc,
    required this.reqPhoto,
    required this.reqVideo,
  });

  factory StepRequirement.fromJson(Map<String, dynamic> json) {
    return StepRequirement(
      stepName: json['step_name'] ?? 'Tahap',
      reqDesc: json['req_desc'] == true,
      reqPhoto: json['req_photo'] == true,
      reqVideo: json['req_video'] == true,
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

  factory JobTracker.fromJson(Map<String, dynamic> json) {
    return JobTracker(
      id: json['id'] as int,
      stepNumber: (json['step_number'] as num).toInt(),
      descriptionValue: json['description_value'] as String?,
      photoUrl: json['photo_url'] as String?,
      videoUrl: json['video_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class JobComment {
  final int id;
  final String comment;
  final String userName;
  final int userId;
  final String createdAt;

  JobComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.userId,
    required this.createdAt,
  });

  factory JobComment.fromJson(Map<String, dynamic> json) {
    return JobComment(
      id: json['id'] as int,
      comment: json['comment'] as String,
      userName: json['user_name'] as String? ?? '-',
      userId: (json['user_id'] as num).toInt(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class Job {
  final int id;
  final String title;
  final String? description;
  final String status;
  final int? currentStep;
  final int completedSteps;

  final String? feedback;
  final Map<String, dynamic>? cs;
  final Map<String, dynamic>? technician;
  final int? technicianId;
  final List<JobTracker> trackers;
  final List<JobComment> comments;

  final bool isCompleted;
  final bool isProcess;
  final bool isPending;
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
  final Map<String, StepRequirement> stepRequirements;

  Job({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.currentStep,
    required this.completedSteps,
    this.feedback,
    this.cs,
    this.technician,
    this.technicianId,
    required this.trackers,
    required this.comments,
    required this.isCompleted,
    required this.isProcess,
    required this.isPending,
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
    required this.isOverdue,
    required this.stepRequirements,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final trackerList = (json['trackers'] as List<dynamic>? ?? [])
        .map((t) => JobTracker.fromJson(t as Map<String, dynamic>))
        .toList();
    final commentList = (json['comments'] as List<dynamic>? ?? [])
        .map((c) => JobComment.fromJson(c as Map<String, dynamic>))
        .toList();
    final Map<String, StepRequirement> stepReqs = {};
    final rawReqs = json['step_requirements'] as Map<String, dynamic>? ?? {};
    rawReqs.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        stepReqs[key] = StepRequirement.fromJson(value);
      }
    });

    return Job(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      currentStep: json['current_step'] != null
          ? (json['current_step'] as num).toInt()
          : null,

      completedSteps: (json['completed_steps'] as num? ?? 0).toInt(),

      feedback: json['feedback'] as String?,
      cs: json['cs'] as Map<String, dynamic>?,
      technician: json['technician'] as Map<String, dynamic>?,
      technicianId: json['technician_id'] != null
          ? (json['technician_id'] as num).toInt()
          : null,
      trackers: trackerList,
      comments: commentList,
      isCompleted: json['is_completed'] == true,
      isProcess: json['is_process'] == true,
      isPending: json['is_pending'] == true,
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
      stepRequirements: stepReqs,
    );
  }
  StepRequirement? requirementForStep(int step) {
    return stepRequirements[step.toString()];
  }

  String get actualDurationLabel {
    if (actualDuration == null) return '-';
    final h = actualDuration! ~/ 60;
    final m = actualDuration! % 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }
}

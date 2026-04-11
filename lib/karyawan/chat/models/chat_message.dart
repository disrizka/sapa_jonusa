// models/chat_message.dart

class ChatMessage {
  final int id;
  final int userId;
  final String? message;
  final String type;
  final String? filePath;
  final bool isPinned;
  final bool isEdited;
  final int seenByCount;
  final String createdAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? parent;
  final int? parentId;

  const ChatMessage({
    required this.id,
    required this.userId,
    this.message,
    required this.type,
    this.filePath,
    required this.isPinned,
    required this.isEdited,
    required this.seenByCount,
    required this.createdAt,
    this.user,
    this.parent,
    this.parentId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    message: json['message'] as String?,
    type: json['type'] as String? ?? 'text',
    filePath: json['file_path'] as String?,
    isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
    isEdited: json['is_edited'] == true || json['is_edited'] == 1,
    seenByCount: (json['seen_by_count'] ?? 0) as int,
    createdAt: json['created_at'] as String,
    user: json['user'] as Map<String, dynamic>?,
    parent: json['parent'] as Map<String, dynamic>?,
    parentId: json['parent_id'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'message': message,
    'type': type,
    'file_path': filePath,
    'is_pinned': isPinned,
    'is_edited': isEdited,
    'seen_by_count': seenByCount,
    'created_at': createdAt,
    'user': user,
    'parent': parent,
    'parent_id': parentId,
  };
}

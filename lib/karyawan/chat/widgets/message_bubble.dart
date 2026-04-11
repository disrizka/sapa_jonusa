// widgets/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../utils/file_utils.dart';
import 'image_bubble.dart';
import 'video_bubble.dart';
import 'file_bubble.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage chat;
  final bool isMe;
  final String? token;
  final void Function(int parentId) onJumpToParent;
  final VoidCallback onSeenByTap;

  const MessageBubble({
    super.key,
    required this.chat,
    required this.isMe,
    this.token,
    required this.onJumpToParent,
    required this.onSeenByTap,
  });

  @override
  Widget build(BuildContext context) {
    final fileUrl = (chat.filePath != null && chat.filePath!.isNotEmpty)
        ? buildFileUrl(chat.filePath!)
        : '';
    final hasOtherSeen = isMe && chat.seenByCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                chat.user?['name'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: EdgeInsets.all(
                  chat.type == 'image' || chat.type == 'video' ? 5 : 10,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1A237E) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 3),
                    bottomRight: Radius.circular(isMe ? 3 : 14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Pin label ──
                    if (chat.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 9,
                              color: isMe ? Colors.white60 : Colors.indigo,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Dipin',
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe ? Colors.white60 : Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Reply preview ──
                    if (chat.parent != null)
                      GestureDetector(
                        onTap: () => onJumpToParent(chat.parentId!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isMe ? Colors.white : Colors.indigo,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chat.parent!['user']['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white : Colors.indigo,
                                ),
                              ),
                              Text(
                                (chat.parent!['message'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? chat.parent!['message']
                                    : '📎 Media',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Image ──
                    if (chat.type == 'image' && fileUrl.isNotEmpty)
                      ImageBubble(
                        key: ValueKey(fileUrl),
                        fileUrl: fileUrl,
                        token: token,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenImageViewer(
                              imageUrl: fileUrl,
                              token: token,
                            ),
                          ),
                        ),
                      ),

                    // ── Video ──
                    if (chat.type == 'video' && fileUrl.isNotEmpty)
                      VideoBubble(
                        key: ValueKey(fileUrl),
                        url: fileUrl,
                        token: token,
                      ),

                    // ── Audio ──
                    if ((chat.type == 'audio' || chat.type == 'voice') &&
                        fileUrl.isNotEmpty)
                      AudioBubble(fileUrl: fileUrl, isMe: isMe, token: token),

                    // ── File (PDF, DOC, dll) ──
                    if (chat.type == 'file' && chat.filePath != null)
                      FileBubble(
                        filePath: chat.filePath!,
                        fileUrl: fileUrl,
                        isMe: isMe,
                        token: token,
                      ),

                    // ── Text ──
                    if (chat.message != null && chat.message!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: chat.type != 'text' ? 6 : 0,
                        ),
                        child: Text(
                          chat.message!,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Timestamp + status ──
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (chat.isPinned) ...[
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 9,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  DateFormat(
                    'HH:mm',
                  ).format(DateTime.parse(chat.createdAt).toLocal()),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (chat.isEdited)
                  const Text(
                    ' · diedit',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onSeenByTap,
                    child: hasOtherSeen
                        ? const Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: Colors.blue,
                          )
                        : const Icon(
                            Icons.done_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

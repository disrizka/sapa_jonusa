import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final Map? replyingTo;
  final VoidCallback onSend;
  final VoidCallback onPickerTap;
  final VoidCallback onCancelReply;

  const ChatInput({
    super.key,
    required this.controller,
    required this.replyingTo,
    required this.onSend,
    required this.onPickerTap,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Column(
      children: [
        if (replyingTo != null)
          _ReplyPreview(replyingTo: replyingTo!, onCancel: onCancelReply),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: Colors.indigo,
                  size: 28,
                ),
                onPressed: onPickerTap,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.indigo,
                  size: 26,
                ),
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReplyPreview extends StatelessWidget {
  final Map replyingTo;
  final VoidCallback onCancel;
  const _ReplyPreview({required this.replyingTo, required this.onCancel});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: const Color(0xFFF3F4FF),
    child: Row(
      children: [
        const Icon(Icons.reply_rounded, size: 18, color: Colors.indigo),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Membalas ${replyingTo['user']?['name'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Colors.indigo),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onCancel,
        ),
      ],
    ),
  );
}

class AttachmentPicker extends StatelessWidget {
  final void Function(String type) onPick;
  const AttachmentPicker({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lampiran',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _AttachItem(
              icon: Icons.image_rounded,
              label: 'Gambar',
              color: const Color(0xFF7C4DFF),
              onTap: () {
                Navigator.pop(context);
                onPick('image');
              },
            ),
            _AttachItem(
              icon: Icons.videocam_rounded,
              label: 'Video',
              color: const Color(0xFFE53935),
              onTap: () {
                Navigator.pop(context);
                onPick('video');
              },
            ),
            _AttachItem(
              icon: Icons.audiotrack_rounded,
              label: 'Audio',
              color: const Color(0xFF6A1B9A),
              onTap: () {
                Navigator.pop(context);
                onPick('audio');
              },
            ),
            _AttachItem(
              icon: Icons.folder_rounded,
              label: 'Dokumen',
              color: const Color(0xFF1565C0),
              onTap: () {
                Navigator.pop(context);
                onPick('file');
              },
            ),
          ],
        ),
      ],
    ),
  );
}

class _AttachItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    ),
  );
}

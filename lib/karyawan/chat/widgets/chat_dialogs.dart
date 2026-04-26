// widgets/chat_dialogs.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Seen By Dialog ───────────────────────────────────────────────────────────
class SeenByDialog extends StatelessWidget {
  final List seenBy;
  const SeenByDialog({super.key, required this.seenBy});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.done_all, color: Colors.indigo, size: 20),
        SizedBox(width: 8),
        Text('Dilihat oleh', style: TextStyle(fontSize: 16)),
      ],
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: seenBy.isEmpty
        ? const Text(
            'Belum ada yang melihat',
            style: TextStyle(color: Colors.grey),
          )
        : SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: seenBy.length,
              itemBuilder: (_, i) {
                final u = seenBy[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      (u['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.indigo,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    u['name'] ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: u['seen_at'] != null
                      ? Text(
                          DateFormat(
                            'dd MMM, HH:mm',
                          ).format(DateTime.parse(u['seen_at']).toLocal()),
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                );
              },
            ),
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}

// ─── Edit Dialog ──────────────────────────────────────────────────────────────
class EditMessageDialog extends StatefulWidget {
  final String initialText;
  const EditMessageDialog({super.key, required this.initialText});

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Pesan'),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: TextField(
      controller: _ctrl,
      maxLines: null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Tulis pesan...',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
        onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
        child: const Text('Simpan', style: TextStyle(color: Colors.white)),
      ),
    ],
  );
}

// ─── Pinned Bar ───────────────────────────────────────────────────────────────
class PinnedBar extends StatelessWidget {
  final List pinnedMessages;
  final VoidCallback onTap;
  const PinnedBar({
    super.key,
    required this.pinnedMessages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pinnedMessages.isEmpty) return const SizedBox.shrink();
    final last = pinnedMessages.last;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin_rounded, size: 16, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pesan Dipin',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  Text(
                    last['message']?.isNotEmpty == true
                        ? last['message']
                        : '📎 Media',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (pinnedMessages.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${pinnedMessages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_right,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pinned Sheet ─────────────────────────────────────────────────────────────
class PinnedSheet extends StatelessWidget {
  final List pinnedMessages;
  final Function(int) onUnpin;
  final Function(int) onJump;
  const PinnedSheet({
    super.key,
    required this.pinnedMessages,
    required this.onUnpin,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.push_pin_rounded, color: Colors.indigo),
            const SizedBox(width: 8),
            const Text(
              'Pesan Dipin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${pinnedMessages.length} pesan',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pinnedMessages.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Belum ada pesan yang dipin',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...pinnedMessages.map(
            (msg) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo.shade50,
                child: Text(
                  (msg['user']?['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.indigo, fontSize: 12),
                ),
              ),
              title: Text(
                msg['user']?['name'] ?? '-',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                msg['message']?.isNotEmpty == true
                    ? msg['message']
                    : '📎 Media',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.push_pin_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onUnpin(msg['id'] as int);
                },
              ),
              onTap: () {
                Navigator.pop(context);
                onJump(msg['id'] as int);
              },
            ),
          ),
      ],
    ),
  );
}

// ─── Unread Divider ("Pesan Baru") ───────────────────────────────────────────
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Divider(color: Colors.indigo.shade200, thickness: 1)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 12,
                color: Colors.indigo.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                'Pesan baru',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.indigo.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Divider(color: Colors.indigo.shade200, thickness: 1)),
      ],
    ),
  );
}

// ─── Date Separator (seperti WhatsApp) ───────────────────────────────────────
/// Tampilkan label tanggal di antara pesan dari hari yang berbeda.
/// Format: "Hari ini", "Kemarin", atau "20 Apr 2025"
class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Hari ini';
    if (d == yesterday) return 'Kemarin';

    // Kalau tahun sama, tidak perlu tampilkan tahun
    if (d.year == today.year) {
      return DateFormat('d MMM', 'id_ID').format(date);
    }
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          // Latar gelap transparan ala WhatsApp
          color: const Color(0xFF1A237E).withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.indigo.shade700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ),
  );
}

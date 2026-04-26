import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;
import '../models/chat_message.dart';
import '../utils/file_utils.dart';
import '../widgets/chat_dialogs.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';

sealed class _ListItem {}

class _ItemDate extends _ListItem {
  final DateTime date;
  _ItemDate(this.date);
}

class _ItemUnread extends _ListItem {}

class _ItemMessage extends _ListItem {
  final ChatMessage msg;
  _ItemMessage(this.msg);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  List<_ListItem> _listItems = [];
  List<ChatMessage> _pinnedMessages = [];
  List _members = [];

  final Set<int> _seenIds = {};
  int? _lastSeenIdBeforeOpen;
  bool _unreadDividerVisible = false;

  /// Indeks di [_listItems]
  /// -1 = tidak ada.
  int _unreadDividerIndex = -1;

  Timer? _timer;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isFirstLoad = true;
  String? _token;
  int? _myId;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final token = await _storage.read(key: 'auth_token');
    final uid = await _storage.read(key: 'user_id');
    if (!mounted) return;
    setState(() {
      _token = token;
      _myId = uid != null ? int.tryParse(uid) : null;
    });
    if (_token != null) {
      await _fetchChats(isInit: true);
      _fetchMembers();
      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchChats(),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  ///   1. [_ItemDate]   setiap kali tanggal berubah antar pesan
  ///   2. [_ItemUnread] tepat sebelum pesan pertama yang belum dibaca
  List<_ListItem> _buildListItems(
    List<ChatMessage> messages,
    int? lastSeenId,
    bool showUnread,
  ) {
    final items = <_ListItem>[];
    DateTime? lastDate;
    bool unreadInserted = false;
    int lastSeenMsgIndex = -1;
    if (lastSeenId != null) {
      lastSeenMsgIndex = messages.indexWhere((m) => m.id == lastSeenId);
    }

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime.parse(msg.createdAt).toLocal();
      final msgDay = DateTime(msgDate.year, msgDate.month, msgDate.day);
      if (lastDate == null || msgDay != lastDate) {
        items.add(_ItemDate(msgDay));
        lastDate = msgDay;
      }
      if (showUnread &&
          !unreadInserted &&
          lastSeenMsgIndex >= 0 &&
          i == lastSeenMsgIndex + 1) {
        items.add(_ItemUnread());
        unreadInserted = true;
      }

      items.add(_ItemMessage(msg));
    }

    return items;
  }

  Future<void> _fetchChats({bool isInit = false}) async {
    if (_token == null || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;
      if (res.statusCode != 200) return;

      final rawList = json.decode(res.body) as List;
      final all = rawList
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      final wasAtBottom =
          _scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 80;
      if (isInit && _myId != null) {
        int? lastSeen;
        for (final m in all) {
          if (m.userId == _myId) {
            lastSeen = m.id;
            _seenIds.add(m.id);
          }
        }
        _lastSeenIdBeforeOpen = lastSeen;
        if (_lastSeenIdBeforeOpen != null) {
          final lastIdx = all.indexWhere((m) => m.id == _lastSeenIdBeforeOpen);
          _unreadDividerVisible = lastIdx >= 0 && lastIdx < all.length - 1;
        } else {
          _unreadDividerVisible = all.isNotEmpty;
        }
      }

      final items = _buildListItems(
        all,
        _lastSeenIdBeforeOpen,
        _unreadDividerVisible,
      );
      _unreadDividerIndex = items.indexWhere((item) => item is _ItemUnread);

      setState(() {
        _messages = all;
        _listItems = items;
        _pinnedMessages = all.where((m) => m.isPinned).toList();
        _isLoading = false;
      });

      if (_isFirstLoad) {
        _isFirstLoad = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToFirstUnread(),
        );
      } else if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMembers() async {
    if (_token == null || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/users'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (mounted && res.statusCode == 200) {
        setState(() => _members = json.decode(res.body) as List);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty || _token == null) return;
    final parentId = _replyingTo?.id;
    _msgCtrl.clear();
    setState(() {
      _replyingTo = null;
      _unreadDividerVisible = false;
    });
    try {
      final res = await http.post(
        Uri.parse('${Api.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'message': msg,
          'type': 'text',
          if (parentId != null) 'parent_id': parentId,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        await _fetchChats();
        _scrollToBottom();
      } else {
        _snack('Gagal kirim pesan (${res.statusCode})', err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _deleteMessage(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('${Api.baseUrl}/api/chats/$id'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _fetchChats();
        _snack('Pesan dihapus');
      } else {
        _snack('Gagal hapus pesan', err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _editMessage(int id, String text) async {
    if (text.isEmpty) return;
    try {
      final res = await http.put(
        Uri.parse('${Api.baseUrl}/api/chats/$id'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'message': text}),
      );
      if (res.statusCode == 200) {
        _fetchChats();
        _snack('Pesan diperbarui');
      } else {
        _snack('Gagal edit pesan', err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _pinMessage(int id, bool pin) async {
    try {
      final res = await http.post(
        Uri.parse('${Api.baseUrl}/api/chats/$id/${pin ? 'pin' : 'unpin'}'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        _fetchChats();
        _snack(pin ? 'Pesan dipin' : 'Pin dihapus');
      } else {
        _snack('Gagal', err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    }
  }

  Future<void> _showSeenBy(int id) async {
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/chats/$id/seen'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (!mounted || res.statusCode != 200) return;
      final data = json.decode(res.body);
      final seenBy = data is List ? data : (data['seen_by'] ?? []);
      showDialog(
        context: context,
        builder: (_) => SeenByDialog(seenBy: seenBy),
      );
    } catch (_) {
      _snack('Gagal memuat data', err: true);
    }
  }

  Future<void> _markSeen(int id) async {
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);
    if (_unreadDividerVisible && mounted) {
      setState(() => _unreadDividerVisible = false);
    }

    try {
      await http.post(
        Uri.parse('${Api.baseUrl}/api/chats/$id/seen'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
    } catch (_) {
      _seenIds.remove(id);
    }
  }

  void _scrollToFirstUnread() {
    if (!_scrollCtrl.hasClients) return;

    if (!_unreadDividerVisible || _unreadDividerIndex < 0) {
      _scrollToBottom(animate: false);
      return;
    }
    final estimatedOffset = (_unreadDividerIndex * 80.0).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );

    _scrollCtrl.jumpTo(estimatedOffset);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  void _jumpTo(int msgId) {
    final idx = _listItems.indexWhere(
      (item) => item is _ItemMessage && item.msg.id == msgId,
    );
    if (idx == -1) return;
    _scrollCtrl.animateTo(
      (idx * 80.0).clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutQuart,
    );
  }

  Future<void> _pickMedia(String type) async {
    if (type == 'image') {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (f != null) _upload(File(f.path), 'image');
    } else if (type == 'video') {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f != null) _upload(File(f.path), 'video');
    } else if (type == 'audio') {
      final r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r != null) _upload(File(r.files.single.path!), 'audio');
    } else if (type == 'file') {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'csv',
          'txt',
          'ppt',
          'pptx',
          'zip',
        ],
      );
      if (r != null) _upload(File(r.files.single.path!), 'file');
    }
  }

  Future<void> _upload(File file, String type) async {
    if (mounted) setState(() => _isUploading = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/chats'),
      );
      req.headers.addAll({
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });
      req.fields['type'] = type;
      if (_msgCtrl.text.trim().isNotEmpty)
        req.fields['message'] = _msgCtrl.text.trim();
      if (_replyingTo != null)
        req.fields['parent_id'] = _replyingTo!.id.toString();
      req.files.add(await http.MultipartFile.fromPath('file', file.path));

      final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)),
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        _msgCtrl.clear();
        setState(() {
          _replyingTo = null;
          _unreadDividerVisible = false;
        });
        await _fetchChats();
        _scrollToBottom();
      } else {
        _snack('Gagal upload: ${res.statusCode}', err: true);
      }
    } on TimeoutException {
      _snack('Koneksi timeout, coba lagi.', err: true);
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showContextMenu(ChatMessage chat) {
    final isMe = chat.userId == _myId;
    final isPinned = chat.isPinned;
    final fileUrl = (chat.filePath != null && chat.filePath!.isNotEmpty)
        ? buildFileUrl(chat.filePath!)
        : '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (chat.message != null && chat.message!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chat.message!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            _menuTile(Icons.reply_rounded, 'Balas', Colors.indigo, () {
              Navigator.pop(context);
              setState(() => _replyingTo = chat);
            }),
            if (chat.message != null && chat.message!.isNotEmpty)
              _menuTile(Icons.copy_rounded, 'Salin Teks', Colors.teal, () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: chat.message!));
                _snack('Teks disalin');
              }),
            if (fileUrl.isNotEmpty)
              _menuTile(
                Icons.link_rounded,
                'Salin Link File',
                Colors.orange,
                () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: fileUrl));
                  _snack('Link disalin');
                },
              ),
            _menuTile(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              isPinned ? 'Hapus Pin' : 'Pin Pesan',
              Colors.purple,
              () {
                Navigator.pop(context);
                _pinMessage(chat.id, !isPinned);
              },
            ),
            _menuTile(
              Icons.done_all_rounded,
              'Siapa yang Lihat',
              Colors.blue,
              () {
                Navigator.pop(context);
                _showSeenBy(chat.id);
              },
            ),
            if (isMe && chat.type == 'text')
              _menuTile(
                Icons.edit_rounded,
                'Edit Pesan',
                Colors.amber.shade700,
                () async {
                  Navigator.pop(context);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        EditMessageDialog(initialText: chat.message ?? ''),
                  );
                  if (result != null && result.isNotEmpty)
                    _editMessage(chat.id, result);
                },
              ),
            if (isMe)
              _menuTile(Icons.delete_rounded, 'Hapus Pesan', Colors.red, () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Hapus Pesan'),
                    content: const Text('Yakin ingin menghapus pesan ini?'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteMessage(chat.id);
                        },
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => ListTile(
    dense: true,
    leading: Icon(icon, color: color, size: 22),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    onTap: onTap,
  );

  void _showPinnedSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: PinnedSheet(
          pinnedMessages: _pinnedMessages.map((m) => m.toJson()).toList(),
          onUnpin: (id) => _pinMessage(id, false),
          onJump: (id) => _jumpTo(id),
        ),
      ),
    ),
  );

  void _showPicker() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AttachmentPicker(onPick: _pickMedia),
  );

  void _showMembers() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.people, color: Colors.indigo),
          SizedBox(width: 10),
          Text('Anggota Jonusa'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: double.maxFinite,
        child: _members.isEmpty
            ? const Center(child: Text('Memuat...'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final u = _members[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        u['name'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      u['name'] + (u['id'] == _myId ? ' (Anda)' : ''),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      u['email'] ?? '-',
                      style: const TextStyle(fontSize: 11),
                    ),
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
    ),
  );
  Widget _buildListItem(int i) {
    final item = _listItems[i];

    if (item is _ItemDate) {
      return DateSeparator(date: item.date);
    }

    if (item is _ItemUnread) {
      return _unreadDividerVisible
          ? const UnreadDivider()
          : const SizedBox.shrink();
    }

    final chat = (item as _ItemMessage).msg;
    Future.microtask(() => _markSeen(chat.id));

    final isMe = chat.userId == _myId;
    return GestureDetector(
      onLongPress: () => _showContextMenu(chat),
      child: MessageBubble(
        chat: chat,
        isMe: isMe,
        token: _token,
        onJumpToParent: _jumpTo,
        onSeenByTap: () => _showSeenBy(chat.id),
      ),
    );
  }

  // Build
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4FF),
    appBar: AppBar(
      title: GestureDetector(
        onTap: _showMembers,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chat Internal Jonusa',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _members.isEmpty ? 'Memuat...' : '${_members.length} anggota',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        if (_pinnedMessages.isNotEmpty)
          IconButton(
            icon: const Icon(
              Icons.push_pin_rounded,
              color: Colors.indigo,
              size: 20,
            ),
            onPressed: _showPinnedSheet,
          ),
      ],
    ),
    body: Column(
      children: [
        if (_isUploading)
          const LinearProgressIndicator(
            color: Colors.indigo,
            backgroundColor: Color(0xFFE8EAF6),
          ),
        PinnedBar(
          pinnedMessages: _pinnedMessages.map((m) => m.toJson()).toList(),
          onTap: _showPinnedSheet,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchChats,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    itemCount: _listItems.length,
                    itemBuilder: (_, i) => _buildListItem(i),
                  ),
                ),
        ),
        ChatInput(
          controller: _msgCtrl,
          replyingTo: _replyingTo?.toJson(),
          onSend: _sendMessage,
          onPickerTap: _showPicker,
          onCancelReply: () => setState(() => _replyingTo = null),
        ),
      ],
    ),
  );

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 13)),
          backgroundColor: err ? Colors.red.shade700 : Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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

final Map<String, Uint8List> _imageCache = {};
String buildFileUrl(String filePath) {
  final base = Api.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
  var path = filePath.trim().replaceAll(RegExp(r'^/'), '');
  path = path.replaceFirst(RegExp(r'^storage/'), '');
  return '$base/$path';
}

class _FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? token;
  const _FullscreenImageViewer({required this.imageUrl, this.token});
  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl;
    if (_imageCache.containsKey(url)) {
      if (mounted)
        setState(() {
          _bytes = _imageCache[url];
          _loading = false;
        });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        _imageCache[url] = res.bodyBytes;
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () async {
            final uri = Uri.parse(widget.imageUrl);
            if (await canLaunchUrl(uri))
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
    body: Center(
      child: _loading
          ? const CircularProgressIndicator(color: Colors.white)
          : _error || _bytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey, size: 64),
                TextButton(
                  onPressed: _loadImage,
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : InteractiveViewer(
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
    ),
  );
}

class _ImageBubble extends StatefulWidget {
  final String fileUrl;
  final VoidCallback onTap;
  final String? token;
  const _ImageBubble({
    super.key,
    required this.fileUrl,
    required this.onTap,
    this.token,
  });
  @override
  State<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<_ImageBubble> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final url = widget.fileUrl;
    if (_imageCache.containsKey(url)) {
      if (mounted)
        setState(() {
          _bytes = _imageCache[url];
          _loading = false;
        });
      return;
    }
    if (mounted)
      setState(() {
        _loading = true;
        _error = false;
      });
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        _imageCache[url] = res.bodyBytes;
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    if (_error || _bytes == null)
      return GestureDetector(
        onTap: _loadImage,
        child: Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 32),
              SizedBox(height: 4),
              Text(
                'Ketuk untuk muat ulang',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(_bytes!, width: 220, fit: BoxFit.cover),
      ),
    );
  }
}

class _VideoBubble extends StatefulWidget {
  final String url;
  const _VideoBubble({required this.url});
  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await for (final response in DefaultCacheManager().getFileStream(
        widget.url,
        key: widget.url,
        withProgress: true,
      )) {
        if (response is FileInfo) {
          _ctrl = VideoPlayerController.file(response.file);
          await _ctrl!.initialize();
          if (mounted)
            setState(() {
              _initialized = true;
              _isLoading = false;
            });
        }
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return _placeholder(
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    if (_hasError || _ctrl == null)
      return GestureDetector(
        onTap: _launch,
        child: _placeholder(
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 32,
              ),
              SizedBox(height: 4),
              Text(
                'Gagal memuat video',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    return GestureDetector(
      onTap: () {
        if (!_initialized) return;
        setState(() {
          _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: VideoPlayer(_ctrl!),
              ),
              if (!_ctrl!.value.isPlaying)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _ctrl!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.indigo,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder({required Widget child}) => Container(
    width: 220,
    height: 140,
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(child: child),
  );

  Future<void> _launch() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _FileBubble extends StatelessWidget {
  final String filePath;
  final bool isMe;
  final VoidCallback onTap;
  const _FileBubble({
    required this.filePath,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fileIcon(detectFileKind(filePath)),
            color: isMe ? Colors.white70 : Colors.indigo,
            size: 28,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(filePath),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ketuk untuk membuka',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AudioBubble extends StatelessWidget {
  final bool isMe;
  final VoidCallback onOpenExternal;
  const _AudioBubble({required this.isMe, required this.onOpenExternal});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onOpenExternal,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.audiotrack_rounded,
            color: isMe ? Colors.white70 : const Color(0xFF6A1B9A),
            size: 28,
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
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Ketuk untuk membuka',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white60 : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SeenByDialog extends StatelessWidget {
  final List seenBy;
  const _SeenByDialog({required this.seenBy});

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

class _PinnedBar extends StatelessWidget {
  final List pinnedMessages;
  final VoidCallback onTap;
  const _PinnedBar({required this.pinnedMessages, required this.onTap});

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

class _PinnedSheet extends StatelessWidget {
  final List pinnedMessages;
  final Function(int) onUnpin;
  final Function(int) onJump;
  const _PinnedSheet({
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
          ...pinnedMessages
              .map(
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
                      style: const TextStyle(
                        color: Colors.indigo,
                        fontSize: 12,
                      ),
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
                      onUnpin(msg['id']);
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onJump(msg['id']);
                  },
                ),
              )
              .toList(),
      ],
    ),
  );
}

class _EditDialog extends StatefulWidget {
  final String initialText;
  const _EditDialog({required this.initialText});
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late TextEditingController _ctrl;
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

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  List _messages = [];
  List _members = [];
  List _pinnedMessages = [];
  final Set<int> _seenIds = {};
  int? _lastSeenId;
  bool _unreadDividerVisible = false;

  Timer? _timer;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isFirstLoad = true;
  String? _token;
  int? _myId;
  Map? _replyingTo;

  @override
  void initState() {
    super.initState();
    _init();
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

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
        setState(() => _members = json.decode(res.body));
      }
    } catch (_) {}
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
      if (res.statusCode == 200) {
        final all = json.decode(res.body) as List;

        final wasAtBottom =
            _scrollCtrl.hasClients &&
            _scrollCtrl.position.pixels >=
                _scrollCtrl.position.maxScrollExtent - 80;
        if (isInit && _myId != null) {
          int? lastSeen;
          for (final m in all) {
            final msgId = m['id'] as int;
            final userId = m['user_id'];
            if (userId == _myId) {
              lastSeen = msgId;
              _seenIds.add(msgId);
            }
          }
          _lastSeenId = lastSeen;
          if (_lastSeenId != null) {
            final lastIdx = all.indexWhere((m) => m['id'] == _lastSeenId);
            _unreadDividerVisible = lastIdx >= 0 && lastIdx < all.length - 1;
          }
        }

        setState(() {
          _messages = all;
          _pinnedMessages = all
              .where((m) => m['is_pinned'] == true || m['is_pinned'] == 1)
              .toList();
          _isLoading = false;
        });

        if (_isFirstLoad) {
          _isFirstLoad = false;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToFirstUnread(),
          );
        } else if (wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToFirstUnread() {
    if (!_scrollCtrl.hasClients) return;

    if (!_unreadDividerVisible || _lastSeenId == null) {
      _scrollToBottom(animate: false);
      return;
    }

    final lastIdx = _messages.indexWhere((m) => m['id'] == _lastSeenId);
    if (lastIdx < 0 || lastIdx >= _messages.length - 1) {
      _scrollToBottom(animate: false);
      return;
    }
    final estimatedOffset = ((lastIdx + 1) * 72.0).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );
    _scrollCtrl.jumpTo(estimatedOffset);
  }

  Future<void> _sendMessage() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty || _token == null) return;
    final parentId = _replyingTo?['id'];
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
      } else
        _snack('Gagal hapus pesan', err: true);
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
      } else
        _snack('Gagal edit pesan', err: true);
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
      } else
        _snack('Gagal', err: true);
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
        builder: (_) => _SeenByDialog(seenBy: seenBy),
      );
    } catch (_) {
      _snack('Gagal memuat data', err: true);
    }
  }

  Future<void> _markSeen(int id) async {
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);
    if (_unreadDividerVisible && _lastSeenId != null) {
      final msgIdx = _messages.indexWhere((m) => m['id'] == id);
      final lastIdx = _messages.indexWhere((m) => m['id'] == _lastSeenId);
      if (msgIdx > lastIdx && mounted) {
        setState(() => _unreadDividerVisible = false);
      }
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

  void _showContextMenu(Map chat) {
    final isMe = chat['user_id'] == _myId;
    final isPinned = chat['is_pinned'] == true || chat['is_pinned'] == 1;
    final fileUrl =
        (chat['file_path'] != null && (chat['file_path'] as String).isNotEmpty)
        ? buildFileUrl(chat['file_path'])
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
            if (chat['message'] != null &&
                (chat['message'] as String).isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chat['message'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            _tile(Icons.reply_rounded, 'Balas', Colors.indigo, () {
              Navigator.pop(context);
              setState(() => _replyingTo = chat);
            }),
            if (chat['message'] != null &&
                (chat['message'] as String).isNotEmpty)
              _tile(Icons.copy_rounded, 'Salin Teks', Colors.teal, () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: chat['message']));
                _snack('Teks disalin');
              }),
            if (fileUrl.isNotEmpty)
              _tile(Icons.link_rounded, 'Salin Link File', Colors.orange, () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: fileUrl));
                _snack('Link disalin');
              }),
            _tile(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              isPinned ? 'Hapus Pin' : 'Pin Pesan',
              Colors.purple,
              () {
                Navigator.pop(context);
                _pinMessage(chat['id'], !isPinned);
              },
            ),
            _tile(Icons.done_all_rounded, 'Siapa yang Lihat', Colors.blue, () {
              Navigator.pop(context);
              _showSeenBy(chat['id']);
            }),
            if (isMe && chat['type'] == 'text')
              _tile(
                Icons.edit_rounded,
                'Edit Pesan',
                Colors.amber.shade700,
                () async {
                  Navigator.pop(context);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        _EditDialog(initialText: chat['message'] ?? ''),
                  );
                  if (result != null && result.isNotEmpty)
                    _editMessage(chat['id'], result);
                },
              ),
            if (isMe)
              _tile(Icons.delete_rounded, 'Hapus Pesan', Colors.red, () {
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
                          _deleteMessage(chat['id']);
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

  Widget _tile(IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: onTap,
      );

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
        req.fields['parent_id'] = _replyingTo!['id'].toString();
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

  void _jumpTo(int msgId) {
    final idx = _messages.indexWhere((m) => m['id'] == msgId);
    if (idx == -1) return;
    _scrollCtrl.animateTo(
      (idx * 80.0).clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutQuart,
    );
  }

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
        child: _PinnedSheet(
          pinnedMessages: _pinnedMessages,
          onUnpin: (id) => _pinMessage(id, false),
          onJump: (id) => _jumpTo(id),
        ),
      ),
    ),
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

  Widget _buildUnreadDivider() => Container(
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
  int _itemCount() {
    if (_unreadDividerVisible && _lastSeenId != null) {
      final lastIdx = _messages.indexWhere((m) => m['id'] == _lastSeenId);
      if (lastIdx >= 0 && lastIdx < _messages.length - 1) {
        return _messages.length + 1;
      }
    }
    return _messages.length;
  }

  Widget _buildListItem(int i) {
    if (_unreadDividerVisible && _lastSeenId != null) {
      final lastIdx = _messages.indexWhere((m) => m['id'] == _lastSeenId);
      final dividerIndex = lastIdx + 1;
      if (lastIdx >= 0 && lastIdx < _messages.length - 1) {
        if (i == dividerIndex) return _buildUnreadDivider();
        final realIndex = i > dividerIndex ? i - 1 : i;
        final chat = _messages[realIndex];
        Future.microtask(() => _markSeen(chat['id'] as int));
        return GestureDetector(
          onLongPress: () => _showContextMenu(chat),
          child: _buildBubble(chat, chat['user_id'] == _myId),
        );
      }
    }
    final chat = _messages[i];
    Future.microtask(() => _markSeen(chat['id'] as int));
    return GestureDetector(
      onLongPress: () => _showContextMenu(chat),
      child: _buildBubble(chat, chat['user_id'] == _myId),
    );
  }

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
        _PinnedBar(pinnedMessages: _pinnedMessages, onTap: _showPinnedSheet),
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
                    itemCount: _itemCount(),
                    itemBuilder: (_, i) => _buildListItem(i),
                  ),
                ),
        ),
        _buildInput(),
      ],
    ),
  );

  Widget _buildBubble(dynamic chat, bool isMe) {
    final type = chat['type'] as String? ?? 'text';
    final filePath = chat['file_path'] as String?;
    final fileUrl = (filePath != null && filePath.isNotEmpty)
        ? buildFileUrl(filePath)
        : '';
    final isPinned = chat['is_pinned'] == true || chat['is_pinned'] == 1;
    final isEdited = chat['is_edited'] == true || chat['is_edited'] == 1;
    final seenCount = (chat['seen_by_count'] ?? 0) as int;
    final hasOtherSeen = isMe && seenCount > 0;

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
                chat['user']?['name'] ?? '',
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
                  type == 'image' || type == 'video' ? 5 : 10,
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
                    if (isPinned)
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
                    if (chat['parent'] != null)
                      GestureDetector(
                        onTap: () => _jumpTo(chat['parent_id']),
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
                                chat['parent']['user']['name'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white : Colors.indigo,
                                ),
                              ),
                              Text(
                                chat['parent']['message']?.isNotEmpty == true
                                    ? chat['parent']['message']
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
                    if (type == 'image' && fileUrl.isNotEmpty)
                      _ImageBubble(
                        key: ValueKey(fileUrl),
                        fileUrl: fileUrl,
                        token: _token,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullscreenImageViewer(
                              imageUrl: fileUrl,
                              token: _token,
                            ),
                          ),
                        ),
                      ),
                    if (type == 'video' && fileUrl.isNotEmpty)
                      _VideoBubble(url: fileUrl),
                    if ((type == 'audio' || type == 'voice') &&
                        fileUrl.isNotEmpty)
                      _AudioBubble(
                        isMe: isMe,
                        onOpenExternal: () async {
                          final uri = Uri.parse(fileUrl);
                          if (await canLaunchUrl(uri))
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                        },
                      ),
                    if (type == 'file' && filePath != null)
                      _FileBubble(
                        filePath: filePath,
                        isMe: isMe,
                        onTap: () async {
                          final uri = Uri.parse(fileUrl);
                          if (await canLaunchUrl(uri))
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                        },
                      ),
                    if (chat['message'] != null &&
                        (chat['message'] as String).isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: type != 'text' ? 6 : 0),
                        child: Text(
                          chat['message'],
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
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (isPinned) ...[
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
                  ).format(DateTime.parse(chat['created_at']).toLocal()),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isEdited)
                  const Text(
                    ' · diedit',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showSeenBy(chat['id']),
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

  Widget _buildInput() => Container(
    color: Colors.white,
    child: Column(
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF3F4FF),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Membalas ${_replyingTo!['user']['name']}',
                    style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ],
            ),
          ),
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
                onPressed: _showPicker,
              ),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  maxLines: null,
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
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showPicker() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
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
              _attach(
                Icons.image_rounded,
                'Gambar',
                const Color(0xFF7C4DFF),
                () {
                  Navigator.pop(context);
                  _pickMedia('image');
                },
              ),
              _attach(
                Icons.videocam_rounded,
                'Video',
                const Color(0xFFE53935),
                () {
                  Navigator.pop(context);
                  _pickMedia('video');
                },
              ),
              _attach(
                Icons.audiotrack_rounded,
                'Audio',
                const Color(0xFF6A1B9A),
                () {
                  Navigator.pop(context);
                  _pickMedia('audio');
                },
              ),
              _attach(
                Icons.folder_rounded,
                'Dokumen',
                const Color(0xFF1565C0),
                () {
                  Navigator.pop(context);
                  _pickMedia('file');
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _attach(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
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

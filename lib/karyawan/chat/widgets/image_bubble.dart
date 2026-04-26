import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/image_cache_manager.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? token;
  const FullscreenImageViewer({super.key, required this.imageUrl, this.token});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl;
    if (AppImageCache.has(url)) {
      if (mounted)
        setState(() {
          _bytes = AppImageCache.get(url);
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
        AppImageCache.set(url, res.bodyBytes);
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
    } catch (e) {
      debugPrint('FullscreenImage load error: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  Future<void> _saveImage() async {
    if (_bytes == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = Uri.parse(widget.imageUrl).pathSegments.last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(_bytes!);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
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
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simpan: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Foto',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      actions: [
        if (_bytes != null)
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isSaved
                        ? Icons.download_done_rounded
                        : Icons.download_rounded,
                    color: _isSaved ? Colors.greenAccent : Colors.white,
                  ),
                  tooltip: 'Simpan Foto',
                  onPressed: _saveImage,
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
                const SizedBox(height: 12),
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
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
    ),
  );
}

class ImageBubble extends StatefulWidget {
  final String fileUrl;
  final VoidCallback onTap;
  final String? token;
  const ImageBubble({
    super.key,
    required this.fileUrl,
    required this.onTap,
    this.token,
  });

  @override
  State<ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<ImageBubble> {
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
    if (AppImageCache.has(url)) {
      if (mounted)
        setState(() {
          _bytes = AppImageCache.get(url);
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
        AppImageCache.set(url, res.bodyBytes);
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        debugPrint('ImageBubble HTTP ${res.statusCode} for $url');
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (e) {
      debugPrint('ImageBubble load error: $e');
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
      return _box(child: const CircularProgressIndicator(strokeWidth: 2));
    if (_error || _bytes == null)
      return GestureDetector(
        onTap: _loadImage,
        child: _box(
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

  Widget _box({required Widget child}) => Container(
    width: 220,
    height: 160,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(child: child),
  );
}

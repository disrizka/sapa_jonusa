// widgets/video_bubble.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// ─── Fullscreen Video Player ─────────────────────────────────────────────────
class FullscreenVideoPlayer extends StatefulWidget {
  final String url;
  final String? token;
  const FullscreenVideoPlayer({super.key, required this.url, this.token});

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: {
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      );
      await _ctrl!.initialize();
      _ctrl!.setLooping(false);
      _ctrl!.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('FullscreenVideoPlayer init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final res = await http
          .get(
            Uri.parse(widget.url),
            headers: {
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 120));

      final dir = await getApplicationDocumentsDirectory();
      final fileName = Uri.parse(widget.url).pathSegments.last;
      final destFile = File('${dir.path}/$fileName');
      await destFile.writeAsBytes(res.bodyBytes);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tersimpan: ${destFile.path}'),
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
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal download: $e'),
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
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Video',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      actions: [
        _isDownloading
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
                  _isDownloaded
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                  color: _isDownloaded ? Colors.greenAccent : Colors.white,
                ),
                tooltip: 'Simpan Video',
                onPressed: _downloadVideo,
              ),
      ],
    ),
    body: _hasError
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat video',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _initialized = false;
                    });
                    _ctrl?.dispose();
                    _ctrl = null;
                    _initVideo();
                  },
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        : !_initialized
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : GestureDetector(
            onTap: () => setState(() {
              _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
            }),
            child: Center(
              child: AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_ctrl!),
                    if (!_ctrl!.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 56,
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

// ─── Video Bubble (thumbnail in chat) ────────────────────────────────────────
class VideoBubble extends StatefulWidget {
  final String url;
  final String? token;
  const VideoBubble({super.key, required this.url, this.token});

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
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
      // Langsung pakai networkUrl — tidak pakai flutter_cache_manager
      // supaya http://10.0.2.2 (emulator localhost) bisa diakses
      _ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: {
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      );
      await _ctrl!.initialize();
      if (mounted)
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('VideoBubble init error: $e');
      if (mounted)
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _initialized = false;
    });
    _ctrl?.dispose();
    _ctrl = null;
    _initializeVideo();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    _ctrl?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullscreenVideoPlayer(url: widget.url, token: widget.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _placeholder(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Memuat video...',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (_hasError || _ctrl == null) {
      return GestureDetector(
        onTap: _retry,
        child: _placeholder(
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white70, size: 32),
              SizedBox(height: 6),
              Text(
                'Gagal memuat\nKetuk untuk retry',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _openFullscreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 220),
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: VideoPlayer(_ctrl!),
              ),
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
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white70,
                    size: 16,
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
}

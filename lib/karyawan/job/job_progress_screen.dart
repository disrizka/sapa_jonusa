import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0D47A1);
const _kBg = Color(0xFFF8FAFC);
const _kText = Color(0xFF1E293B);
const _kSub = Color(0xFF64748B);
const _kGreen = Color(0xFF10B981);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kOrange = Color(0xFFF97316);

class JobProgressScreen extends StatefulWidget {
  final Job job;
  const JobProgressScreen({super.key, required this.job});

  @override
  State<JobProgressScreen> createState() => _JobProgressScreenState();
}

class _JobProgressScreenState extends State<JobProgressScreen> {
  late Job _job;
  final _descCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  File? _photo;
  File? _video;
  final _picker = ImagePicker();
  bool _sendingComment = false;
  bool _uploading = false;
  bool _isLoadingUser = true;

  String _currentUserId = '';
  String _currentUserName = '';

  // ── Timer fields ────────────────────────────────────────────────────────
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _acceptedAt;
  bool _isOverdue = false;
  String? _overdueLabel;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _loadCurrentUser();
    _initTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _initTimer() {
    // Mulai timer jika job sedang process
    if (_job.isProcess || _job.isCompleted) {
      // accepted_at dari API — fallback ke created_at jika null
      final acceptedStr = _job.acceptedAt ?? _job.createdAt;
      if (acceptedStr != null) {
        try {
          _acceptedAt = DateTime.parse(acceptedStr);
        } catch (_) {}
      }

      if (!_job.isCompleted) {
        _elapsed = _acceptedAt != null
            ? DateTime.now().difference(_acceptedAt!)
            : Duration.zero;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _elapsed = _acceptedAt != null
                  ? DateTime.now().difference(_acceptedAt!)
                  : _elapsed + const Duration(seconds: 1);
              _checkOverdue();
            });
          }
        });
      } else {
        // Completed — hitung total waktu pengerjaan
        if (_acceptedAt != null && _job.completedAt != null) {
          try {
            final completedAt = DateTime.parse(_job.completedAt!);
            _elapsed = completedAt.difference(_acceptedAt!);
          } catch (_) {}
        }
      }
      _checkOverdue();
    }
  }

  void _checkOverdue() {
    if (_job.endTime == null) return;
    try {
      final deadline = DateTime.parse(_job.endTime!);
      final now = _job.isCompleted && _job.completedAt != null
          ? DateTime.parse(_job.completedAt!)
          : DateTime.now();
      _isOverdue = now.isAfter(deadline);

      if (_isOverdue) {
        final over = now.difference(deadline);
        _overdueLabel = '⚠ Melebihi estimasi ${_formatDuration(over)}';
      } else {
        final remaining = deadline.difference(now);
        _overdueLabel = '✓ Sisa waktu ${_formatDuration(remaining)}';
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}j ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatElapsed() => _formatDuration(_elapsed);

  // ── Load user ────────────────────────────────────────────────────────────
  Future<void> _loadCurrentUser() async {
    try {
      final allData = await _storage.readAll();
      for (final entry in allData.entries) {
        try {
          final data = jsonDecode(entry.value);
          if (data is Map && data['id'] != null) {
            setState(() {
              _currentUserId = data['id'].toString();
              _currentUserName = data['name']?.toString() ?? '';
              _isLoadingUser = false;
            });
            return;
          }
        } catch (_) {}
      }
      final idStr = await _storage.read(key: 'user_id');
      if (idStr != null) {
        setState(() {
          _currentUserId = idStr;
          _isLoadingUser = false;
        });
      } else {
        setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  bool get _isMyJob {
    if (_isLoadingUser) return false;
    final String jobTechId = (_job.technicianId ?? _job.technician?['id'] ?? '')
        .toString();
    if (_currentUserId.isNotEmpty && jobTechId.isNotEmpty) {
      if (_currentUserId == jobTechId) return true;
    }
    final String techName = (_job.technician?['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String myName = _currentUserName.trim().toLowerCase();
    if (techName.isNotEmpty && myName.isNotEmpty && techName == myName)
      return true;
    return false;
  }

  // ── Submit komentar ──────────────────────────────────────────────────────
  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final newComment = await JobService.addComment(
        jobId: _job.id,
        comment: text,
      );
      if (mounted) {
        setState(() {
          _job = Job(
            id: _job.id,
            title: _job.title,
            description: _job.description,
            status: _job.status,
            currentStep: _job.currentStep,
            feedback: _job.feedback,
            cs: _job.cs,
            technician: _job.technician,
            technicianId: _job.technicianId,
            trackers: _job.trackers,
            comments: [newComment, ..._job.comments],
            createdAt: _job.createdAt,
            clientName: _job.clientName,
            location: _job.location,
            latitude: _job.latitude,
            longitude: _job.longitude,
            startTime: _job.startTime,
            endTime: _job.endTime,
            acceptedAt: _job.acceptedAt,
            completedAt: _job.completedAt,
            actualDuration: _job.actualDuration,
            completionReason: _job.completionReason,
          );
          _commentCtrl.clear();
          _sendingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _refreshJob() async {
    try {
      final updatedJob = await JobService.getJobDetail(_job.id);
      if (mounted) {
        _timer?.cancel();
        setState(() => _job = updatedJob);
        _initTimer();
      }
    } catch (e) {
      debugPrint('Refresh gagal: $e');
    }
  }

  // ── Submit progress ──────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_uploading) return;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi deskripsi dulu!'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon tambahkan bukti foto!'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }

    // Step terakhir — minta alasan sebelum selesai
    final isLastStep = (_job.currentStep ?? 1) >= 4;
    if (isLastStep) {
      final shouldProceed = await _showCompletionReasonDialog();
      if (!shouldProceed) return;
    }

    setState(() => _uploading = true);
    try {
      final result = await JobService.updateProgress(
        jobId: _job.id,
        description: desc,
        photoFile: _photo,
        videoFile: _video,
        completionReason: isLastStep ? _reasonCtrl.text.trim() : null,
      );
      _timer?.cancel();
      setState(() {
        _job = result['job'];
        _uploading = false;
        _descCtrl.clear();
        _reasonCtrl.clear();
        _photo = null;
        _video = null;
      });
      _initTimer();
      if (_job.isCompleted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<bool> _showCompletionReasonDialog() async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isOverdue
                    ? _kRed.withOpacity(0.1)
                    : _kGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: _isOverdue ? _kRed : _kGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Selesaikan Tugas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status waktu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isOverdue
                    ? _kRed.withOpacity(0.08)
                    : _kGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isOverdue
                      ? _kRed.withOpacity(0.3)
                      : _kGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total waktu pengerjaan: ${_formatElapsed()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  if (_overdueLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _overdueLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOverdue ? _kRed : _kGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isOverdue
                  ? 'Tugas ini melebihi estimasi waktu. Tolong jelaskan alasannya:'
                  : 'Tugas selesai tepat waktu! Isi catatan akhir (opsional):',
              style: const TextStyle(fontSize: 13, color: _kSub),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _isOverdue
                    ? 'Contoh: Terjadi kendala teknis, peralatan rusak...'
                    : 'Contoh: Pekerjaan berjalan lancar, tidak ada kendala...',
                hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            if (_isOverdue) ...[
              const SizedBox(height: 6),
              const Text(
                '* Wajib diisi jika melewati estimasi',
                style: TextStyle(fontSize: 11, color: _kRed),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _kSub)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isOverdue ? _kOrange : _kGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (_isOverdue && _reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Harap isi alasan keterlambatan!'),
                    backgroundColor: _kRed,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── Picker ───────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kPrimary),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kPrimary),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final picked = await _picker.pickImage(source: src, imageQuality: 70);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickVideo() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: _kPrimary),
              title: const Text('Rekam Video Baru'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: _kPrimary),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final picked = await _picker.pickVideo(source: src);
    if (picked != null) setState(() => _video = File(picked.path));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCompleted = _job.status == 'completed';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kPrimary, _kAccent]),
          ),
        ),
        title: const Text(
          'Detail & Progress Tugas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshJob,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await _refreshJob(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner pemantau
              if (!_isMyJob && !isCompleted) _buildViewerBanner(),
              if (!_isMyJob && !isCompleted) const SizedBox(height: 12),

              // ── TIMER CARD (process) ────────────────────────────────────
              if (_job.isProcess || isCompleted) ...[
                _buildTimerCard(isCompleted),
                const SizedBox(height: 16),
              ],

              // Header
              _buildHeaderCard(isCompleted),
              const SizedBox(height: 24),

              // Info Klien & Lokasi
              if (_job.clientName != null || _job.location != null) ...[
                _buildClientLocationCard(),
                const SizedBox(height: 24),
              ],

              // Riwayat Pengerjaan
              const Text(
                'Riwayat Pengerjaan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              if (_job.trackers.isEmpty)
                _buildEmptyState(
                  icon: Icons.pending_actions_outlined,
                  message: 'Belum ada progress pengerjaan.',
                )
              else
                ..._job.trackers.map((t) => _buildTrackerTile(t)),

              const SizedBox(height: 24),

              // Form input progress
              if (!isCompleted && _isMyJob) ...[
                const Text(
                  'Input Progress Tahap Berikutnya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildProgressForm(),
              ],

              // Hasil akhir (completed)
              if (isCompleted && _job.completionReason != null) ...[
                const SizedBox(height: 8),
                _buildCompletionReport(),
              ],

              const SizedBox(height: 24),

              // Komentar
              const Text(
                'Diskusi & Komentar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              _buildCommentSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── TIMER CARD ────────────────────────────────────────────────────────────
  Widget _buildTimerCard(bool isCompleted) {
    final timerColor = _isOverdue ? _kRed : _kGreen;
    final bgColor = _isOverdue
        ? _kRed.withOpacity(0.08)
        : _kGreen.withOpacity(0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: timerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.task_alt : Icons.timer_outlined,
                color: timerColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted ? 'Durasi Pengerjaan' : 'Timer Pengerjaan (Live)',
                style: TextStyle(
                  fontSize: 12,
                  color: timerColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (!isCompleted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: timerColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Big timer
          Text(
            _formatElapsedClock(),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: timerColor,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (_overdueLabel != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: timerColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _overdueLabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: timerColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (_job.startTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _timeChip(
                  'Mulai',
                  _job.startTime!,
                  Icons.play_circle_outline,
                  _kPrimary,
                ),
                const SizedBox(width: 8),
                _timeChip(
                  'Target',
                  _job.endTime ?? '-',
                  Icons.flag_outlined,
                  _kAmber,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeChip(String label, String value, IconData icon, Color color) {
    String displayValue = value;
    try {
      final dt = DateTime.parse(value);
      displayValue =
          '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kText,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsedClock() {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Client & Location Card ────────────────────────────────────────────────
  Widget _buildClientLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Info Penugasan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const Divider(height: 16),
          if (_job.clientName != null)
            _infoRow(Icons.person_outline, 'Klien', _job.clientName!),
          if (_job.location != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.location_on_outlined, 'Lokasi', _job.location!),
          ],
          if (_job.latitude != null && _job.longitude != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                  'https://www.google.com/maps?q=${_job.latitude},${_job.longitude}',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: _kPrimary, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Lihat di Google Maps',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _kSub),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kSub,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: _kText),
          ),
        ),
      ],
    );
  }

  // ── Completion Report ─────────────────────────────────────────────────────
  Widget _buildCompletionReport() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOverdue
              ? [_kOrange.withOpacity(0.1), _kRed.withOpacity(0.05)]
              : [_kGreen.withOpacity(0.1), _kGreen.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isOverdue
              ? _kOrange.withOpacity(0.3)
              : _kGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                color: _isOverdue ? _kOrange : _kGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isOverdue
                    ? 'Tugas Selesai — Melebihi Estimasi'
                    : 'Tugas Selesai — Tepat Waktu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _isOverdue ? _kOrange : _kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Durasi aktual: ',
                style: TextStyle(
                  fontSize: 12,
                  color: _kSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatElapsed(),
                style: const TextStyle(
                  fontSize: 12,
                  color: _kText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_job.completionReason != null &&
              _job.completionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_outlined, size: 14, color: _kSub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _job.completionReason!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Viewer Banner ────────────────────────────────────────────────────────
  Widget _buildViewerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: _kAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Anda memantau tugas ini. Hanya '
              '${_job.technician?['name'] ?? 'teknisi yang ditunjuk'} '
              'yang dapat melanjutkan progress.',
              style: const TextStyle(
                color: _kAmber,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isCompleted) {
    final int completedSteps = isCompleted ? 4 : ((_job.currentStep ?? 1) - 1);
    final double progressVal = isCompleted
        ? 1.0
        : ((_job.currentStep ?? 1) - 1) / 4.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _job.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _job.description ?? '-',
            style: const TextStyle(fontSize: 13, color: _kSub),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                Icons.engineering_outlined,
                size: 16,
                color: _kPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Teknisi: ${_job.technician?['name'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isMyJob
                      ? _kPrimary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isMyJob ? 'Tugas Saya' : 'Pemantau',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isMyJob ? _kPrimary : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isCompleted) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tahap $completedSteps dari 4',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progressVal * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressVal,
                backgroundColor: _kPrimary.withOpacity(0.1),
                color: _kPrimary,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(4, (i) {
                final done = i < completedSteps;
                final active = !isCompleted && i == completedSteps;
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: done
                                  ? _kGreen
                                  : active
                                  ? _kPrimary.withOpacity(0.5)
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: done
                                    ? _kGreen
                                    : active
                                    ? _kPrimary
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: done
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : active
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: _kPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          if (i < 3)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: done && i < completedSteps - 1
                                    ? _kGreen
                                    : Colors.grey.shade200,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tahap ${i + 1}',
                          style: TextStyle(
                            fontSize: 9,
                            color: done
                                ? _kGreen
                                : active
                                ? _kPrimary
                                : Colors.grey.shade400,
                            fontWeight: done || active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ] else
            _buildSuccessBadge(),
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: _kGreen, size: 18),
          SizedBox(width: 8),
          Text(
            'TUGAS SELESAI',
            style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTile(JobTracker t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: _kGreen.withOpacity(0.1),
            child: Text(
              '${t.stepNumber}',
              style: const TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            'Tahap ${t.stepNumber}: ${t.descriptionValue ?? "Selesai"}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _kText,
            ),
          ),
          trailing: const Icon(Icons.check_circle, color: _kGreen, size: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 20),
                  if (t.photoUrl != null) ...[
                    const Text(
                      'Bukti Foto:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _kSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        t.photoUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (t.videoUrl != null) ...[
                    const Text(
                      'Bukti Video:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _kSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(t.videoUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_circle_fill, color: _kPrimary),
                            SizedBox(width: 12),
                            Text(
                              'Putar Video Bukti',
                              style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Text(
                    'Selesai pada: ${t.createdAt ?? "-"}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressForm() {
    final int currentStep = _job.currentStep ?? 1;
    final int nextStep = currentStep + 1;
    final isLast = currentStep >= 4;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INPUT PROGRESS TAHAP $currentStep',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Deskripsi Tahap $currentStep',
              hintText: 'Apa hasil pekerjaan di tahap ini?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _kBg,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_photo == null ? 'Foto' : '✓ Foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: Text(_video == null ? 'Video' : '✓ Video'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info overdue warning sebelum step terakhir
          if (isLast && _isOverdue)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _kRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tugas sudah melebihi estimasi waktu. Nanti kamu akan diminta mengisi alasan.',
                      style: const TextStyle(fontSize: 11, color: _kRed),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _kGreen : _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _uploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      isLast
                          ? 'Selesaikan Tugas ✓'
                          : 'Simpan & Lanjut Tahap $nextStep →',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_job.comments.isEmpty)
          _buildEmptyState(
            icon: Icons.chat_bubble_outline,
            message: 'Belum ada diskusi. Jadilah yang pertama berkomentar!',
          )
        else
          ..._job.comments.map((c) => _buildCommentBubble(c)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              _sendingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: _kPrimary),
                      onPressed: _submitComment,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentBubble(JobComment c) {
    final int myId = int.tryParse(_currentUserId) ?? 0;
    final bool isMe = c.userId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            c.userName,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[100] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(c.comment, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            c.createdAt ?? '',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

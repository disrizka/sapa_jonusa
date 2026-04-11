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
  final _storage = const FlutterSecureStorage();
  File? _photo;
  File? _video;
  final _picker = ImagePicker();
  bool _sendingComment = false;
  bool _uploading = false;
  bool _isLoadingUser = true;

  String _currentUserId = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Load user dari storage ───────────────────────────────────────────────
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

  // ── Cek apakah ini tugas saya ────────────────────────────────────────────
  bool get _isMyJob {
    if (_isLoadingUser) return false;

    final String jobTechId =
        (_job.technicianId ?? _job.technician?['id'] ?? '').toString();

    if (_currentUserId.isNotEmpty && jobTechId.isNotEmpty) {
      if (_currentUserId == jobTechId) return true;
    }

    final String techName =
        (_job.technician?['name'] ?? '').toString().trim().toLowerCase();
    final String myName = _currentUserName.trim().toLowerCase();
    if (techName.isNotEmpty && myName.isNotEmpty && techName == myName) {
      return true;
    }
    return false;
  }

  // ── Kirim komentar ───────────────────────────────────────────────────────
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
          );
          _commentCtrl.clear();
          _sendingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal kirim komentar: $e'),
            backgroundColor: _kRed,
          ),
        );
      }
    }
  }

  Future<void> _refreshJob() async {
    try {
      final updatedJob = await JobService.getJobDetail(_job.id);
      if (mounted) setState(() => _job = updatedJob);
    } catch (e) {
      debugPrint('Refresh job gagal: $e');
    }
  }

  // ── Submit progress (hanya teknisi) ─────────────────────────────────────
  Future<void> _submit() async {
    if (_uploading) return;
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi deskripsi dulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon tambahkan bukti foto!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final result = await JobService.updateProgress(
        jobId: _job.id,
        description: desc,
        photoFile: _photo,
        videoFile: _video,
      );
      setState(() {
        _job = result['job'];
        _uploading = false;
        _descCtrl.clear();
        _photo = null;
        _video = null;
      });
      if (_job.isCompleted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // ── Picker ───────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
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
      builder:
          (_) => SafeArea(
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
        // Tombol refresh untuk semua user
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
              // ── Banner: pemantau (non-teknisi) ──────────────────────
              if (!_isMyJob && !isCompleted) _buildViewerBanner(),
              if (!_isMyJob && !isCompleted) const SizedBox(height: 12),

              // ── Header ──────────────────────────────────────────────
              _buildHeaderCard(isCompleted),
              const SizedBox(height: 24),

              // ── Riwayat Pengerjaan ───────────────────────────────────
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

              // ── Form input progress (HANYA teknisi, tugas belum selesai) ──
              if (!isCompleted) ...[
                if (_isMyJob) ...[
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
                // Non-teknisi: TIDAK ada form, sudah ada banner di atas
              ],

              const SizedBox(height: 24),

              // ── Diskusi & Komentar (semua bisa lihat & ikut komentar) ──
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

  // ════════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ════════════════════════════════════════════════════════════════════════

  /// Banner khusus untuk pemantau (karyawan lain)
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
    final double progressVal =
        isCompleted ? 1.0 : ((_job.currentStep ?? 1) - 1) / 4.0;

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
              // Badge "Tugas Saya" / "Pemantau"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      _isMyJob
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
            // Progress bar
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
            // Step dots dengan label
            Row(
              children: List.generate(4, (i) {
                final done = i < completedSteps;
                final active = !isCompleted && i == completedSteps;
                final label = 'Tahap ${i + 1}';
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
                              color:
                                  done
                                      ? _kGreen
                                      : active
                                      ? _kPrimary.withOpacity(0.5)
                                      : Colors.grey.shade200,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    done
                                        ? _kGreen
                                        : active
                                        ? _kPrimary
                                        : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child:
                                done
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
                                color:
                                    done && i < completedSteps - 1
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
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            color:
                                done
                                    ? _kGreen
                                    : active
                                    ? _kPrimary
                                    : Colors.grey.shade400,
                            fontWeight:
                                done || active
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child:
                  _uploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        currentStep >= 4
                            ? 'Selesaikan Tugas ✓'
                            : 'Simpan & Lanjut Tahap $nextStep →',
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Komentar ─────────────────────────────────────────────────────────────
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

        // Input komentar — semua user bisa berkomentar
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
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

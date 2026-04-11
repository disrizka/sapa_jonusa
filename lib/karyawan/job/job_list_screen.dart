import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sapa_jonusa/service/job_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'job_progress_screen.dart';

const _kPrimary = Color(0xFF1565C0);
const _kBg = Color(0xFFF0F4FF);
const _kText = Color(0xFF0D1B3E);
const _kSub = Color(0xFF8A99B5);
const _kGreen = Color(0xFF00897B);
const _kAmber = Color(0xFFF57C00);
const _kRed = Color(0xFFE53935);

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _storage = const FlutterSecureStorage();

  List<Job> _active = [];
  List<Job> _history = [];
  bool _loading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserData();
    await _load();
  }

  Future<void> _loadUserData() async {
    try {
      final userStr = await _storage.read(key: 'user_data');
      if (userStr != null) {
        final userData = jsonDecode(userStr) as Map<String, dynamic>;
        setState(() => _currentUserId = userData['id'] as int?);
      } else {
        final userIdStr = await _storage.read(key: 'user_id');
        if (userIdStr != null) {
          setState(() => _currentUserId = int.tryParse(userIdStr));
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Gagal load user data -> $e');
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final active = await JobService.getActiveJobs();
      final history = await JobService.getJobHistory();
      if (mounted) {
        setState(() {
          _active = active;
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept(Job job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Terima Tugas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text('Ambil tugas "${job.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: _kSub)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ambil'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await JobService.acceptJob(job.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil diambil!'),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _openProgress(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobProgressScreen(job: job)),
    );
    _load();
  }

  // ── Label & warna tahap ──────────────────────────────────────────────────
  String _stepLabel(Job job) {
    if (job.isCompleted) return 'Selesai';
    if (job.isPending) return 'Menunggu';
    final step = job.currentStep ?? 1;
    return 'Tahap $step dari 4';
  }

  Color _stepColor(Job job) {
    if (job.isCompleted) return _kGreen;
    if (job.isPending) return _kAmber;
    return _kPrimary;
  }

  double _progressValue(Job job) {
    if (job.isCompleted) return 1.0;
    if (job.isPending) return 0.0;
    final step = job.currentStep ?? 1;
    return (step - 1) / 4.0;
  }

  // ── Widget progress bar + step dots ─────────────────────────────────────
  Widget _buildProgressSection(Job job) {
    final color = _stepColor(job);
    final progress = _progressValue(job);
    final completedSteps = job.isCompleted ? 4 : ((job.currentStep ?? 1) - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _stepLabel(job),
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!job.isPending)
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.12),
            color: color,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        // Step dots
        Row(
          children: List.generate(4, (i) {
            final done = i < completedSteps;
            final active =
                !job.isPending && !job.isCompleted && i == completedSteps;
            return Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color:
                          done
                              ? color
                              : active
                              ? color.withOpacity(0.4)
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done || active ? color : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child:
                        done
                            ? const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            )
                            : active
                            ? Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
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
                            i < completedSteps - 1
                                ? color
                                : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButton(Job job, bool isHistory) {
    if (isHistory) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openProgress(job),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Lihat Detail'),
        ),
      );
    }

    final int? jobTechId = job.technicianId;
    final bool isMyJob =
        jobTechId != null &&
        _currentUserId != null &&
        jobTechId == _currentUserId;

    if (job.isPending) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          // Semua orang bisa klik untuk melihat, tapi hanya teknisi yang bisa accept
          onPressed: isMyJob ? () => _accept(job) : () => _openProgress(job),
          icon: Icon(
            isMyJob ? Icons.check_circle_outline : Icons.visibility_outlined,
            size: 18,
          ),
          label: Text(isMyJob ? 'AMBIL TUGAS & MULAI' : 'Lihat Detail'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isMyJob ? const Color(0xFF1A237E) : Colors.grey.shade100,
            foregroundColor: isMyJob ? Colors.white : Colors.grey.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (job.isProcess) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          // Semua orang bisa lihat progress, tapi label berbeda
          onPressed: () => _openProgress(job),
          icon: Icon(
            isMyJob ? Icons.upload_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          label: Text(
            isMyJob
                ? 'Input Progress Tahap ${job.currentStep}'
                : 'Pantau Progress',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isMyJob ? const Color(0xFF1565C0) : Colors.grey.shade100,
            foregroundColor: isMyJob ? Colors.white : Colors.grey.shade700,
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildCard(Job job, {bool isHistory = false}) {
    final statusColor =
        job.status == 'pending'
            ? _kAmber
            : (job.status == 'process' ? _kPrimary : _kGreen);

    final statusLabel =
        job.status == 'pending'
            ? 'MENUNGGU'
            : job.status == 'process'
            ? 'PROSES'
            : 'SELESAI';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: judul + badge status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Deskripsi
          Text(
            job.description ?? '',
            style: const TextStyle(color: _kSub, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Info teknisi
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: _kSub),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Teknisi: ${job.technician?['name'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: _kText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Progress bar & step dots (BARU) ─────────────────────────
          _buildProgressSection(job),
          const SizedBox(height: 14),
          // Tombol aksi
          _buildActionButton(job, isHistory),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Tracker Tugas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _kPrimary,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Aktif'), Tab(text: 'Riwayat')],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tab,
                children: [
                  _buildList(_active, false),
                  _buildList(_history, true),
                ],
              ),
    );
  }

  Widget _buildList(List<Job> list, bool isHistory) {
    if (list.isEmpty) {
      return const Center(child: Text('Tidak ada tugas'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16),
        itemCount: list.length,
        itemBuilder:
            (context, index) => _buildCard(list[index], isHistory: isHistory),
      ),
    );
  }
}

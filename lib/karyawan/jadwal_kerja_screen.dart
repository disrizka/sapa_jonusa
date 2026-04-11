import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;

// ─── MODEL DATA ──────────────────────────────────────────────────────────────

class Holiday {
  final String date;
  final String title;

  Holiday({required this.date, required this.title});

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    date: json['start'] as String,
    title: json['title'] as String? ?? 'Libur',
  );
}

// ─── SCREEN UTAMA ────────────────────────────────────────────────────────────

class JadwalKerjaScreen extends StatefulWidget {
  final String? token;
  const JadwalKerjaScreen({super.key, this.token});

  @override
  State<JadwalKerjaScreen> createState() => _JadwalKerjaScreenState();
}

class _JadwalKerjaScreenState extends State<JadwalKerjaScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, Holiday> _holidays = {};
  bool _isLoading = true;
  String? _errorMessage;

  final _storage = const FlutterSecureStorage();
  String? _activeToken;

  @override
  void initState() {
    super.initState();
    _resolveTokenThenFetch();
  }

  // ── Ambil Token dari Secure Storage ────────────────────────────────────────

  Future<void> _resolveTokenThenFetch() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    String? token = widget.token;
    if (token == null || token.isEmpty) {
      token = await _storage.read(key: 'auth_token');
    }

    _activeToken = token?.trim();
    await _fetchHolidays();
  }

  // ── Fetch Data dari API ────────────────────────────────────────────────────

  Future<void> _fetchHolidays() async {
    if (_activeToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Sesi habis, silakan login kembali.";
      });
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${Api.baseUrl}/api/holidays'),
            headers: {
              'Authorization': 'Bearer $_activeToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final map = <String, Holiday>{};
        for (final item in data) {
          final h = Holiday.fromJson(item as Map<String, dynamic>);
          map[h.date] = h;
        }

        if (mounted) {
          setState(() {
            _holidays = map;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal memuat data (${response.statusCode})";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Tidak dapat terhubung ke server.";
        });
      }
    }
  }

  // ── Helper Logika Libur (Sesuai Permintaan Rizka) ──────────────────────────

  bool _isHoliday(DateTime day) {
    String formatted = DateFormat('yyyy-MM-dd').format(day);
    // HANYA JUMAT yang libur mingguan. Sabtu & Minggu tidak otomatis merah.
    return (day.weekday == DateTime.friday) || _holidays.containsKey(formatted);
  }

  Holiday? _getHoliday(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    if (_holidays.containsKey(key)) return _holidays[key];
    if (day.weekday == DateTime.friday) {
      return Holiday(date: key, title: 'Libur Mingguan (Jumat)');
    }
    return null;
  }

  // ── UI BUILDER ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.indigo),
              )
              : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(child: _buildLegend()),
                  SliverToBoxAdapter(child: _buildCalendarCard()),
                  SliverToBoxAdapter(
                    child: _buildSectionTitle("Daftar Libur Bulan Ini"),
                  ),
                  _buildHolidayList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 90.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.indigo.shade800,
      // centerTitle di sini untuk leading/actions
      centerTitle: true,
      leading: const BackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        // TAMBAHKAN INI agar teks di dalam FlexibleSpaceBar ke tengah
        centerTitle: true,
        // Sesuaikan padding agar benar-benar di tengah secara vertikal saat AppBar mengecil
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: const Text(
          'Jadwal Kerja',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade900, Colors.blue.shade700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'id_ID',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.indigo.shade900,
          ),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.orangeAccent,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.indigo,
            shape: BoxShape.circle,
          ),
          // Sabtu & Minggu tetap hitam (Hari Kerja)
          weekendTextStyle: TextStyle(color: Colors.black87),
          outsideDaysVisible: false,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            if (_isHoliday(day)) return _buildHolidayCell(day);
            return null;
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          if (_isHoliday(selectedDay)) {
            final h = _getHoliday(selectedDay);
            if (h != null) _showDetailLibur(h);
          }
        },
        onFormatChanged: (f) => setState(() => _calendarFormat = f),
        onPageChanged: (f) => setState(() => _focusedDay = f),
      ),
    );
  }

  Widget _buildHolidayCell(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayList() {
    // Cari hari terakhir di bulan ini
    int lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;

    final List<Holiday> monthHolidays = [];

    // 1. Tambahkan dari API
    _holidays.values.forEach((h) {
      final d = DateTime.parse(h.date);
      if (d.month == _focusedDay.month && d.year == _focusedDay.year) {
        monthHolidays.add(h);
      }
    });

    // 2. Tambahkan hari Jumat secara manual jika belum ada di API
    for (int i = 1; i <= lastDay; i++) {
      DateTime d = DateTime(_focusedDay.year, _focusedDay.month, i);
      if (d.weekday == DateTime.friday) {
        String fmt = DateFormat('yyyy-MM-dd').format(d);
        if (!monthHolidays.any((h) => h.date == fmt)) {
          monthHolidays.add(
            Holiday(date: fmt, title: "Libur Mingguan (Jumat)"),
          );
        }
      }
    }

    monthHolidays.sort((a, b) => a.date.compareTo(b.date));

    if (monthHolidays.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Tidak ada libur bulan ini",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final h = monthHolidays[index];
        final date = DateTime.parse(h.date);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  h.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.indigo,
              ),
            ],
          ),
        );
      }, childCount: monthHolidays.length),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.indigo.shade900,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _dot(Colors.red.shade400, "Libur"),
          const SizedBox(width: 15),
          _dot(Colors.orange.shade400, "Hari Ini"),
          const SizedBox(width: 15),
          _dot(Colors.grey.shade300, "Kerja"),
        ],
      ),
    );
  }

  Widget _dot(Color c, String l) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  void _showDetailLibur(Holiday holiday) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_note, color: Colors.red, size: 50),
                const SizedBox(height: 15),
                Text(
                  holiday.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat(
                    'EEEE, d MMMM yyyy',
                    'id_ID',
                  ).format(DateTime.parse(holiday.date)),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Tutup",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

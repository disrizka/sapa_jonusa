import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:url_launcher/url_launcher.dart';

class TimScreen extends StatefulWidget {
  const TimScreen({super.key});

  @override
  State<TimScreen> createState() => _TimScreenState();
}

class _TimScreenState extends State<TimScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http
          .get(
            Uri.parse('${Api.baseUrl}/api/users'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _allUsers = data;
            _filteredUsers = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error Fetch Tim: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredUsers =
          _allUsers
              .where(
                (user) =>
                    user['name'].toLowerCase().contains(query.toLowerCase()) ||
                    (user['division']?['name'] ?? '').toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        color: Colors.indigo,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
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
                  'Direktori Tim',
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
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: _filterSearch,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau divisi...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.indigo,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: Colors.indigo.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Daftar User
            _isLoading
                ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  ),
                )
                : _filteredUsers.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildUserCard(_filteredUsers[index]),
                      childCount: _filteredUsers.length,
                    ),
                  ),
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statItem("Anggota", _allUsers.length.toString(), Icons.group),
        const SizedBox(width: 12),
        _statItem(
          "Divisi",
          _allUsers.map((e) => e['division_id']).toSet().length.toString(),
          Icons.account_tree_rounded,
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    String name = user['name'] ?? 'No Name';
    String email = user['email'] ?? '-';
    String division = user['division']?['name'] ?? 'Belum Set';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar Circle Modern
            _buildAvatar(name),
            const SizedBox(width: 16),
            // Info Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Badge Divisi yang Cantik
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      division,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
            // Email Button
            IconButton(
              icon: const Icon(
                Icons.alternate_email_rounded,
                color: Colors.indigo,
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.indigo.withOpacity(0.05),
              ),
              onPressed: () async {
                final Uri params = Uri(scheme: 'mailto', path: email);
                if (await canLaunchUrl(params)) await launchUrl(params);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade100, Colors.indigo.shade50],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.indigo,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.indigo.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            "Anggota tim tidak ditemukan",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

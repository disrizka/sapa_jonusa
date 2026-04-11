import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PerusahaanScreen extends StatelessWidget {
  const PerusahaanScreen({super.key});

  // Fungsi helper untuk membuka URL/Email
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak dapat membuka $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF), // Abu-abu kebiruan sangat muda
      body: CustomScrollView(
        slivers: [
          // Header dengan efek Slivers agar lebih interaktif saat di-scroll
          SliverToBoxAdapter(child: _buildHeader(context)),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('Tentang Perusahaan'),
                const SizedBox(height: 16),
                _buildAboutCard(),

                const SizedBox(height: 32),
                _buildSectionTitle('Visi & Misi'),
                const SizedBox(height: 16),
                _buildInfoCard(
                  Icons.auto_awesome_mosaic_rounded,
                  'Visi',
                  'Menjadi mitra teknologi terpercaya yang menghubungkan solusi digital dengan kebutuhan Nusantara.',
                  [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                ),
                _buildInfoCard(
                  Icons.rocket_launch_rounded,
                  'Misi',
                  'Menyediakan infrastruktur digital yang efisien, transparan, dan inovatif bagi seluruh lapisan masyarakat.',
                  [const Color(0xFF81C784), const Color(0xFF388E3C)],
                ),

                const SizedBox(height: 32),
                _buildSectionTitle('Kontak & Media Sosial'),
                const SizedBox(height: 16),
                _buildContactCard(),

                const SizedBox(height: 48),
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'Sapa Jonusa v1.0.2',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '© 2026 PT Jasa Online Nusantara',
                        style: TextStyle(color: Colors.black26, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Stack(
        children: [
          // Dekorasi Lingkaran Abstrak
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PT Jasa Online Nusantara',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Teknologi untuk Negeri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A237E),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Text(
        'PT Jasa Online Nusantara (JONUSA) adalah perusahaan IT Solution yang berfokus pada pengembangan ekosistem digital terpadu. Kami percaya bahwa teknologi harus dapat diakses oleh semua orang untuk menciptakan efisiensi dan peluang baru di era modern.',
        style: TextStyle(
          fontSize: 15,
          color: Colors.black54,
          height: 1.7,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String content,
    List<Color> colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.shade50),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _contactTile(
            Icons.location_on_rounded,
            'Kantor Pusat',
            'Bekasi, Jawa Barat',
            'https://maps.app.goo.gl/71EaFsjpfvgrq5zQ6',
          ),
          Divider(height: 1, indent: 70, color: Colors.indigo.shade50),
          _contactTile(
            Icons.language_rounded,
            'Website Official',
            'jonusa.net',
            'https://jonusa.net/',
          ),
          Divider(height: 1, indent: 70, color: Colors.indigo.shade50),
          _contactTile(
            Icons.mail_rounded,
            'Email Support',
            'hallo@jonusa.net',
            'mailto:hallo@jonusa.net',
          ),
        ],
      ),
    );
  }

  Widget _contactTile(IconData icon, String label, String value, String url) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.indigo.shade700, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black38,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      onTap: () => _launchURL(url),
    );
  }
}

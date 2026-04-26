import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sapa_jonusa/admin/admin_screen.dart';
import 'package:sapa_jonusa/api/api.dart';
import 'package:sapa_jonusa/auth/login_screen.dart';
import 'package:sapa_jonusa/karyawan/karyawan_screen.dart';
import 'package:sapa_jonusa/service/fcm_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final token = await _storage.read(key: 'auth_token');
    final role = await _storage.read(key: 'user_role');

    if (!mounted) return;

    if (token != null && role != null) {
      await _sendFcmToken(token);

      if (!mounted) return;

      final cleanRole = role.trim().toLowerCase();
      if (cleanRole == 'admin' || cleanRole == 'kepala') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TesAdminPage()),
        );
      } else if (cleanRole == 'karyawan' || cleanRole == 'staff') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const KaryawanHomeScreen()),
        );
      } else {
        _goToLogin();
      }
    } else {
      _goToLogin();
    }
  }

  Future<void> _sendFcmToken(String authToken) async {
    try {
      final fcmToken = await FcmService.getToken();
      if (fcmToken == null) return;

      await http.post(
        Uri.parse('$baseUrl/api/user/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );

      debugPrint('FCM token (splash) berhasil dikirim.');
    } catch (e) {
      debugPrint('Gagal kirim FCM token dari splash: $e');
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset(
                  'assets/images/fingerprint.png',
                  color: Colors.white,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.fingerprint,
                      color: Colors.white,
                      size: 40,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Jonusa',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0D1B3E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Group Management System',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8A99B5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFF1565C0),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

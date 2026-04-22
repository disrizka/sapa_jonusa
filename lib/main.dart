import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sapa_jonusa/auth/splash_screen.dart';
import 'package:sapa_jonusa/service/fcm_service.dart';

// 1. Inisialisasi Plugin secara Global
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // 2. Pastikan binding sudah siap
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inisialisasi Firebase
  await Firebase.initializeApp();

  // 4. Inisialisasi FCM (Pastikan file services/fcm_service.dart sudah benar)
  await FcmService.init();

  // 5. Inisialisasi Format Tanggal (Bahasa Indonesia)
  await initializeDateFormatting('id_ID', null);

  // 6. Setup Notifikasi Lokal untuk Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 7. Jalankan App (Cukup satu kali panggil runApp)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAPA Jonusa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F5BFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FF),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
      ),
      // Entry awal aplikasi
      home: const SplashScreen(),
    );
  }
}

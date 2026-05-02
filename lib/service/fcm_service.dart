import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'navigation_service.dart';

export 'navigation_service.dart' show navigatorKey;

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sapa_high_importance',
    'Notifikasi SAPA',
    description: 'Notifikasi absensi, chat, dan tugas',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await (_localNotif
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >())
        ?.createNotificationChannel(_channel);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          _handlePayloadString(details.payload!);
        }
      },
    );

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('FCM foreground: ${msg.data}');
      _showLocal(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM background tap: ${msg.data}');
      _navigate(msg.data);
    });

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      final route =
          initial.data['route'] as String? ??
          initial.data['type'] as String? ??
          '';
      final routeId = initial.data['route_id'] as String?;

      NavigationService.pendingRouteId = routeId;
      NavigationService.pendingRoute = route;
    }

    final token = await _fcm.getToken();
    debugPrint('FCM Token: $token');
  }

  static void _showLocal(RemoteMessage msg) {
    final n = msg.notification;
    if (n == null) return;

    final payloadData = {
      'route': msg.data['route'] ?? msg.data['type'] ?? '',
      'route_id': msg.data['route_id'] ?? '',
    };

    _localNotif.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(payloadData),
    );
  }

  static void _handlePayloadString(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _navigate(data);
    } catch (e) {
      debugPrint('Payload parse error: $e');
    }
  }

  static void _navigate(Map<String, dynamic> data) {
    final route = data['route'] as String? ?? data['type'] as String? ?? '';
    final routeId = data['route_id'] as String?;

    if (route.isEmpty) return;

    NavigationService.handleRoute(route, routeId);
  }

  static Future<String?> getToken() => _fcm.getToken();
}

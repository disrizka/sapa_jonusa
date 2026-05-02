import 'package:flutter/material.dart';
import 'package:sapa_jonusa/karyawan/attedance_history_screen.dart';
import 'package:sapa_jonusa/karyawan/chat/screens/chat_screen.dart';
import 'package:sapa_jonusa/karyawan/job/job_list_screen.dart';
import 'package:sapa_jonusa/karyawan/job/job_progress_screen.dart';
import 'package:sapa_jonusa/karyawan/notification_screen.dart';
import 'package:sapa_jonusa/service/job_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NavigationService {
  static String? _pendingRoute;
  static String? _pendingRouteId;

  static bool _pendingProcessed = false;

  static set pendingRoute(String? value) {
    _pendingRoute = value;
    _pendingProcessed = false;
  }

  static set pendingRouteId(String? value) => _pendingRouteId = value;

  static void processPendingRoute() {
    if (_pendingRoute == null || _pendingProcessed) return;

    final route = _pendingRoute!;
    final id = _pendingRouteId;

    _pendingRoute = null;
    _pendingRouteId = null;
    _pendingProcessed = true;

    debugPrint('Processing pending route: $route id=$id');
    handleRoute(route, id);
  }

  static Future<void> handleRoute(String route, String? routeId) async {
    debugPrint('handleRoute called: route=$route id=$routeId');

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator null — simpan ke pending');
      _pendingRoute = route;
      _pendingRouteId = routeId;
      _pendingProcessed = false;
      return;
    }

    switch (route) {
      case 'chat':
        navigator.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
        break;

      case 'job_detail':
      case 'job_assigned':
        final id = routeId != null ? int.tryParse(routeId) : null;
        if (id != null) {
          navigator.push(
            MaterialPageRoute(builder: (_) => const _LoadingScreen()),
          );
          try {
            final job = await JobService.getJobDetail(id);
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => JobProgressScreen(job: job)),
            );
          } catch (e) {
            debugPrint('Gagal load job detail: $e');
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const JobListScreen()),
            );
          }
        } else {
          navigator.push(
            MaterialPageRoute(builder: (_) => const JobListScreen()),
          );
        }
        break;

      case 'jobs':
        navigator.push(
          MaterialPageRoute(builder: (_) => const JobListScreen()),
        );
        break;

      case 'presence':
      case 'attendance_history':
        navigator.push(
          MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
        );
        break;

      default:
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
        break;
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Memuat...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

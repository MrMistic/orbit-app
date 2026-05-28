import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lightweight wrapper around flutter_local_notifications. Used for the
/// cook timer "ding" — fires immediately when the timer ends.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Android 13+ requires explicit notification permission.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      if (kDebugMode) print('Notification permission request failed: $e');
    }
    _initialized = true;
  }

  static Future<void> showTimerDone({
    required String recipeName,
    int? id,
  }) async {
    await init();
    const android = AndroidNotificationDetails(
      'cook_timer',
      'Cook timers',
      channelDescription: 'Notifications for cooking timer completion.',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    const details = NotificationDetails(android: android);
    await _plugin.show(
      id ?? recipeName.hashCode,
      'Timer done',
      '$recipeName is ready.',
      details,
    );
  }
}

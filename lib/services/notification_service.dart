import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Lightweight wrapper around flutter_local_notifications.
///
/// Channels:
///   - cook_timer: immediate fire when cook timer ends
///   - todo_reminders: due-date reminders for todos
///   - maintenance_reminders: overdue/upcoming maintenance items
///   - contact_reminders: reach-out cadence nudges
///   - subscription_reminders: upcoming renewal warnings
///   - cycle_reminders: (managed by CycleRemindersController)
class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ─── ID RANGES ───
  // cook_timer:          0 - 999
  // todo_reminders:      1000 - 1999
  // maintenance:         2000 - 2999
  // contacts:            3000 - 3999
  // subscriptions:       4000 - 4999
  // cycle_reminders:     10000 - 19999 (managed by CycleRemindersController)

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);

    // Android 13+ requires explicit notification permission.
    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      if (kDebugMode) print('Notification permission request failed: $e');
    }
    _initialized = true;
  }

  // ─── COOK TIMER (immediate) ───

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
    await plugin.show(
      id ?? recipeName.hashCode.abs() % 1000,
      'Timer done',
      '$recipeName is ready.',
      details,
    );
  }

  // ─── SCHEDULED NOTIFICATIONS ───

  static Future<void> scheduleTodoReminder({
    required int notifId,
    required String title,
    required DateTime dueDate,
  }) async {
    await init();
    // Fire at 9 AM on the due date.
    final fireAt = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    if (fireAt.isBefore(DateTime.now())) return;

    await plugin.zonedSchedule(
      1000 + (notifId % 1000),
      'Todo due today',
      title,
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminders',
          'Todo reminders',
          channelDescription: 'Reminders for upcoming todo due dates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleMaintenanceReminder({
    required int notifId,
    required String title,
    required DateTime dueDate,
  }) async {
    await init();
    // Fire at 8 AM on the due date.
    final fireAt = DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0);
    if (fireAt.isBefore(DateTime.now())) return;

    await plugin.zonedSchedule(
      2000 + (notifId % 1000),
      'Maintenance due',
      title,
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'maintenance_reminders',
          'Maintenance reminders',
          channelDescription: 'Reminders for upcoming maintenance tasks.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleContactReminder({
    required int notifId,
    required String contactName,
    required DateTime fireAt,
  }) async {
    await init();
    if (fireAt.isBefore(DateTime.now())) return;

    await plugin.zonedSchedule(
      3000 + (notifId % 1000),
      'Reach out',
      "It's been a while — check in with $contactName.",
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'contact_reminders',
          'Contact reminders',
          channelDescription: 'Nudges to stay in touch with your contacts.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleSubscriptionReminder({
    required int notifId,
    required String subscriptionName,
    required DateTime renewalDate,
  }) async {
    await init();
    // Fire 1 day before renewal at 10 AM.
    final fireAt = DateTime(
      renewalDate.year,
      renewalDate.month,
      renewalDate.day - 1,
      10,
      0,
    );
    if (fireAt.isBefore(DateTime.now())) return;

    await plugin.zonedSchedule(
      4000 + (notifId % 1000),
      'Renewal tomorrow',
      '$subscriptionName renews tomorrow.',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_reminders',
          'Subscription reminders',
          channelDescription: 'Heads-up before subscriptions renew.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── BULK CANCEL BY RANGE ───

  static Future<void> cancelRange(int start, int end) async {
    for (var i = start; i < end; i++) {
      await plugin.cancel(i);
    }
  }

  static Future<void> cancelTodoReminders() => cancelRange(1000, 2000);
  static Future<void> cancelMaintenanceReminders() => cancelRange(2000, 3000);
  static Future<void> cancelContactReminders() => cancelRange(3000, 4000);
  static Future<void> cancelSubscriptionReminders() => cancelRange(4000, 5000);
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../database/models.dart';
import '../database/object_box.dart';
import '../services/cycle_predictor.dart';
import '../services/notification_service.dart';

class CycleRemindersController extends GetxController {
  final RxList<CycleReminder> reminders = <CycleReminder>[].obs;

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.plugin;
  static const _channelId = 'cycle_reminders';
  static const _channelName = 'Cycle reminders';

  @override
  void onInit() {
    super.onInit();
    _reload();
    ObjectBox.instance.cycleReminderBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) {
      _reload();
      rescheduleAll();
    });
  }

  void _reload() {
    reminders.assignAll(ObjectBox.instance.cycleReminderBox.getAll());
  }

  Future<void> add({
    required String title,
    required String message,
    required String triggerType,
    required int daysBefore,
  }) async {
    if (title.trim().isEmpty) return;
    ObjectBox.instance.cycleReminderBox.put(CycleReminder(
      title: title.trim(),
      message: message.trim(),
      triggerType: triggerType,
      daysBefore: daysBefore,
    ));
    _reload();
    await rescheduleAll();
  }

  Future<void> updateReminder(
    CycleReminder r, {
    required String title,
    required String message,
    required String triggerType,
    required int daysBefore,
    required bool enabled,
  }) async {
    r.title = title.trim();
    r.message = message.trim();
    r.triggerType = triggerType;
    r.daysBefore = daysBefore;
    r.enabled = enabled;
    ObjectBox.instance.cycleReminderBox.put(r);
    _reload();
    await rescheduleAll();
  }

  Future<void> toggleEnabled(CycleReminder r) async {
    r.enabled = !r.enabled;
    ObjectBox.instance.cycleReminderBox.put(r);
    _reload();
    await rescheduleAll();
  }

  Future<void> remove(CycleReminder r) async {
    ObjectBox.instance.cycleReminderBox.remove(r.id);
    _reload();
    await rescheduleAll();
  }

  /// Cancels all scheduled cycle notifications and re-schedules based on
  /// current prediction + enabled reminders.
  Future<void> rescheduleAll() async {
    // Cancel all existing cycle reminder notifications (ids 10000-19999).
    for (var i = 10000; i < 10000 + reminders.length * 2; i++) {
      await _plugin.cancel(i);
    }

    // Get current prediction.
    final entries = ObjectBox.instance.cycleBox.getAll()
      ..sort((a, b) => a.date.compareTo(b.date));
    final prediction = CyclePredictor.predict(entries);
    if (prediction == null) return;

    var notifId = 10000;
    for (final r in reminders) {
      if (!r.enabled) continue;
      final targetDate = _computeTargetDate(r, prediction);
      if (targetDate == null) continue;

      // Only schedule if in the future.
      final now = DateTime.now();
      if (targetDate.isBefore(now)) continue;

      final scheduledDate = tz.TZDateTime.from(targetDate, tz.local);
      await _plugin.zonedSchedule(
        notifId++,
        r.title,
        r.message,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders based on cycle predictions',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  DateTime? _computeTargetDate(CycleReminder r, CyclePrediction prediction) {
    DateTime anchor;
    switch (r.triggerType) {
      case 'before_period':
      case 'period_start':
        anchor = prediction.nextPeriodStart;
        break;
      case 'fertile_start':
        anchor = prediction.fertileWindow.start;
        break;
      case 'ovulation':
        anchor = prediction.ovulation;
        break;
      default:
        anchor = prediction.nextPeriodStart;
    }
    // daysBefore is how many days before the anchor to fire.
    final target = anchor.subtract(Duration(days: r.daysBefore));
    // Set to 9 AM for a reasonable notification time.
    return DateTime(target.year, target.month, target.day, 9, 0);
  }

  /// Suggested presets for quick setup.
  static const presets = [
    _Preset(
      title: 'Period coming soon',
      message: 'Period predicted in 2 days. Be extra thoughtful.',
      triggerType: 'before_period',
      daysBefore: 2,
    ),
    _Preset(
      title: 'PMS likely starting',
      message: 'PMS phase may be starting. Extra patience and care.',
      triggerType: 'before_period',
      daysBefore: 5,
    ),
    _Preset(
      title: 'Period starting today',
      message: 'Period predicted to start today.',
      triggerType: 'period_start',
      daysBefore: 0,
    ),
    _Preset(
      title: 'Fertile window opening',
      message: 'Fertile window is starting.',
      triggerType: 'fertile_start',
      daysBefore: 0,
    ),
    _Preset(
      title: 'Ovulation day',
      message: 'Predicted ovulation today.',
      triggerType: 'ovulation',
      daysBefore: 0,
    ),
  ];
}

class _Preset {
  const _Preset({
    required this.title,
    required this.message,
    required this.triggerType,
    required this.daysBefore,
  });
  final String title;
  final String message;
  final String triggerType;
  final int daysBefore;
}

typedef CycleReminderPreset = _Preset;

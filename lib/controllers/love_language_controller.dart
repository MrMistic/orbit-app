import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../data/love_language_suggestions.dart';
import '../database/models.dart';
import '../database/object_box.dart';

class LoveLanguageController extends GetxController {
  final RxList<LoveLanguageReminder> reminders = <LoveLanguageReminder>[].obs;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'love_language';
  static const _channelName = 'Love language reminders';
  static bool _tzInitialized = false;
  final _rng = Random();

  @override
  void onInit() {
    super.onInit();
    _initTz();
    _reload();
    ObjectBox.instance.loveLanguageBox
        .query()
        .watch(triggerImmediately: false)
        .listen((_) {
      _reload();
      rescheduleAll();
    });
  }

  void _initTz() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  void _reload() {
    reminders.assignAll(ObjectBox.instance.loveLanguageBox.getAll());
  }

  /// Add multiple suggestions at once (from the setup flow).
  Future<void> addBatch(List<LoveLanguageReminder> items) async {
    final box = ObjectBox.instance.loveLanguageBox;
    for (final item in items) {
      box.put(item);
    }
    _reload();
    await rescheduleAll();
  }

  Future<void> add({
    required String language,
    required String action,
    int frequencyDays = 3,
  }) async {
    if (action.trim().isEmpty) return;
    ObjectBox.instance.loveLanguageBox.put(LoveLanguageReminder(
      language: language,
      action: action.trim(),
      frequencyDays: frequencyDays,
    ));
    _reload();
    await rescheduleAll();
  }

  Future<void> updateReminder(
    LoveLanguageReminder r, {
    required String action,
    required int frequencyDays,
    required bool enabled,
  }) async {
    r.action = action.trim();
    r.frequencyDays = frequencyDays;
    r.enabled = enabled;
    ObjectBox.instance.loveLanguageBox.put(r);
    _reload();
    await rescheduleAll();
  }

  Future<void> toggleEnabled(LoveLanguageReminder r) async {
    r.enabled = !r.enabled;
    ObjectBox.instance.loveLanguageBox.put(r);
    _reload();
    await rescheduleAll();
  }

  Future<void> remove(LoveLanguageReminder r) async {
    ObjectBox.instance.loveLanguageBox.remove(r.id);
    _reload();
    await rescheduleAll();
  }

  /// Picks a random enabled action that hasn't been shown recently.
  String? getRandomSuggestion() {
    final enabled = reminders.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return null;
    // Prefer ones not shown recently.
    final candidates = enabled.where((r) {
      if (r.lastShownAt == null) return true;
      return DateTime.now().difference(r.lastShownAt!).inDays >= r.frequencyDays;
    }).toList();
    final pool = candidates.isNotEmpty ? candidates : enabled;
    return pool[_rng.nextInt(pool.length)].action;
  }

  /// Schedule the next notification for each enabled reminder.
  Future<void> rescheduleAll() async {
    // Cancel love language notifications (ids 20000-29999).
    for (var i = 20000; i < 20000 + reminders.length + 10; i++) {
      await _plugin.cancel(i);
    }

    var notifId = 20000;
    final now = DateTime.now();

    for (final r in reminders) {
      if (!r.enabled) continue;

      // Schedule next occurrence: lastShown + frequency, or tomorrow if never shown.
      final lastShown = r.lastShownAt ?? now;
      var nextDate = lastShown.add(Duration(days: r.frequencyDays));
      if (nextDate.isBefore(now)) {
        nextDate = now.add(const Duration(days: 1));
      }
      // Fire at 10 AM.
      final target = DateTime(nextDate.year, nextDate.month, nextDate.day, 10);
      if (target.isBefore(now)) continue;

      final scheduledDate = tz.TZDateTime.from(target, tz.local);
      await _plugin.zonedSchedule(
        notifId++,
        loveLanguageLabels[r.language] ?? 'Love reminder',
        r.action,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Periodic love language reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Mark as shown so next schedule advances.
      r.lastShownAt = target;
      ObjectBox.instance.loveLanguageBox.put(r);
    }
  }
}

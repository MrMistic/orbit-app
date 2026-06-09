import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models.dart';
import '../database/object_box.dart';

/// Manages the Google Sleep API opt-in and imports detected sleep sessions.
class SleepDetectionService {
  static const _channel = MethodChannel('com.life.orbit/intent');
  static const _prefKey = 'sleep_auto_detect';
  static const _pendingKey = 'pending_sleep_segments';
  static const _permChannel = MethodChannel('com.life.orbit/permissions');

  /// Whether auto-detection is currently enabled.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Request ACTIVITY_RECOGNITION permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestActivityRecognition');
      return result ?? false;
    } catch (_) {
      // If channel fails, assume we can try (permission may already be granted).
      return true;
    }
  }

  /// Enable sleep auto-detection.
  static Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    try {
      await _channel.invokeMethod('enableSleepDetection');
    } catch (_) {}
  }

  /// Disable sleep auto-detection.
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    try {
      await _channel.invokeMethod('disableSleepDetection');
    } catch (_) {}
  }

  /// Import any pending sleep segments detected by the native receiver.
  /// Returns the number of new entries created.
  static Future<int> importPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey) ?? '';
    if (raw.isEmpty) return 0;

    final segments = raw.split(';').where((s) => s.contains('|')).toList();
    if (segments.isEmpty) return 0;

    final box = ObjectBox.instance.sleepBox;
    final existing = box.getAll();
    final newlyImported = <(DateTime, DateTime)>[];
    var imported = 0;

    for (final seg in segments) {
      final parts = seg.split('|');
      if (parts.length != 2) continue;
      final startMs = int.tryParse(parts[0]);
      final endMs = int.tryParse(parts[1]);
      if (startMs == null || endMs == null) continue;

      final bedtime = DateTime.fromMillisecondsSinceEpoch(startMs);
      final wakeTime = DateTime.fromMillisecondsSinceEpoch(endMs);

      // Skip if duration is unreasonable (< 2h or > 14h).
      final hours = wakeTime.difference(bedtime).inMinutes / 60.0;
      if (hours < 2 || hours > 14) continue;

      // Skip if we already have an entry overlapping this time.
      final isDuplicate = existing.any((e) {
        return e.bedtime.difference(bedtime).inMinutes.abs() < 30 &&
            e.wakeTime.difference(wakeTime).inMinutes.abs() < 30;
      });
      if (isDuplicate) continue;

      // Also check against entries imported in this same batch.
      final isBatchDuplicate = newlyImported.any((entry) {
        return entry.$1.difference(bedtime).inMinutes.abs() < 30 &&
            entry.$2.difference(wakeTime).inMinutes.abs() < 30;
      });
      if (isBatchDuplicate) continue;

      box.put(SleepEntry(bedtime: bedtime, wakeTime: wakeTime));
      newlyImported.add((bedtime, wakeTime));
      imported++;
    }

    // Clear pending data.
    await prefs.setString(_pendingKey, '');
    return imported;
  }
}

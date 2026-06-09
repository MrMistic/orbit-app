import '../database/object_box.dart';
import 'notification_service.dart';

/// Scans all relevant data sources and schedules upcoming notifications.
///
/// Called once on app startup (after ObjectBox is ready) and can be re-invoked
/// whenever data changes that affects reminders.
class ReminderScheduler {
  /// Reschedule everything. Cancels stale notifications first.
  static Future<void> rescheduleAll() async {
    await _scheduleTodos();
    await _scheduleMaintenance();
    await _scheduleContacts();
    await _scheduleSubscriptions();
  }

  // ─── TODOS ───

  static Future<void> _scheduleTodos() async {
    await NotificationService.cancelTodoReminders();
    final todos = ObjectBox.instance.todoBox.getAll();
    var idx = 0;
    for (final t in todos) {
      if (t.done || t.dueDate == null) continue;
      // Only schedule for today or future.
      final today = DateTime.now();
      if (t.dueDate!.isBefore(DateTime(today.year, today.month, today.day))) {
        continue;
      }
      await NotificationService.scheduleTodoReminder(
        notifId: idx++,
        title: t.title,
        dueDate: t.dueDate!,
      );
      if (idx >= 1000) break; // cap at range limit
    }
  }

  // ─── MAINTENANCE ───

  static Future<void> _scheduleMaintenance() async {
    await NotificationService.cancelMaintenanceReminders();
    final items = ObjectBox.instance.maintenanceBox.getAll();
    var idx = 0;
    for (final item in items) {
      if (item.nextDueAt == null) continue;
      final today = DateTime.now();
      if (item.nextDueAt!
          .isBefore(DateTime(today.year, today.month, today.day))) {
        continue; // already overdue — don't schedule a past notification
      }
      await NotificationService.scheduleMaintenanceReminder(
        notifId: idx++,
        title: item.title,
        dueDate: item.nextDueAt!,
      );
      if (idx >= 1000) break;
    }
  }

  // ─── CONTACTS ───

  static Future<void> _scheduleContacts() async {
    await NotificationService.cancelContactReminders();
    final contacts = ObjectBox.instance.crmContactBox.getAll();
    var idx = 0;
    for (final c in contacts) {
      if (c.reachOutDays == null) continue;
      // Compute when the next reach-out is due.
      final lastContact = c.lastContactedAt ?? c.createdAt;
      final nextDue = lastContact.add(Duration(days: c.reachOutDays!));
      // Fire at 10 AM on the due date.
      final fireAt = DateTime(nextDue.year, nextDue.month, nextDue.day, 10, 0);
      if (fireAt.isBefore(DateTime.now())) continue; // already overdue
      await NotificationService.scheduleContactReminder(
        notifId: idx++,
        contactName: c.name,
        fireAt: fireAt,
      );
      if (idx >= 1000) break;
    }
  }

  // ─── SUBSCRIPTIONS ───

  static Future<void> _scheduleSubscriptions() async {
    await NotificationService.cancelSubscriptionReminders();
    final subs = ObjectBox.instance.subscriptionBox.getAll();
    var idx = 0;
    for (final s in subs) {
      if (!s.active || s.nextRenewal == null) continue;
      final today = DateTime.now();
      // Only schedule if renewal is at least tomorrow (so the "day before"
      // notification fires today or in the future).
      if (s.nextRenewal!
          .isBefore(DateTime(today.year, today.month, today.day + 1))) {
        continue;
      }
      await NotificationService.scheduleSubscriptionReminder(
        notifId: idx++,
        subscriptionName: s.name,
        renewalDate: s.nextRenewal!,
      );
      if (idx >= 1000) break;
    }
  }
}

package com.life.orbit

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Receives alarm broadcasts and triggers PhotoWidget update.
 * Also handles scheduling/cancelling the repeating alarm.
 */
class PhotoWidgetAlarm : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Trigger widget update.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, PhotoWidget::class.java))
        if (ids.isNotEmpty()) {
            val updateIntent = Intent(context, PhotoWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(updateIntent)
        }
    }

    companion object {
        private const val REQUEST_CODE = 7777

        private fun getPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, PhotoWidgetAlarm::class.java)
            return PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        /**
         * Schedule a repeating alarm at the given interval in minutes.
         */
        fun schedule(context: Context, intervalMinutes: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intervalMillis = intervalMinutes.toLong() * 60_000L
            val pendingIntent = getPendingIntent(context)

            // Cancel any existing alarm first.
            alarmManager.cancel(pendingIntent)

            // Schedule inexact repeating to be battery-friendly.
            alarmManager.setInexactRepeating(
                AlarmManager.RTC,
                System.currentTimeMillis() + intervalMillis,
                intervalMillis,
                pendingIntent
            )
        }

        /**
         * Cancel the repeating alarm.
         */
        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(getPendingIntent(context))
        }
    }
}

package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class CycleWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            // shared_preferences stores ints as Long on Android.
            val days = try {
                prefs.getLong("flutter.widget_cycle_days", Long.MIN_VALUE).toInt()
            } catch (e: ClassCastException) {
                try {
                    prefs.getInt("flutter.widget_cycle_days", Int.MIN_VALUE)
                } catch (_: Exception) {
                    Int.MIN_VALUE
                }
            }
            val confidence = prefs.getString("flutter.widget_cycle_confidence", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_cycle)
            if (days == Long.MIN_VALUE.toInt() || days == Int.MIN_VALUE) {
                views.setTextViewText(R.id.widget_value, "—")
                views.setTextViewText(R.id.widget_subtitle, "No data yet")
            } else {
                val valueText = when {
                    days < 0 -> "${-days}d late"
                    days == 0 -> "Today"
                    days == 1 -> "1 day"
                    else -> "$days days"
                }
                views.setTextViewText(R.id.widget_value, valueText)
                views.setTextViewText(R.id.widget_subtitle, confidence)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "cycle")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 6, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_value, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_subtitle, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

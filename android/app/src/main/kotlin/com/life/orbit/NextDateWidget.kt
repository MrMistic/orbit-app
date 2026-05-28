package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NextDateWidget : AppWidgetProvider() {
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
            val title = prefs.getString("flutter.widget_next_date_title", "") ?: ""
            // Flutter's shared_preferences stores ints as Long on Android.
            // Use a try/catch in case the underlying type differs.
            val days = try {
                prefs.getLong("flutter.widget_next_date_days", -1).toInt()
            } catch (e: ClassCastException) {
                try {
                    prefs.getInt("flutter.widget_next_date_days", -1)
                } catch (_: Exception) {
                    -1
                }
            }

            val views = RemoteViews(context.packageName, R.layout.widget_next_date)
            if (title.isEmpty() || days < 0) {
                views.setTextViewText(R.id.widget_days, "—")
                views.setTextViewText(R.id.widget_title, "No dates set")
            } else {
                val daysText = when (days) {
                    0 -> "Today!"
                    1 -> "1 day"
                    else -> "$days days"
                }
                views.setTextViewText(R.id.widget_days, daysText)
                views.setTextViewText(R.id.widget_title, title)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "important_dates")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_days, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

package com.life.orbit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SleepWidget : AppWidgetProvider() {
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
            val summary = prefs.getString("flutter.widget_sleep_avg", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_sleep)
            views.setTextViewText(
                R.id.widget_summary,
                if (summary.isEmpty()) "Log sleep to see your average" else summary
            )

            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "sleep")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 3, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_summary, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
